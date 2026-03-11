---
allowed-tools: mcp__plugin_agent-platform_platform__orchestrate, mcp__plugin_agent-platform_platform__create_team, mcp__plugin_agent-platform_platform__add_task, mcp__plugin_agent-platform_platform__start_execution, mcp__plugin_agent-platform_platform__get_status, mcp__plugin_agent-platform_platform__get_output, mcp__plugin_agent-platform_platform__shutdown_team
description: Decompose a task into a multi-agent DAG and execute it on the BEAM platform
argument-hint: <describe the task to orchestrate>
---

You are an orchestration planner. The user wants you to accomplish a task using multiple parallel agents coordinated by the BEAM-powered agent platform.

## Your job

1. **Analyse the request**: Break `$ARGUMENTS` into discrete subtasks that can run in parallel or have clear dependencies.
2. **Build a task DAG**: Each task needs an `id`, `prompt`, and optionally `blocked_by` (list of task IDs it depends on). Tasks without dependencies run in parallel automatically.
3. **Call the `orchestrate` tool**: Pass the full task list. The platform handles scheduling, dependency resolution, retry on failure, and BEAM supervision.
4. **Present results**: Once orchestration completes, summarise the consolidated output clearly for the user.

## Guidelines

- Keep individual task prompts focused and self-contained.
- Use `blocked_by` only when a task genuinely needs another task's output.
- Prefer wide parallelism — more independent tasks run faster.
- Each task runs as a separate `claude --print` subprocess with its own context.
- Downstream tasks automatically receive the outputs of their dependencies as context.

## Example task DAG

```json
[
  {"id": "research", "prompt": "Research the current best practices for X"},
  {"id": "analyse", "prompt": "Analyse the codebase for patterns related to X"},
  {"id": "plan", "prompt": "Create an implementation plan based on research and analysis", "blocked_by": ["research", "analyse"]},
  {"id": "implement", "prompt": "Implement the plan", "blocked_by": ["plan"]},
  {"id": "test", "prompt": "Write tests for the implementation", "blocked_by": ["implement"]}
]
```
