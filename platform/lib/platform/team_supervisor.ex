defmodule Platform.TeamSupervisor do
  @moduledoc """
  DynamicSupervisor that manages all active teams.
  Each team gets its own supervision tree.
  """
  use DynamicSupervisor

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Creates a new team with the given name.
  Returns `{:ok, pid}` or `{:error, reason}`.
  """
  def create_team(name, opts \\ []) do
    case Registry.lookup(Platform.TeamRegistry, name) do
      [{_pid, _}] ->
        {:error, :already_exists}

      [] ->
        child_spec = {Platform.Team.Supervisor, Keyword.merge(opts, name: name)}
        DynamicSupervisor.start_child(__MODULE__, child_spec)
    end
  end

  @doc """
  Shuts down a team by name, stopping all its agents and processes.
  """
  def shutdown_team(name) do
    case Registry.lookup(Platform.TeamRegistry, name) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Lists all active team names.
  """
  def list_teams do
    Registry.select(Platform.TeamRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end
end
