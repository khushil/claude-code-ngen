---
globs: ["plugins/**/commands/*.md", "plugins/**/agents/*.md", "plugins/**/skills/**/SKILL.md"]
---

# Plugin Markdown Authoring

## Command Files (`commands/*.md`)

Commands are slash commands defined entirely in markdown with YAML frontmatter.

### Frontmatter Fields

```yaml
---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*)
description: Short description shown in command picker
argument-hint: <optional placeholder text>
---
```

- `allowed-tools` — comma-separated tool patterns the command may use. Supports glob wildcards.
- `description` — required, one-line summary.
- `argument-hint` — optional, shown as placeholder in the input field.

### Dynamic Context

Use `!` followed by a backtick-wrapped command to inject runtime output into the prompt:

```markdown
- Current git status: !`git status`
- Current branch: !`git branch --show-current`
```

These execute when the command is invoked and their output replaces the expression.

### User Input

Use `$ARGUMENTS` to reference whatever the user typed after the slash command:

```markdown
Create a commit with message: $ARGUMENTS
```

### GitHub CLI

Always use `./scripts/gh.sh` instead of `gh` directly. This wrapper only allows:
- `issue view <number>`, `issue list`, `search issues "<query>"`, `label list`
- Flags: `--comments`, `--state`, `--limit`, `--label`

## Agent Files (`agents/*.md`)

Agent markdown files define specialized sub-agents. Same frontmatter as commands, plus:
- Agents typically have a focused role (explorer, reviewer, architect)
- Keep agent prompts specific — they run as sub-conversations
- Use `allowed-tools` to restrict what the agent can access

## Skill Files (`skills/**/SKILL.md`)

Skills are auto-invoked capabilities. Structure:

```
skills/
  skill-name/
    SKILL.md           # Main skill definition
    examples/          # Example inputs/outputs (optional)
    references/        # Reference docs (optional)
```

- `SKILL.md` uses the same frontmatter format as commands
- Skills can be triggered automatically based on context, not just slash commands
- Include examples to improve skill accuracy
