defmodule Platform.TeamSupervisorTest do
  use ExUnit.Case, async: false

  setup do
    {:ok, _} = Application.ensure_all_started(:platform)
    :ok
  end

  test "create and shutdown team" do
    team = "sup-test-#{System.unique_integer([:positive])}"
    assert {:ok, _pid} = Platform.create_team(team)
    assert team in Platform.TeamSupervisor.list_teams()

    assert :ok = Platform.shutdown_team(team)
    # Allow cleanup
    Process.sleep(50)
    refute team in Platform.TeamSupervisor.list_teams()
  end

  test "duplicate team returns error" do
    team = "dup-test-#{System.unique_integer([:positive])}"
    {:ok, _} = Platform.create_team(team)

    assert {:error, :already_exists} = Platform.create_team(team)

    Platform.shutdown_team(team)
  end

  test "shutdown nonexistent team returns error" do
    assert {:error, :not_found} = Platform.shutdown_team("nonexistent-#{System.unique_integer([:positive])}")
  end
end
