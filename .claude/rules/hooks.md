---
globs: ["plugins/**/hooks/*.py", "plugins/**/hooks/hooks.json"]
---

# Plugin Hook Development

## hooks.json Schema

Each plugin with hooks must have `hooks/hooks.json`:

```json
{
  "description": "What these hooks do",
  "hooks": {
    "EventName": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/script.py",
            "timeout": 10
          }
        ],
        "matcher": "Edit|Write"
      }
    ]
  }
}
```

### Fields

- `type` — always `"command"` for plugin hooks
- `command` — shell command to execute. Use `${CLAUDE_PLUGIN_ROOT}` for paths relative to the plugin root.
- `timeout` — seconds before the hook is killed (default: varies, recommend 10)
- `matcher` — optional regex to match tool names (e.g., `"Edit|Write|MultiEdit"`). Only for PreToolUse/PostToolUse.

## Supported Events

| Event | When it fires |
|-------|--------------|
| `PreToolUse` | Before a tool executes (can block it) |
| `PostToolUse` | After a tool executes |
| `Stop` | When Claude is about to stop responding |
| `UserPromptSubmit` | When the user submits a prompt |
| `SessionStart` | When a new session begins |

## Python Hook I/O

### Input
Hooks receive a JSON object on **stdin** with event-specific data:
- PreToolUse/PostToolUse: `tool_name`, `tool_input`, and tool-specific fields
- Stop/UserPromptSubmit: conversation context

### Output
Print a JSON object to **stdout** with optional fields:

```json
{
  "decision": "block",
  "reason": "Why this was blocked (shown to Claude)",
  "message": "Message shown to the user"
}
```

- `decision` — `"block"` to prevent the action, `"allow"` to permit, omit to take no action
- `reason` — explanation for Claude (not shown to user)
- `message` / `systemMessage` — text shown to user or injected as system message

### Best Practices

- Always `import json; import sys` and read from `sys.stdin`
- Use `${CLAUDE_PLUGIN_ROOT}` in hooks.json, resolve via `os.environ['CLAUDE_PLUGIN_ROOT']` in Python
- Exit 0 even on errors — a non-zero exit blocks the operation
- Keep hooks fast (under 10 seconds)
