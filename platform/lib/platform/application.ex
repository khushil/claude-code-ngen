defmodule Platform.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Platform.TeamRegistry},
      {Platform.TeamSupervisor, []}
    ]

    opts = [strategy: :one_for_one, name: Platform.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
