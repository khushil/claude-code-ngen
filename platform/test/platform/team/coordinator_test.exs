defmodule Platform.Team.CoordinatorTest do
  use ExUnit.Case, async: false

  setup do
    # Ensure the application is started
    {:ok, _} = Application.ensure_all_started(:platform)

    team = "test-#{System.unique_integer([:positive])}"
    {:ok, _pid} = Platform.create_team(team)

    on_exit(fn ->
      Platform.shutdown_team(team)
    end)

    %{team: team}
  end

  test "add tasks and get status", %{team: team} do
    {:ok, _} = Platform.add_task(team, %{id: "t1", prompt: "test prompt"})
    {:ok, _} = Platform.add_task(team, %{id: "t2", prompt: "test prompt 2", blocked_by: ["t1"]})

    status = Platform.get_status(team)
    assert status.summary.total == 2
    assert status.summary.pending == 2
    assert status.tasks["t1"].blocked_by == []
    assert status.tasks["t2"].blocked_by == ["t1"]
  end

  test "rejects tasks after execution starts", %{team: team} do
    {:ok, _} = Platform.add_task(team, %{id: "t1", prompt: "test"})
    :ok = Platform.start_execution(team)

    assert {:error, :execution_already_started} =
             Platform.add_task(team, %{id: "t2", prompt: "test"})
  end

  test "detects invalid dependencies", %{team: team} do
    {:ok, _} = Platform.add_task(team, %{id: "t1", prompt: "test", blocked_by: ["nonexistent"]})

    assert {:error, {:invalid_dependencies, _}} = Platform.start_execution(team)
  end

  test "get_task_output returns error for non-existent task", %{team: team} do
    assert {:error, :not_found} = Platform.get_task_output(team, "nope")
  end

  test "get_task_output returns error for pending task", %{team: team} do
    {:ok, _} = Platform.add_task(team, %{id: "t1", prompt: "test"})
    assert {:error, {:not_completed, :pending}} = Platform.get_task_output(team, "t1")
  end
end
