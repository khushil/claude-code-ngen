defmodule Platform.Team.Coordinator do
  @moduledoc """
  Orchestrates task execution within a team.

  Maintains a dependency graph and task state machine. When tasks become
  unblocked (all dependencies completed), spawns agents to execute them
  via the Claude CLI subprocess.

  Task states: :pending → :running → :completed | :failed
  """
  use GenServer
  require Logger

  defmodule Task do
    @moduledoc "A unit of work within a team."
    defstruct [
      :id,
      :prompt,
      :output_file,
      :system_prompt,
      model: nil,
      effort: nil,
      allowed_tools: nil,
      max_budget: nil,
      working_dir: nil,
      blocked_by: [],
      state: :pending,
      result: nil,
      error: nil,
      agent_pid: nil,
      retries: 0,
      max_retries: 2
    ]
  end

  # --- Client API ---

  def start_link(opts) do
    team = Keyword.fetch!(opts, :team)
    GenServer.start_link(__MODULE__, opts, name: via(team))
  end

  @doc """
  Adds a task to the team's execution plan.
  Task map must include :id and :prompt, optionally :blocked_by, :output_file, :system_prompt.
  """
  def add_task(team, task_attrs) when is_map(task_attrs) do
    GenServer.call(via(team), {:add_task, task_attrs})
  end

  @doc """
  Begins executing all unblocked tasks.
  """
  def start_execution(team) do
    GenServer.call(via(team), :start_execution)
  end

  @doc """
  Returns the current status of all tasks.
  """
  def get_status(team) do
    GenServer.call(via(team), :get_status)
  end

  @doc """
  Returns the output of a completed task.
  """
  def get_task_output(team, task_id) do
    GenServer.call(via(team), {:get_task_output, task_id})
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    team = Keyword.fetch!(opts, :team)

    state = %{
      team: team,
      tasks: %{},
      execution_started: false
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:add_task, attrs}, _from, state) do
    if state.execution_started do
      {:reply, {:error, :execution_already_started}, state}
    else
      task = %Task{
        id: Map.fetch!(attrs, :id),
        prompt: Map.fetch!(attrs, :prompt),
        blocked_by: Map.get(attrs, :blocked_by, []),
        output_file: Map.get(attrs, :output_file),
        system_prompt: Map.get(attrs, :system_prompt),
        model: Map.get(attrs, :model),
        effort: Map.get(attrs, :effort),
        allowed_tools: Map.get(attrs, :allowed_tools),
        max_budget: Map.get(attrs, :max_budget),
        working_dir: Map.get(attrs, :working_dir),
        max_retries: Map.get(attrs, :max_retries, 2)
      }

      # Forward references allowed — validated at start_execution
      state = put_in(state.tasks[task.id], task)
      {:reply, {:ok, task.id}, state}
    end
  end

  @impl true
  def handle_call(:start_execution, _from, state) do
    # Validate all dependencies reference existing tasks
    all_ids = Map.keys(state.tasks)

    invalid =
      Enum.flat_map(state.tasks, fn {id, task} ->
        Enum.map(task.blocked_by -- all_ids, &{id, &1})
      end)

    if invalid != [] do
      {:reply, {:error, {:invalid_dependencies, invalid}}, state}
    else
      state = %{state | execution_started: true}
      state = dispatch_ready_tasks(state)
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status =
      Map.new(state.tasks, fn {id, task} ->
        {id,
         %{
           state: task.state,
           retries: task.retries,
           blocked_by: task.blocked_by,
           has_result: task.result != nil,
           error: task.error
         }}
      end)

    summary = %{
      total: map_size(state.tasks),
      pending: count_by_state(state.tasks, :pending),
      running: count_by_state(state.tasks, :running),
      completed: count_by_state(state.tasks, :completed),
      failed: count_by_state(state.tasks, :failed)
    }

    {:reply, %{tasks: status, summary: summary}, state}
  end

  @impl true
  def handle_call({:get_task_output, task_id}, _from, state) do
    case Map.get(state.tasks, task_id) do
      nil -> {:reply, {:error, :not_found}, state}
      %Task{state: :completed, result: result} -> {:reply, {:ok, result}, state}
      %Task{state: s} -> {:reply, {:error, {:not_completed, s}}, state}
    end
  end

  @impl true
  def handle_info({:agent_completed, task_id, result}, state) do
    Logger.info("[#{state.team}] Task #{task_id} completed")

    state = update_task(state, task_id, fn task ->
      %{task | state: :completed, result: result, agent_pid: nil}
    end)

    Platform.Team.EventBus.broadcast(state.team, :task_completed, %{
      task_id: task_id,
      team: state.team
    })

    # Dispatch any tasks that were blocked by this one
    state = dispatch_ready_tasks(state)

    # Check if all tasks are done
    maybe_notify_all_done(state)

    {:noreply, state}
  end

  @impl true
  def handle_info({:agent_failed, task_id, error}, state) do
    task = state.tasks[task_id]

    if task.retries < task.max_retries do
      Logger.warning("[#{state.team}] Task #{task_id} failed (attempt #{task.retries + 1}/#{task.max_retries + 1}), retrying: #{inspect(error)}")

      state = update_task(state, task_id, fn t ->
        %{t | state: :pending, retries: t.retries + 1, agent_pid: nil, error: nil}
      end)

      state = dispatch_ready_tasks(state)
      {:noreply, state}
    else
      Logger.error("[#{state.team}] Task #{task_id} failed permanently after #{task.retries + 1} attempts: #{inspect(error)}")

      state = update_task(state, task_id, fn t ->
        %{t | state: :failed, error: error, agent_pid: nil}
      end)

      Platform.Team.EventBus.broadcast(state.team, :task_failed, %{
        task_id: task_id,
        team: state.team,
        error: error
      })

      maybe_notify_all_done(state)
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    # Find the task this agent was working on
    case Enum.find(state.tasks, fn {_id, t} -> t.agent_pid == pid end) do
      {task_id, _task} when reason != :normal ->
        send(self(), {:agent_failed, task_id, {:agent_crashed, reason}})
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  # --- Private ---

  defp dispatch_ready_tasks(%{execution_started: false} = state), do: state

  defp dispatch_ready_tasks(state) do
    ready_tasks =
      state.tasks
      |> Enum.filter(fn {_id, task} ->
        task.state == :pending and dependencies_met?(task, state.tasks)
      end)

    Enum.reduce(ready_tasks, state, fn {task_id, task}, acc ->
      spawn_agent(acc, task_id, task)
    end)
  end

  defp dependencies_met?(task, all_tasks) do
    Enum.all?(task.blocked_by, fn dep_id ->
      case Map.get(all_tasks, dep_id) do
        %Task{state: :completed} -> true
        _ -> false
      end
    end)
  end

  defp spawn_agent(state, task_id, task) do
    coordinator = self()

    # Gather dependency outputs for context
    dep_outputs =
      Enum.reduce(task.blocked_by, %{}, fn dep_id, acc ->
        case Map.get(state.tasks, dep_id) do
          %Task{result: result} when result != nil -> Map.put(acc, dep_id, result)
          _ -> acc
        end
      end)

    agent_opts = [
      team: state.team,
      task_id: task_id,
      prompt: task.prompt,
      system_prompt: task.system_prompt,
      coordinator: coordinator,
      dependency_outputs: dep_outputs,
      model: task.model,
      effort: task.effort,
      allowed_tools: task.allowed_tools,
      max_budget: task.max_budget,
      working_dir: task.working_dir
    ]

    case Platform.Team.AgentSupervisor.start_agent(state.team, agent_opts) do
      {:ok, pid} ->
        Process.monitor(pid)
        Logger.info("[#{state.team}] Started agent for task #{task_id} (pid: #{inspect(pid)})")

        update_task(state, task_id, fn t ->
          %{t | state: :running, agent_pid: pid}
        end)

      {:error, reason} ->
        Logger.error("[#{state.team}] Failed to start agent for task #{task_id}: #{inspect(reason)}")

        send(self(), {:agent_failed, task_id, {:spawn_failed, reason}})
        state
    end
  end

  defp update_task(state, task_id, fun) do
    task = fun.(state.tasks[task_id])
    put_in(state.tasks[task_id], task)
  end

  defp count_by_state(tasks, target_state) do
    Enum.count(tasks, fn {_id, t} -> t.state == target_state end)
  end

  defp maybe_notify_all_done(state) do
    all_terminal =
      Enum.all?(state.tasks, fn {_id, t} ->
        t.state in [:completed, :failed]
      end)

    if all_terminal do
      Logger.info("[#{state.team}] All tasks finished")

      Platform.Team.EventBus.broadcast(state.team, :team_done, %{
        team: state.team,
        status: get_summary(state)
      })
    end
  end

  defp get_summary(state) do
    %{
      total: map_size(state.tasks),
      completed: count_by_state(state.tasks, :completed),
      failed: count_by_state(state.tasks, :failed)
    }
  end

  defp via(team), do: {:via, Registry, {Platform.TeamRegistry, {team, :coordinator}}}
end
