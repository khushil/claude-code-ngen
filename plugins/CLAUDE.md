# Plugins Directory

This directory contains 13 official Claude Code plugins. Each plugin extends Claude Code with custom commands, agents, hooks, and/or skills.

## Required Plugin Structure

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json       # Plugin metadata (name, description, version)
├── commands/             # Slash commands as .md files (optional)
├── agents/               # Sub-agent definitions as .md files (optional)
├── skills/               # Auto-invoked skills (optional)
├── hooks/                # Event hooks with hooks.json + scripts (optional)
├── .mcp.json             # MCP server configuration (optional)
└── README.md             # Plugin documentation (required)
```

## Adding a New Plugin

1. Create `plugins/<name>/` — name must be **kebab-case**
2. Create `.claude-plugin/plugin.json`:
   ```json
   {
     "name": "my-plugin",
     "description": "What it does",
     "version": "1.0.0"
   }
   ```
3. Create `README.md` documenting the plugin's purpose, commands, and usage
4. Add the plugin entry to `/.claude-plugin/marketplace.json` in the `plugins` array
5. Add a row to `plugins/README.md` table

## Plugin Templates

- **Simple command plugin:** Use `commit-commands/` as a template — just commands in markdown
- **Hook-based plugin:** Use `hookify/` or `security-guidance/` — hooks.json + Python scripts
- **Full-featured plugin:** Use `plugin-dev/` or `feature-dev/` — commands + agents + skills

## Conventions

- Plugin `name` in `plugin.json` must match the directory name
- Each plugin has its own `README.md` for documentation — do NOT add `CLAUDE.md` inside individual plugins
- Commands use YAML frontmatter (`description`, `allowed-tools`, `argument-hint`)
- Hooks use `${CLAUDE_PLUGIN_ROOT}` for portable paths in `hooks.json`
- GitHub CLI calls must use `./scripts/gh.sh`, not `gh` directly

## Current Plugins

See `README.md` in this directory for the full catalog with descriptions and contents.
