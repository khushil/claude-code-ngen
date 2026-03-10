# Claude Code Plugins Repository

This is a **plugin ecosystem repository**, not a traditional software project. There is no build system, no package.json, and no compiled output. The repo contains official Claude Code plugins, GitHub automation workflows, and supporting scripts.

## Directory Map

```
plugins/           13 official Claude Code plugins (commands, agents, hooks, skills)
.claude-plugin/    marketplace.json — plugin registry for this repo
.github/workflows/ GitHub Actions for issue triage, lifecycle, dedup, and sweeps
scripts/           TypeScript (bun) and shell scripts for GitHub automation
examples/          Example CLAUDE.md files for reference
prompts/           Prompt templates
rubrics/           Evaluation rubrics
```

## Key Files

- `.claude-plugin/marketplace.json` — master registry of all plugins; update when adding/removing plugins
- `plugins/README.md` — plugin catalog with descriptions and contents
- `scripts/gh.sh` — security-sandboxed `gh` CLI wrapper (only allows: `issue view`, `issue list`, `search issues`, `label list`)
- `scripts/issue-lifecycle.ts` — source of truth for lifecycle labels, timeouts, and messages

## Conventions

- **Plugins live in `plugins/` only.** Each plugin has `.claude-plugin/plugin.json` and `README.md`.
- **Plugin names are kebab-case** and must match their directory name.
- **Markdown drives behavior.** Commands, agents, and skills are defined in `.md` files with YAML frontmatter.
- **TypeScript scripts run via `bun`**, not Node.js. No `npm` or `yarn`.
- **GitHub CLI access uses `./scripts/gh.sh`** — never call `gh` directly in commands or workflows that need sandboxing.
- **Shell scripts use `set -euo pipefail`.**

## What NOT to Do

- Do not add a `package.json`, `tsconfig.json`, or build tooling to the root.
- Do not create plugins outside of `plugins/`.
- Do not add `CLAUDE.md` files inside individual plugins — they already have `README.md`.
- Do not call `gh` directly in plugin commands — use `./scripts/gh.sh`.
- Do not modify `marketplace.json` schema fields — only add/remove plugin entries.

## Working with Plugins

When adding a new plugin:
1. Create `plugins/<name>/` with `.claude-plugin/plugin.json` and `README.md`
2. Add an entry to `.claude-plugin/marketplace.json`
3. Update `plugins/README.md` table

When modifying a plugin:
1. Read its `README.md` first to understand purpose and structure
2. Follow existing patterns in similar plugins (e.g., `commit-commands` for simple, `hookify` for complex)

## Working with Workflows

- Workflows use `anthropics/claude-code-action@v1` for Claude-powered automation
- TypeScript scripts need `oven-sh/setup-bun@v2` in the workflow
- Required env vars: `GH_TOKEN` or `GITHUB_TOKEN`, `GH_REPO` or `GITHUB_REPOSITORY`
- `issue-opened-dispatch.yml` fans out to other workflows on new issues
