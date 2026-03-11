defmodule Platform.Agent do
  @moduledoc """
  Unified agent that executes tasks via `claude --print` CLI subprocess.

  Spawns a Port running the Claude CLI, streams output, parses the JSON
  response, and reports results back to the Coordinator. Inherits auth
  from the user's existing Claude Code credentials — no API key needed.

  Replaces both LightAgent and ClaudeAPI.
  """
  use GenServer, restart: :temporary
  require Logger

  # --- Client API ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    state = %{
      team: Keyword.fetch!(opts, :team),
      task_id: Keyword.fetch!(opts, :task_id),
      prompt: Keyword.fetch!(opts, :prompt),
      system_prompt: Keyword.get(opts, :system_prompt),
      coordinator: Keyword.fetch!(opts, :coordinator),
      dependency_outputs: Keyword.get(opts, :dependency_outputs, %{}),
      model: Keyword.get(opts, :model),
      effort: Keyword.get(opts, :effort),
      allowed_tools: Keyword.get(opts, :allowed_tools),
      max_budget: Keyword.get(opts, :max_budget),
      working_dir: Keyword.get(opts, :working_dir),
      port: nil,
      buffer: "",
      prompt_file: nil
    }

    timeout = Application.get_env(:platform, :agent_timeout, 300_000)

    {:ok, state, {:continue, {:execute, timeout}}}
  end

  @impl true
  def handle_continue({:execute, timeout}, state) do
    Logger.info("[#{state.team}] Agent executing task #{state.task_id}")

    full_prompt = build_prompt(state.prompt, state.dependency_outputs)

    # Write prompt to temp file to avoid argument length limits
    prompt_file = Path.join(System.tmp_dir!(), "platform_#{:erlang.unique_integer([:positive])}.txt")
    File.write!(prompt_file, full_prompt)

    config = %{
      model: state.model,
      effort: state.effort,
      allowed_tools: state.allowed_tools,
      max_budget: state.max_budget,
      working_dir: state.working_dir,
      system_prompt: state.system_prompt
    }

    cmd = build_cli_command(config, prompt_file)

    port =
      Port.open(
        {:spawn, cmd},
        [:binary, :exit_status, :stderr_to_stdout]
      )

    Process.send_after(self(), :timeout, timeout)

    {:noreply, %{state | port: port, prompt_file: prompt_file}}
  end

  @impl true
  def handle_info({port, {:data, chunk}}, %{port: port} = state) do
    {:noreply, %{state | buffer: state.buffer <> chunk}}
  end

  @impl true
  def handle_info({port, {:exit_status, 0}}, %{port: port} = state) do
    cleanup_prompt_file(state.prompt_file)

    case parse_response(state.buffer) do
      {:ok, text} ->
        Logger.info("[#{state.team}] Agent completed task #{state.task_id} (#{String.length(text)} chars)")
        send(state.coordinator, {:agent_completed, state.task_id, text})

      {:error, reason} ->
        Logger.warning("[#{state.team}] Agent failed to parse response for task #{state.task_id}: #{inspect(reason)}")
        send(state.coordinator, {:agent_failed, state.task_id, {:parse_error, reason}})
    end

    {:stop, :normal, state}
  end

  @impl true
  def handle_info({port, {:exit_status, code}}, %{port: port} = state) do
    cleanup_prompt_file(state.prompt_file)
    Logger.warning("[#{state.team}] Agent CLI exited with code #{code} for task #{state.task_id}")
    send(state.coordinator, {:agent_failed, state.task_id, {:cli_exit, code, state.buffer}})
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:timeout, state) do
    Logger.warning("[#{state.team}] Agent timed out for task #{state.task_id}")

    if state.port do
      Port.close(state.port)
    end

    cleanup_prompt_file(state.prompt_file)
    send(state.coordinator, {:agent_failed, state.task_id, :timeout})
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    cleanup_prompt_file(state.prompt_file)
    :ok
  end

  # --- Public pure functions (for testing) ---

  @doc """
  Builds the full prompt with dependency context using XML-style tags.
  """
  def build_prompt(prompt, dependency_outputs) when map_size(dependency_outputs) == 0 do
    prompt
  end

  def build_prompt(prompt, dependency_outputs) do
    dep_context =
      dependency_outputs
      |> Enum.map(fn {task_id, output} ->
        "<dependency id=\"#{task_id}\">\n#{output}\n</dependency>"
      end)
      |> Enum.join("\n\n")

    """
    #{prompt}

    ---

    Context from completed dependencies:

    #{dep_context}\
    """
  end

  @doc """
  Parses the JSON response from `claude --print --output-format json`.

  Expects: `{"messages": [{"role": "assistant", "content": [{"type": "text", "text": "..."}]}]}`
  """
  def parse_response(raw) do
    case Jason.decode(raw) do
      {:ok, %{"messages" => messages}} ->
        extract_text_from_messages(messages)

      {:ok, %{"content" => content}} ->
        # Fallback: direct content array (some CLI versions)
        extract_text_from_content(content)

      {:ok, other} ->
        {:error, {:unexpected_format, other}}

      {:error, reason} ->
        {:error, {:json_decode_error, reason}}
    end
  end

  @doc """
  Builds the CLI command string for `claude --print`.
  """
  def build_cli_command(config, prompt_file) do
    executable = Application.get_env(:platform, :claude_executable, "claude")

    args =
      [
        executable,
        "--print",
        "--output-format", "json",
        "--dangerously-skip-permissions"
      ]
      |> maybe_add("--model", config[:model])
      |> maybe_add("--effort", config[:effort])
      |> maybe_add("--allowed-tools", config[:allowed_tools])
      |> maybe_add("--max-budget-usd", config[:max_budget])
      |> maybe_add("--system-prompt", config[:system_prompt])

    cmd = Enum.join(args, " ")
    "#{cmd} < #{shell_escape(prompt_file)}"
  end

  # --- Private ---

  defp extract_text_from_messages(messages) do
    assistant_msg =
      Enum.find(messages, fn msg -> msg["role"] == "assistant" end)

    case assistant_msg do
      %{"content" => content} -> extract_text_from_content(content)
      nil -> {:error, :no_assistant_message}
    end
  end

  defp extract_text_from_content(content) when is_list(content) do
    text_parts =
      content
      |> Enum.filter(fn block -> block["type"] == "text" end)
      |> Enum.map(fn block -> block["text"] end)

    case text_parts do
      [] -> {:error, :no_text_content}
      parts -> {:ok, Enum.join(parts, "\n")}
    end
  end

  defp extract_text_from_content(_), do: {:error, :invalid_content_format}

  defp maybe_add(args, _flag, nil), do: args
  defp maybe_add(args, flag, value), do: args ++ [flag, shell_escape(to_string(value))]

  defp shell_escape(str) do
    "'#{String.replace(str, "'", "'\\''")}'"
  end

  defp cleanup_prompt_file(nil), do: :ok
  defp cleanup_prompt_file(path), do: File.rm(path)
end
