defmodule Platform.CLI do
  @moduledoc """
  Escript entry point for the agent platform.

  Supports two modes:

  - **One-shot** (default): reads a JSON task graph from stdin, runs orchestration,
    writes JSON results to stdout.
  - **Interactive** (`--interactive`): reads newline-delimited JSON commands from stdin,
    keeps the BEAM alive between commands so teams persist across calls.
  """

  require Logger

  def main(args) do
    # Suppress logger output so stdout stays clean JSON
    Logger.configure(level: :warning)
    {:ok, _} = Application.ensure_all_started(:platform)

    case args do
      ["--interactive"] -> interactive_loop()
      _ -> one_shot()
    end
  end

  # -- One-shot mode ----------------------------------------------------------

  defp one_shot do
    input = IO.read(:stdio, :eof)

    case Jason.decode(input) do
      {:ok, request} ->
        result = run_orchestration(request)
        IO.write(:stdio, Jason.encode!(result))

      {:error, reason} ->
        IO.write(:stdio, Jason.encode!(%{error: "Invalid JSON: #{inspect(reason)}"}))
    end
  end

  defp run_orchestration(%{"tasks" => tasks}) when is_list(tasks) do
    if tasks == [] do
      %{results: %{}, status: %{"total" => 0, "completed" => 0, "failed" => 0}}
    else
      run_orchestration_tasks(tasks)
    end
  end

  defp run_orchestration(_) do
    %{error: "Request must include a \"tasks\" array"}
  end

  defp run_orchestration_tasks(tasks) do
    team_name = "oneshot_#{System.unique_integer([:positive])}"

    case Platform.create_team(team_name) do
      {:ok, _pid} ->
        # Add all tasks
        add_results =
          Enum.map(tasks, fn task ->
            Platform.add_task(team_name, normalize_task(task))
          end)

        errors =
          add_results
          |> Enum.filter(fn
            {:error, _} -> true
            _ -> false
          end)

        if errors != [] do
          Platform.shutdown_team(team_name)
          %{error: "Failed to add tasks", details: inspect(errors)}
        else
          # Subscribe to team_done before starting
          Platform.Team.EventBus.subscribe(team_name, :team_done)

          case Platform.start_execution(team_name) do
            :ok ->
              wait_and_collect(team_name)

            {:error, reason} ->
              Platform.shutdown_team(team_name)
              %{error: "Failed to start execution", reason: inspect(reason)}
          end
        end

      {:error, reason} ->
        %{error: "Failed to create team", reason: inspect(reason)}
    end
  end

  defp wait_and_collect(team_name) do
    receive do
      {:event, :team_done, %{status: status}} ->
        results = collect_outputs(team_name, status)
        Platform.shutdown_team(team_name)
        results
    after
      600_000 ->
        status = Platform.get_status(team_name)
        Platform.shutdown_team(team_name)
        %{error: "Timed out after 600s", status: normalize_status(status)}
    end
  end

  defp collect_outputs(team_name, status) do
    %{tasks: task_statuses} = Platform.get_status(team_name)

    results =
      task_statuses
      |> Enum.map(fn {task_id, _info} ->
        case Platform.get_task_output(team_name, task_id) do
          {:ok, output} -> {task_id, output}
          {:error, reason} -> {task_id, %{error: inspect(reason)}}
        end
      end)
      |> Map.new()

    %{results: results, status: normalize_summary(status)}
  end

  # -- Interactive mode --------------------------------------------------------

  defp interactive_loop do
    case IO.gets(:stdio, "") do
      :eof ->
        :ok

      {:error, _} ->
        :ok

      line ->
        line |> String.trim() |> handle_command()
        interactive_loop()
    end
  end

  defp handle_command(""), do: :ok

  defp handle_command(line) do
    case Jason.decode(line) do
      {:ok, cmd} ->
        result = dispatch(cmd)
        IO.puts(Jason.encode!(result))

      {:error, reason} ->
        IO.puts(Jason.encode!(%{error: "Invalid JSON: #{inspect(reason)}"}))
    end
  end

  defp dispatch(%{"action" => "orchestrate", "tasks" => tasks}) do
    run_orchestration(%{"tasks" => tasks})
  end

  defp dispatch(%{"action" => "create_team", "name" => name}) do
    case Platform.create_team(name) do
      {:ok, _pid} -> %{ok: true, team: name}
      {:error, reason} -> %{error: inspect(reason)}
    end
  end

  defp dispatch(%{"action" => "add_task", "team" => team} = cmd) do
    task = normalize_task(cmd)

    case Platform.add_task(team, task) do
      {:ok, task_id} -> %{ok: true, task_id: task_id}
      {:error, reason} -> %{error: inspect(reason)}
    end
  end

  defp dispatch(%{"action" => "start", "team" => team}) do
    case Platform.start_execution(team) do
      :ok -> %{ok: true}
      {:error, reason} -> %{error: inspect(reason)}
    end
  end

  defp dispatch(%{"action" => "status", "team" => team}) do
    status = Platform.get_status(team)
    normalize_status(status)
  end

  defp dispatch(%{"action" => "output", "team" => team, "task_id" => task_id}) do
    case Platform.get_task_output(team, task_id) do
      {:ok, output} -> %{ok: true, output: output}
      {:error, reason} -> %{error: inspect(reason)}
    end
  end

  defp dispatch(%{"action" => "shutdown", "team" => team}) do
    case Platform.shutdown_team(team) do
      :ok -> %{ok: true}
      {:error, reason} -> %{error: inspect(reason)}
    end
  end

  defp dispatch(%{"action" => action}) do
    %{error: "Unknown action: #{action}"}
  end

  defp dispatch(_) do
    %{error: "Command must include an \"action\" field"}
  end

  # -- Helpers -----------------------------------------------------------------

  defp normalize_task(map) do
    base = %{
      id: map["id"],
      prompt: map["prompt"]
    }

    base
    |> maybe_put(:blocked_by, map["blocked_by"])
    |> maybe_put(:model, map["model"])
    |> maybe_put(:effort, map["effort"])
    |> maybe_put(:system_prompt, map["system_prompt"])
    |> maybe_put(:max_budget, map["max_budget"])
    |> maybe_put(:max_retries, map["max_retries"])
    |> maybe_put(:working_dir, map["working_dir"])
    |> maybe_put(:output_file, map["output_file"])
    |> maybe_put(:allowed_tools, map["allowed_tools"])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp normalize_status(%{tasks: tasks, summary: summary}) do
    %{
      tasks: normalize_tasks_map(tasks),
      summary: normalize_summary(summary)
    }
  end

  defp normalize_status(other), do: other

  defp normalize_tasks_map(tasks) when is_map(tasks) do
    tasks
    |> Enum.map(fn {k, v} ->
      {to_string(k), normalize_task_status(v)}
    end)
    |> Map.new()
  end

  defp normalize_task_status(info) when is_map(info) do
    info
    |> Enum.map(fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), jsonify(v)}
      {k, v} -> {k, jsonify(v)}
    end)
    |> Map.new()
  end

  defp normalize_summary(summary) when is_map(summary) do
    summary
    |> Enum.map(fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
    |> Map.new()
  end

  defp normalize_summary(other), do: other

  defp jsonify(v) when is_atom(v), do: Atom.to_string(v)
  defp jsonify(v), do: v
end
