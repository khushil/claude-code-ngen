---
globs: ["scripts/*.ts", "scripts/*.sh"]
---

# Scripts

## TypeScript Scripts

All TypeScript scripts run via **`bun`**, not Node.js. No `npm`, `yarn`, or `npx`.

```bash
bun run scripts/my-script.ts
```

### Key Scripts

- `issue-lifecycle.ts` — source of truth for lifecycle labels, timeouts, and nudge messages. Other scripts import from here.
- `auto-close-duplicates.ts` — closes issues marked as duplicates
- `sweep.ts` — bulk issue maintenance
- `lifecycle-comment.ts` — posts lifecycle nudge comments
- `comment-on-duplicates.sh` / `backfill-duplicate-comments.ts` — duplicate issue commenting

## Shell Scripts

All shell scripts use `set -euo pipefail` at the top.

### `gh.sh` — Security-Sandboxed GitHub CLI

**Never call `gh` directly** in plugin commands or automation. Use this wrapper:

```bash
./scripts/gh.sh issue view 123
./scripts/gh.sh issue list --state open --limit 20
./scripts/gh.sh search issues "query" --limit 10
./scripts/gh.sh label list --limit 100
```

Allowed commands: `issue view`, `issue list`, `search issues`, `label list`
Allowed flags: `--comments`, `--state`, `--limit`, `--label`

The wrapper requires `GH_REPO` or `GITHUB_REPOSITORY` in `owner/repo` format. Search queries cannot contain `repo:`, `org:`, or `user:` qualifiers.

### `edit-issue-labels.sh` — Label Modifications

Use this script to add or remove labels on issues. Do not use `gh issue edit` directly.
