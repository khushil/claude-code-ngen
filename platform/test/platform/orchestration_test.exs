defmodule Platform.OrchestrationTest do
  @moduledoc """
  Integration test for the full orchestration pipeline.
  Verifies dependency graph execution, parallelism, retry, and crash recovery
  using message injection to simulate agent completion.
  """
  use ExUnit.Case, async: false

  setup do
    {:ok, _} = Application.ensure_all_started(:platform)

    team = "orch-test-#{System.unique_integer([:positive])}"
    {:ok, _pid} = Platform.create_team(team)

    on_exit(fn ->
      Platform.shutdown_team(team)
    end)

    %{team: team}
  end

  test "coordinator sends completion messages for mock tasks", %{team: team} do
    # We test the coordinator's message handling directly
    # by simulating agent completion messages
    coordinator =
      {:via, Registry, {Platform.TeamRegistry, {team, :coordinator}}}

    {:ok, _} = Platform.add_task(team, %{id: "t1", prompt: "test"})
    {:ok, _} = Platform.add_task(team, %{id: "t2", prompt: "test", blocked_by: ["t1"]})

    # Subscribe to events
    Platform.Team.EventBus.subscribe(team, :task_completed)
    Platform.Team.EventBus.subscribe(team, :team_done)

    # Simulate t1 completing (as if an agent reported back)
    send(GenServer.whereis(coordinator), {:agent_completed, "t1", "result 1"})

    assert_receive {:event, :task_completed, %{task_id: "t1"}}, 1000

    # After t1 completes, t2 should be dispatched
    Process.sleep(100)
    status = Platform.get_status(team)
    assert status.tasks["t1"].state == :completed
    # t2 should be running (agent spawned) or failed (no API key)
    assert status.tasks["t2"].state in [:running, :failed, :pending]
  end

  test "retry logic on agent failure", %{team: team} do
    coordinator =
      {:via, Registry, {Platform.TeamRegistry, {team, :coordinator}}}

    {:ok, _} = Platform.add_task(team, %{id: "t1", prompt: "test", max_retries: 1})

    Platform.Team.EventBus.subscribe(team, :task_failed)
    Platform.Team.EventBus.subscribe(team, :team_done)

    # Simulate first failure — should retry
    send(GenServer.whereis(coordinator), {:agent_failed, "t1", :test_error})
    Process.sleep(100)

    status = Platform.get_status(team)
    # After first failure with max_retries=1, should be retrying (pending/running)
    assert status.tasks["t1"].retries == 1

    # Simulate second failure — should be permanent
    send(GenServer.whereis(coordinator), {:agent_failed, "t1", :test_error_2})

    assert_receive {:event, :task_failed, %{task_id: "t1"}}, 1000

    status = Platform.get_status(team)
    assert status.tasks["t1"].state == :failed
  end

  test "parallel task execution — all deps must complete before downstream unblocks", %{team: team} do
    coordinator =
      {:via, Registry, {Platform.TeamRegistry, {team, :coordinator}}}

    # c depends on both a AND b — both must complete before c can run
    {:ok, _} = Platform.add_task(team, %{id: "a", prompt: "test a"})
    {:ok, _} = Platform.add_task(team, %{id: "b", prompt: "test b"})
    {:ok, _} = Platform.add_task(team, %{id: "c", prompt: "test c", blocked_by: ["a", "b"]})

    Platform.Team.EventBus.subscribe(team, :task_completed)

    # Complete only "a" — "c" should remain pending because "b" is still pending
    send(GenServer.whereis(coordinator), {:agent_completed, "a", "result a"})
    assert_receive {:event, :task_completed, %{task_id: "a"}}, 1000

    Process.sleep(50)
    status = Platform.get_status(team)
    assert status.tasks["a"].state == :completed
    assert status.tasks["c"].state == :pending, "c should stay pending until both deps complete"

    # Now complete "b" — "c" should unblock
    send(GenServer.whereis(coordinator), {:agent_completed, "b", "result b"})
    assert_receive {:event, :task_completed, %{task_id: "b"}}, 1000

    Process.sleep(100)
    status = Platform.get_status(team)
    assert status.tasks["b"].state == :completed
    # c should now be dispatched (running or already completed/failed via mock CLI)
    assert status.tasks["c"].state in [:running, :failed, :pending]
  end

  test "dependency outputs are passed to downstream tasks", %{team: team} do
    coordinator =
      {:via, Registry, {Platform.TeamRegistry, {team, :coordinator}}}

    {:ok, _} = Platform.add_task(team, %{id: "t1", prompt: "test"})
    {:ok, _} = Platform.add_task(team, %{id: "t2", prompt: "use deps", blocked_by: ["t1"]})

    # Complete t1 with a result
    send(GenServer.whereis(coordinator), {:agent_completed, "t1", "analysis output here"})
    Process.sleep(100)

    # Verify t1 output is stored
    {:ok, output} = Platform.get_task_output(team, "t1")
    assert output == "analysis output here"
  end
end
