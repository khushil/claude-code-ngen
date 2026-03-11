defmodule Platform.Team.EventBus do
  @moduledoc """
  Simple pub/sub event bus for a team.
  Processes subscribe to events and receive messages when events are broadcast.
  """
  use GenServer

  # --- Client API ---

  def start_link(opts) do
    team = Keyword.fetch!(opts, :team)
    GenServer.start_link(__MODULE__, opts, name: via(team))
  end

  def subscribe(team, event_type) do
    GenServer.call(via(team), {:subscribe, event_type, self()})
  end

  def broadcast(team, event_type, payload) do
    GenServer.cast(via(team), {:broadcast, event_type, payload})
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    {:ok, %{subscribers: %{}}}
  end

  @impl true
  def handle_call({:subscribe, event_type, pid}, _from, state) do
    Process.monitor(pid)
    subs = Map.update(state.subscribers, event_type, MapSet.new([pid]), &MapSet.put(&1, pid))
    {:reply, :ok, %{state | subscribers: subs}}
  end

  @impl true
  def handle_cast({:broadcast, event_type, payload}, state) do
    case Map.get(state.subscribers, event_type, MapSet.new()) do
      subs ->
        Enum.each(subs, fn pid ->
          send(pid, {:event, event_type, payload})
        end)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    subs =
      Map.new(state.subscribers, fn {event_type, pids} ->
        {event_type, MapSet.delete(pids, pid)}
      end)

    {:noreply, %{state | subscribers: subs}}
  end

  defp via(team), do: {:via, Registry, {Platform.TeamRegistry, {team, :event_bus}}}
end
