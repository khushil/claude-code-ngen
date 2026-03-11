# Agent Platform (Phase 0)

An Elixir/OTP application for orchestrating Claude Code agent teams using BEAM primitives.

## How It Works

All agent work goes through `claude --print` CLI subprocesses, inheriting authentication from the user's existing Claude Code credentials (`~/.claude/.credentials.json`). No separate API key is needed.

The platform's value is **pure orchestration**: supervision trees, dependency graphs, message passing, retry logic, and crash recovery — all using BEAM primitives.

## Why BEAM?

The FORGE prompt template manually reimplements patterns that BEAM provides natively:

| FORGE Workaround | BEAM Native |
|------------------|-------------|
| `progress.yaml` on disk | GenServer state |
| `TaskList()` polling | `Registry.select/2` |
| `SendMessage()` tool call | `Process.send/2` |
| Retry logic (max 2) | Supervisor restart strategies |
| Shutdown coordination | `Supervisor.stop/1` |
| Parallel fork points | `Task.Supervisor.async_many/2` |

## Architecture

```
Platform.Supervisor
├── Platform.TeamRegistry (Registry)
├── Platform.TeamSupervisor (DynamicSupervisor)
│   └── Team "name" (Supervisor)
│       ├── Team.EventBus (GenServer)
│       ├── Team.AgentSupervisor (DynamicSupervisor)
│       │   └── Agent (GenServer) × N — each spawns `claude --print` via Port
│       └── Team.Coordinator (GenServer)
│           - dependency graph
│           - task states + retry budgets
│           - dispatches agents when tasks unblock
```

## Quick Start

```bash
cd platform

# Install dependencies
mix deps.get

# Run tests (uses mock CLI — no auth needed)
mix test

# Run the demo (requires authenticated `claude` CLI)
mix run -e "Platform.Demo.run()"
```

## API

```elixir
# Create a team
{:ok, _pid} = Platform.create_team("my-team")

# Add tasks with dependencies
Platform.add_task("my-team", %{
  id: "analyse",
  prompt: "Analyse the requirements...",
  system_prompt: "You are a technical analyst.",
  blocked_by: [],
  # Optional CLI config:
  model: "claude-opus-4-6",
  effort: "high",
  max_budget: 1.0
})

Platform.add_task("my-team", %{
  id: "implement",
  prompt: "Implement based on analysis...",
  blocked_by: ["analyse"]
})

# Start execution
:ok = Platform.start_execution("my-team")

# Check status
Platform.get_status("my-team")
# => %{tasks: %{"analyse" => %{state: :running, ...}, ...}, summary: %{total: 2, ...}}

# Get output
{:ok, result} = Platform.get_task_output("my-team", "analyse")

# Clean up
Platform.shutdown_team("my-team")
```

## Task Configuration

Each task supports these optional CLI config fields:

| Field | Description |
|-------|-------------|
| `model` | Claude model override (e.g., `"claude-opus-4-6"`) |
| `effort` | Effort level (`"low"`, `"high"`) |
| `allowed_tools` | Comma-separated tool list |
| `max_budget` | Max budget in USD |
| `working_dir` | Working directory for the agent |
| `system_prompt` | System prompt for the agent |

## Task States

```
:pending → :running → :completed
                   → :failed (after max_retries exhausted)
```

On failure, tasks retry up to `max_retries` times (default: 2) before being marked as permanently failed.

## Phase Roadmap

- **Phase 0** (current): CLI-based agents, standalone proof of concept
- **Phase 1**: MCP server integration
- **Phase 2**: FORGE-compatible orchestration, plugin packaging
- **Phase 3**: Distribution, persistence, Phoenix LiveView dashboard
