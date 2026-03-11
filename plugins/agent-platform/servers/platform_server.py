"""MCP server for the BEAM-powered agent platform.

Thin wrapper using FastMCP SDK that spawns the platform escript in interactive
mode and exposes orchestration primitives as MCP tools.
"""

from mcp.server.fastmcp import FastMCP
import subprocess
import json
import os
import atexit

mcp = FastMCP("agent-platform")

# Resolve escript path relative to plugin root
PLUGIN_ROOT = os.environ.get(
    "CLAUDE_PLUGIN_ROOT", os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)
ESCRIPT = os.path.join(PLUGIN_ROOT, "..", "..", "platform", "platform")

# Single long-lived escript process in interactive mode
_proc = None


def _get_proc():
    """Get or spawn the interactive escript process."""
    global _proc
    if _proc is None or _proc.poll() is not None:
        _proc = subprocess.Popen(
            [ESCRIPT, "--interactive"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    return _proc


def _call(command: dict) -> dict:
    """Send a JSON command to the escript and read one JSON response line."""
    proc = _get_proc()
    proc.stdin.write(json.dumps(command) + "\n")
    proc.stdin.flush()
    line = proc.stdout.readline()
    if not line:
        raise RuntimeError("escript process returned no output")
    return json.loads(line)


def _cleanup():
    """Terminate the escript process on exit."""
    global _proc
    if _proc is not None and _proc.poll() is None:
        _proc.terminate()
        _proc.wait(timeout=5)


atexit.register(_cleanup)


@mcp.tool()
def orchestrate(tasks: list[dict]) -> str:
    """Run a multi-agent task DAG with dependency resolution, retry, and parallel execution.

    Each task needs: id (str), prompt (str).
    Optional: blocked_by (list[str]), model (str), effort (str),
    system_prompt (str), max_budget (float), max_retries (int).

    Returns JSON with results for each task.
    """
    result = _call({"action": "orchestrate", "tasks": tasks})
    return json.dumps(result, indent=2)


@mcp.tool()
def create_team(name: str) -> str:
    """Create a named agent team for multi-step orchestration."""
    return json.dumps(_call({"action": "create_team", "name": name}))


@mcp.tool()
def add_task(
    team: str,
    id: str,
    prompt: str,
    blocked_by: list[str] = None,
    model: str = None,
    effort: str = None,
    system_prompt: str = None,
) -> str:
    """Add a task to a team. Use blocked_by to declare dependencies on other task IDs."""
    cmd = {"action": "add_task", "team": team, "id": id, "prompt": prompt}
    if blocked_by:
        cmd["blocked_by"] = blocked_by
    if model:
        cmd["model"] = model
    if effort:
        cmd["effort"] = effort
    if system_prompt:
        cmd["system_prompt"] = system_prompt
    return json.dumps(_call(cmd))


@mcp.tool()
def start_execution(team: str) -> str:
    """Start executing all unblocked tasks in a team."""
    return json.dumps(_call({"action": "start", "team": team}))


@mcp.tool()
def get_status(team: str) -> str:
    """Get current status of all tasks in a team."""
    return json.dumps(
        _call({"action": "status", "team": team}), indent=2
    )


@mcp.tool()
def get_output(team: str, task_id: str) -> str:
    """Get the output of a completed task."""
    return json.dumps(
        _call({"action": "output", "team": team, "task_id": task_id})
    )


@mcp.tool()
def shutdown_team(team: str) -> str:
    """Shut down a team and release resources."""
    return json.dumps(_call({"action": "shutdown", "team": team}))


if __name__ == "__main__":
    mcp.run(transport="stdio")
