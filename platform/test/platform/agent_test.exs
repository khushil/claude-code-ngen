defmodule Platform.AgentTest do
  @moduledoc """
  Tests for Platform.Agent — the unified CLI-based agent.
  Tests pure functions directly and integration via mock_claude.sh.
  """
  use ExUnit.Case, async: true

  alias Platform.Agent

  # --- build_prompt/2 ---

  describe "build_prompt/2" do
    test "returns prompt unchanged when no dependencies" do
      assert Agent.build_prompt("Do something", %{}) == "Do something"
    end

    test "includes dependency context with XML tags" do
      deps = %{"analyse" => "analysis output here"}
      result = Agent.build_prompt("Implement this", deps)

      assert result =~ "Implement this"
      assert result =~ "<dependency id=\"analyse\">"
      assert result =~ "analysis output here"
      assert result =~ "</dependency>"
      assert result =~ "Context from completed dependencies"
    end

    test "includes multiple dependencies" do
      deps = %{"a" => "output a", "b" => "output b"}
      result = Agent.build_prompt("Do work", deps)

      assert result =~ "<dependency id=\"a\">"
      assert result =~ "output a"
      assert result =~ "<dependency id=\"b\">"
      assert result =~ "output b"
    end
  end

  # --- parse_response/1 ---

  describe "parse_response/1" do
    test "parses standard claude --print JSON response" do
      json = ~s({"messages":[{"role":"assistant","content":[{"type":"text","text":"hello world"}]}]})
      assert {:ok, "hello world"} = Agent.parse_response(json)
    end

    test "parses response with multiple text blocks" do
      json = Jason.encode!(%{
        "messages" => [%{
          "role" => "assistant",
          "content" => [
            %{"type" => "text", "text" => "part 1"},
            %{"type" => "text", "text" => "part 2"}
          ]
        }]
      })

      assert {:ok, "part 1\npart 2"} = Agent.parse_response(json)
    end

    test "handles direct content array fallback" do
      json = Jason.encode!(%{
        "content" => [%{"type" => "text", "text" => "direct content"}]
      })

      assert {:ok, "direct content"} = Agent.parse_response(json)
    end

    test "returns error for invalid JSON" do
      assert {:error, {:json_decode_error, _}} = Agent.parse_response("not json")
    end

    test "returns error for unexpected format" do
      json = Jason.encode!(%{"something" => "else"})
      assert {:error, {:unexpected_format, _}} = Agent.parse_response(json)
    end

    test "returns error when no assistant message" do
      json = Jason.encode!(%{
        "messages" => [%{"role" => "user", "content" => [%{"type" => "text", "text" => "hi"}]}]
      })

      assert {:error, :no_assistant_message} = Agent.parse_response(json)
    end

    test "returns error when no text content" do
      json = Jason.encode!(%{
        "messages" => [%{
          "role" => "assistant",
          "content" => [%{"type" => "tool_use", "id" => "1", "name" => "foo"}]
        }]
      })

      assert {:error, :no_text_content} = Agent.parse_response(json)
    end
  end

  # --- build_cli_command/2 ---

  describe "build_cli_command/2" do
    test "builds minimal command with defaults" do
      config = %{model: nil, effort: nil, allowed_tools: nil, max_budget: nil, working_dir: nil, system_prompt: nil}
      cmd = Agent.build_cli_command(config, "/tmp/prompt.txt")

      assert cmd =~ "--print"
      assert cmd =~ "--output-format"
      assert cmd =~ "json"
      assert cmd =~ "--dangerously-skip-permissions"
      assert cmd =~ "< '/tmp/prompt.txt'"
      refute cmd =~ "--model"
      refute cmd =~ "--effort"
    end

    test "includes model when specified" do
      config = %{model: "claude-opus-4-6", effort: nil, allowed_tools: nil, max_budget: nil, working_dir: nil, system_prompt: nil}
      cmd = Agent.build_cli_command(config, "/tmp/prompt.txt")

      assert cmd =~ "--model"
      assert cmd =~ "claude-opus-4-6"
    end

    test "includes effort when specified" do
      config = %{model: nil, effort: "high", allowed_tools: nil, max_budget: nil, working_dir: nil, system_prompt: nil}
      cmd = Agent.build_cli_command(config, "/tmp/prompt.txt")

      assert cmd =~ "--effort"
      assert cmd =~ "high"
    end

    test "includes all options" do
      config = %{
        model: "claude-sonnet-4-6",
        effort: "low",
        allowed_tools: "Read,Grep",
        max_budget: 0.5,
        working_dir: nil,
        system_prompt: "Be concise"
      }
      cmd = Agent.build_cli_command(config, "/tmp/p.txt")

      assert cmd =~ "--model"
      assert cmd =~ "--effort"
      assert cmd =~ "--allowed-tools"
      assert cmd =~ "--max-budget-usd"
      assert cmd =~ "--system-prompt"
    end
  end

  # --- Integration test using mock_claude.sh ---

  describe "integration with mock CLI" do
    test "agent completes successfully via Port" do
      {:ok, _} = Application.ensure_all_started(:platform)

      team = "agent-test-#{System.unique_integer([:positive])}"
      {:ok, _pid} = Platform.create_team(team)

      on_exit(fn -> Platform.shutdown_team(team) end)

      coordinator = self()

      {:ok, pid} =
        Platform.Agent.start_link(
          team: team,
          task_id: "test_task",
          prompt: "Hello",
          coordinator: coordinator,
          dependency_outputs: %{}
        )

      assert_receive {:agent_completed, "test_task", "Mock response for task"}, 10_000

      # Agent stops after reporting — give it a moment to terminate
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000
    end

    test "agent includes dependency context" do
      {:ok, _} = Application.ensure_all_started(:platform)

      team = "agent-dep-test-#{System.unique_integer([:positive])}"
      {:ok, _pid} = Platform.create_team(team)

      on_exit(fn -> Platform.shutdown_team(team) end)

      coordinator = self()

      {:ok, _pid} =
        Platform.Agent.start_link(
          team: team,
          task_id: "downstream",
          prompt: "Use the dependency output",
          coordinator: coordinator,
          dependency_outputs: %{"upstream" => "upstream result"}
        )

      # Mock CLI doesn't use the prompt, but the agent should still complete
      assert_receive {:agent_completed, "downstream", "Mock response for task"}, 10_000
    end
  end
end
