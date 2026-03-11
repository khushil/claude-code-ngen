defmodule Platform.Team.Supervisor do
  @moduledoc """
  Per-team supervisor. Starts the Coordinator, EventBus,
  and a DynamicSupervisor for light agents.
  """
  use Supervisor

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)

    Supervisor.start_link(__MODULE__, opts,
      name: {:via, Registry, {Platform.TeamRegistry, name}}
    )
  end

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)

    children = [
      {Platform.Team.EventBus, team: name},
      {Platform.Team.AgentSupervisor, team: name},
      {Platform.Team.Coordinator, team: name}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
