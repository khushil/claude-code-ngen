defmodule Platform.Team.EventBusTest do
  use ExUnit.Case, async: false

  setup do
    {:ok, _} = Application.ensure_all_started(:platform)

    team = "bus-test-#{System.unique_integer([:positive])}"
    {:ok, _pid} = Platform.create_team(team)

    on_exit(fn ->
      Platform.shutdown_team(team)
    end)

    %{team: team}
  end

  test "subscribe and receive events", %{team: team} do
    :ok = Platform.Team.EventBus.subscribe(team, :test_event)

    Platform.Team.EventBus.broadcast(team, :test_event, %{data: "hello"})

    assert_receive {:event, :test_event, %{data: "hello"}}, 1000
  end

  test "only receives subscribed event types", %{team: team} do
    :ok = Platform.Team.EventBus.subscribe(team, :wanted)

    Platform.Team.EventBus.broadcast(team, :unwanted, %{data: "nope"})
    Platform.Team.EventBus.broadcast(team, :wanted, %{data: "yes"})

    assert_receive {:event, :wanted, %{data: "yes"}}, 1000
    refute_receive {:event, :unwanted, _}, 100
  end
end
