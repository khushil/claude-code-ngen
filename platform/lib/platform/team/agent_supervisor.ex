defmodule Platform.Team.AgentSupervisor do
  @moduledoc """
  DynamicSupervisor for agents within a team.
  Agents are started on demand by the Coordinator when tasks become unblocked.
  """
  use DynamicSupervisor

  def start_link(opts) do
    team = Keyword.fetch!(opts, :team)
    DynamicSupervisor.start_link(__MODULE__, opts, name: via(team))
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts an agent under this team's agent supervisor.
  """
  def start_agent(team, agent_opts) do
    child_spec = {Platform.Agent, agent_opts}
    DynamicSupervisor.start_child(via(team), child_spec)
  end

  def via(team), do: {:via, Registry, {Platform.TeamRegistry, {team, :agent_supervisor}}}
end
