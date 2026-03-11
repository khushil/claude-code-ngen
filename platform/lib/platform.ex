defmodule Platform do
  @moduledoc """
  Agent Platform — an Elixir/OTP application for orchestrating Claude Code agent teams.

  All agent work goes through `claude --print` CLI subprocesses, inheriting
  the user's existing Claude Code authentication. The platform's value is
  pure orchestration: supervision, dependency graphs, message passing, retry.
  """

  defdelegate create_team(name, opts \\ []), to: Platform.TeamSupervisor
  defdelegate shutdown_team(name), to: Platform.TeamSupervisor
  defdelegate add_task(team, task), to: Platform.Team.Coordinator
  defdelegate start_execution(team), to: Platform.Team.Coordinator
  defdelegate get_status(team), to: Platform.Team.Coordinator
  defdelegate get_task_output(team, task_id), to: Platform.Team.Coordinator
end
