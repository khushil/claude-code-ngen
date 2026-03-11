defmodule Platform.Demo do
  @moduledoc """
  Demonstrates the agent platform with a 3-task dependency graph.

  All tasks execute via `claude --print` CLI subprocesses, inheriting
  auth from the user's existing Claude Code credentials.

  Task graph:
    analyse (no deps) ──┐
                        ├──► implement (blocked by analyse)
                        │
                        └──► review (blocked by analyse + implement)

  Run with: mix demo
  Or: mix run -e "Platform.Demo.run()"
  """
  require Logger

  def run do
    Logger.info("=== Agent Platform Phase 0 Demo ===")

    # Create a team
    {:ok, _pid} = Platform.create_team("demo")
    Logger.info("Created team 'demo'")

    # Add tasks with dependency graph
    {:ok, _} =
      Platform.add_task("demo", %{
        id: "analyse",
        prompt: """
        You are a software analyst. Analyse the following requirement and produce a brief
        technical specification (3-5 bullet points).

        Requirement: Build a CLI tool that converts Markdown files to HTML.
        It should support tables, code blocks with syntax highlighting, and custom CSS themes.

        Output a concise technical spec.
        """,
        system_prompt: "You are a concise technical analyst. Output only the specification, no preamble.",
        blocked_by: []
      })

    {:ok, _} =
      Platform.add_task("demo", %{
        id: "implement",
        prompt: """
        You are a software architect. Given the technical specification from the analysis phase,
        outline the implementation plan with module structure and key function signatures.

        Use the analysis output provided in the dependency context below.
        Output a brief implementation plan (5-8 bullet points with code signatures).
        """,
        system_prompt: "You are a concise software architect. Output only the plan, no preamble.",
        blocked_by: ["analyse"]
      })

    {:ok, _} =
      Platform.add_task("demo", %{
        id: "review",
        prompt: """
        You are a code reviewer. Review the implementation plan for potential issues,
        missing edge cases, and improvement suggestions.

        Use both the analysis and implementation outputs provided in the dependency context.
        Output a brief review (3-5 points).
        """,
        system_prompt: "You are a concise code reviewer. Output only the review, no preamble.",
        blocked_by: ["analyse", "implement"]
      })

    Logger.info("Added 3 tasks: analyse → implement → review")

    # Subscribe to team events
    Platform.Team.EventBus.subscribe("demo", :task_completed)
    Platform.Team.EventBus.subscribe("demo", :task_failed)
    Platform.Team.EventBus.subscribe("demo", :team_done)

    # Start execution
    :ok = Platform.start_execution("demo")
    Logger.info("Execution started — waiting for completion...")

    # Wait for all tasks to complete
    wait_for_completion("demo")

    # Print results
    print_results("demo")

    # Clean up
    Platform.shutdown_team("demo")
    Logger.info("=== Demo complete ===")
  end

  defp wait_for_completion(team) do
    receive do
      {:event, :task_completed, %{task_id: id}} ->
        Logger.info("  ✓ Task '#{id}' completed")
        wait_for_completion(team)

      {:event, :task_failed, %{task_id: id, error: error}} ->
        Logger.error("  ✗ Task '#{id}' failed: #{inspect(error)}")
        wait_for_completion(team)

      {:event, :team_done, %{status: status}} ->
        Logger.info("All tasks done: #{status.completed}/#{status.total} completed, #{status.failed} failed")
    after
      300_000 ->
        Logger.error("Timed out waiting for team completion")
    end
  end

  defp print_results(team) do
    %{tasks: tasks} = Platform.get_status(team)

    Enum.each(tasks, fn {id, info} ->
      IO.puts("\n#{'=' |> String.duplicate(60)}")
      IO.puts("Task: #{id} (#{info.state})")
      IO.puts(String.duplicate("=", 60))

      case Platform.get_task_output(team, id) do
        {:ok, output} ->
          IO.puts(String.slice(output, 0, 500))
          if String.length(output) > 500, do: IO.puts("... (truncated)")

        {:error, reason} ->
          IO.puts("No output: #{inspect(reason)}")
      end
    end)
  end
end
