---
globs: [".github/workflows/*.yml"]
---

# GitHub Actions Workflows

## Claude Code Action

Most workflows use `anthropics/claude-code-action@v1` to run Claude as a GitHub Action:

```yaml
- name: Run Claude Code
  uses: anthropics/claude-code-action@v1
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    GH_REPO: ${{ github.repository }}
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
    prompt: "/skill-name arguments here"
    claude_args: |
      --model claude-opus-4-6
```

### Required Environment Variables

- `GH_TOKEN` or `GITHUB_TOKEN` — GitHub authentication
- `GH_REPO` or `GITHUB_REPOSITORY` — repository in `owner/repo` format
- `ANTHROPIC_API_KEY` — for Claude-powered workflows

## TypeScript Scripts in Workflows

Use `oven-sh/setup-bun@v2` for TypeScript scripts (never Node.js):

```yaml
- name: Setup Bun
  uses: oven-sh/setup-bun@v2
  with:
    bun-version: latest

- name: Run script
  run: bun run scripts/my-script.ts
```

## Workflow Patterns

### Issue Dispatch Fan-out
`issue-opened-dispatch.yml` fires on new issues and dispatches to a target repo. Other issue workflows (`claude-issue-triage.yml`, `claude-dedupe-issues.yml`) trigger independently on `issues: [opened]`.

### Concurrency
Use concurrency groups to prevent duplicate runs on the same issue:
```yaml
concurrency:
  group: issue-triage-${{ github.event.issue.number }}
  cancel-in-progress: true
```

### Timeouts
- Always set `timeout-minutes` on jobs (typically 10)
- Set a tighter `timeout-minutes` on the Claude action step (typically 5)

### Permissions
Follow least-privilege. Common pattern:
```yaml
permissions:
  contents: read
  issues: write
```
