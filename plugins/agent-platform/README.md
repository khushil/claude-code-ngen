# agent-platform

BEAM-powered multi-agent orchestration with dependency graphs, retry, and supervision.

## Overview

This plugin exposes the Elixir agent platform as both a **native CLI API** and a set of **MCP tools** for Claude Code. It lets you run multi-agent task DAGs where each task is a `claude --print` subprocess, coordinated by BEAM supervision trees with automatic dependency resolution, parallel execution, and retry on failure.

## Architecture

```
┌─────────────────────────┐    ┌─────────────────────────────┐
│  Native API (direct)    │    │  MCP Layer (Claude Code)    │
│                         │    │                             │
│  echo '{}' | ./platform │    │  FastMCP stdio server       │
│  curl / scripts / CI    │    │  auto-started by plugin     │
└───────────┬─────────────┘    └──────────────┬──────────────┘
            │                                 │
            └────────────┬────────────────────┘
                         ▼
              Platform escript (Elixir binary)
                         │
                         ▼
              BEAM supervision tree
              ├── Agent → claude --print
              ├── Agent → claude --print
              └── Agent → claude --print
```

## Usage

### Via Claude Code (MCP)

Install the plugin, then use the `/orchestrate` command:

```
/orchestrate Build a REST API with tests and documentation
```

Claude will decompose the request into a task DAG and execute it on the platform.

### Direct MCP tools

The plugin exposes 7 MCP tools:

| Tool | Description |
|------|-------------|
| `orchestrate` | Run a complete task DAG (one-shot convenience) |
| `create_team` | Create a named agent team |
| `add_task` | Add a task to a team with optional dependencies |
| `start_execution` | Start executing unblocked tasks |
| `get_status` | Get current status of all tasks |
| `get_output` | Get the output of a completed task |
| `shutdown_team` | Shut down a team and release resources |

### Native API (no Claude Code required)

Build the escript once:

```bash
cd platform && mix escript.build
```

**One-shot mode** — pipe a task graph, get results:

```bash
echo '{"tasks":[{"id":"t1","prompt":"Say hello"}]}' | ./platform
```

**Interactive mode** — keep the BEAM alive for multiple commands:

```bash
./platform --interactive
# Then send newline-delimited JSON commands:
{"action":"create_team","name":"my-team"}
{"action":"add_task","team":"my-team","id":"t1","prompt":"Analyse the code"}
{"action":"add_task","team":"my-team","id":"t2","prompt":"Write tests","blocked_by":["t1"]}
{"action":"start","team":"my-team"}
{"action":"status","team":"my-team"}
{"action":"shutdown","team":"my-team"}
```

## Task format

Each task accepts:

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique task identifier |
| `prompt` | Yes | Instruction for the Claude agent |
| `blocked_by` | No | List of task IDs this task depends on |
| `model` | No | Claude model to use |
| `effort` | No | Effort level for the agent |
| `system_prompt` | No | System-level instructions |
| `max_budget` | No | Max budget in USD |
| `max_retries` | No | Maximum retry attempts (default: 2) |
| `working_dir` | No | Working directory for the agent |
| `output_file` | No | File path to write output to |

## Dependencies

- **Elixir/Erlang** — for building the escript (one-time compile)
- **Python 3.8+** with `mcp` package — for the MCP layer only (`pip install mcp`)
- The built escript is self-contained (no runtime Elixir dependency)
