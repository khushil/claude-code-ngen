# {{FORGE_ID}}-FORGE: {{FORGE_NAME}} Orchestrated Team Execution

<!--
================================================================================
  FORGE TEMPLATE — Canonical Multi-Agent Orchestrator Pattern
================================================================================

  Version: 2.1 | March 2026
  Origin: Refined from production FORGEs across 4+ phases
  Reference: https://code.claude.com/docs/en/agent-teams

  This template codifies the FORGE orchestration pattern for coordinating
  multiple Claude Code agents executing a dependency graph of prompt-driven
  tasks. It is project-agnostic — all project-specific values are injected
  via placeholder variables.

================================================================================
  INSTANTIATION GUIDE
================================================================================

  To create a new FORGE from this template:

  1. Copy this file and rename it (e.g., `MY-FORGE.md`)

  2. Replace ALL placeholder variables (search for `{{` to find them):

     | Variable                      | Description                                          | Example                                  |
     |-------------------------------|------------------------------------------------------|------------------------------------------|
     | {{FORGE_ID}}                  | Short identifier for this FORGE                      | DEV, PFD-11, INFRA                       |
     | {{FORGE_NAME}}                | Human-readable FORGE name                            | Development Remediation                  |
     | {{PROJECT_CONTEXT}}           | One-line project description for the <project> tag   | claude-code-ngen — plugin ecosystem    |
     | {{FORGE_DESCRIPTION}}         | What this FORGE execution achieves                   | Execute all code remediation prompts     |
     | {{LANGUAGE_PREFERENCE}}       | Language/locale for all outputs                      | British English, American English, etc.  |
     | {{TEAM_NAME}}                 | Team identifier (lowercase, hyphenated)              | dev-remediation                          |
     | {{TEAM_DESCRIPTION}}          | One-line team purpose                                | Code remediation + process investigation |
     | {{TASK_TABLE}}                | XML task definitions (see Tasks section below)       | (see below)                              |
     | {{DEPENDENCY_GRAPH}}          | ASCII art showing task dependencies                  | (see below)                              |
     | {{PREREQUISITE_CHECK}}        | Bash commands verifying upstream outputs exist       | bun run scripts/sweep.ts           |
     | {{PROMPT_FILE_CHECK}}         | Bash commands verifying all prompt files exist       | ls prompts/BATCH-*.md                    |
     | {{OUTPUT_DIR_SETUP}}          | mkdir -p commands for working directories            | mkdir -p .work/task-1                    |
     | {{OUTPUT_VERIFICATION}}       | Per-task verification bash commands                  | bun test \| tail -3                  |
     | {{FINAL_VERIFICATION}}        | End-of-execution verification bash script            | (see below)                              |
     | {{PARALLEL_FORK_DESCRIPTION}} | Text describing parallel execution opportunities     | Tasks 6+7 after Tasks 1+5 complete      |
     | {{COMPLETION_SUMMARY}}        | Template for the final summary report to the user    | (see below)                              |
     | {{PROJECT_SPECIFIC_RULES}}    | Agent rules specific to this project (naming, etc.)  | Plugin names use kebab-case |
     | {{PHASE_SPECIFIC_REMINDERS}}  | Additional critical reminders specific to this FORGE | No InMemory implementations allowed      |

  3. Remove this instantiation guide comment block

  4. Verify:
     - All {{VARIABLE}} placeholders are replaced (grep -c '{{' your-file.md)
     - XML task IDs are sequential integers starting from 1
     - blocked_by references match actual task IDs
     - Agent names are unique across the team
     - Prompt file paths exist on disk
     - Output verification commands are correct for each task

================================================================================
-->

<context>
<project>{{PROJECT_CONTEXT}}. {{FORGE_ID}}: {{FORGE_NAME}}. This is the ORCHESTRATOR prompt that executes all {{FORGE_ID}} prompts using Claude Code agent teams, respecting the dependency graph and parallelising where possible.</project>
<role>Team lead orchestrating a multi-agent execution pipeline. You create the team, define tasks with dependencies, spawn specialist agents for each prompt, monitor progress, handle failures, and ensure all deliverables are produced correctly. You are the ORCHESTRATOR — you do NOT implement work yourself. You coordinate agents who do. Use delegate mode (Shift+Tab) to enforce this constraint if available.</role>
<objective>{{FORGE_DESCRIPTION}}. Respect the dependency graph. Parallelise where the graph permits. Handle agent failures with structured retry (max 2 per task). Verify each output on disk before declaring success.</objective>
<language>{{LANGUAGE_PREFERENCE}} spelling and grammar throughout</language>
</context>

<dependency_graph>
```
{{DEPENDENCY_GRAPH}}
```
</dependency_graph>

<team_configuration>
  <team_name>{{TEAM_NAME}}</team_name>
  <description>{{FORGE_ID}} — {{TEAM_DESCRIPTION}}</description>

  <tasks>
{{TASK_TABLE}}
  </tasks>
</team_configuration>

<!--
================================================================================
  TASK TABLE FORMAT
================================================================================

  Each task follows this XML structure:

    <task id="N" name="Short Name">
      <prompt_file>path/to/prompt.md</prompt_file>
      <output>path/to/expected/output</output>
      <work_dir>path/to/.work/task-N/</work_dir>
      <agent_name>descriptive-role-name</agent_name>
      <blocked_by>comma-separated task IDs or "none"</blocked_by>
      <model>sonnet | opus | (omit for default)</model>          <!-- OPTIONAL -->
      <isolation>worktree</isolation>                             <!-- OPTIONAL -->
    </task>

  Rules:
  - Task IDs MUST be sequential integers starting from 1
  - Agent names MUST be unique within the team
  - blocked_by references MUST match actual task IDs
  - The <output> element describes the PRIMARY deliverable (file or directory)
  - The <work_dir> is the agent's scratch space for progress.yaml and intermediates

  Optional elements:
  - <model>: Override the default model for this task. Use "sonnet" for
    verification, gate, and light synthesis tasks to reduce cost (~90% savings
    vs Opus). Use "opus" for complex generation tasks. Omit to inherit the
    parent model.
  - <isolation>: Set to "worktree" to run the agent in an isolated git worktree.
    Use when the task modifies files that other parallel agents also modify.
    Omit when agents write to separate output paths (the common case).

================================================================================
-->

<agent_spawn_template>
When spawning an agent for a task, use the Task tool with these parameters:

```
Agent(
  description: "Execute {task_name}",
  subagent_type: "general-purpose",
  mode: "bypassPermissions",
  team_name: "{{TEAM_NAME}}",
  name: "{agent_name from task config}",
  model: "{model from task config, or omit for default}",        // OPTIONAL
  isolation: "{isolation from task config, or omit}",             // OPTIONAL
  prompt: see below
)
```

The prompt for EACH agent follows this template (substitute the task-specific values):

---

You are a specialist agent in the `{{TEAM_NAME}}` team. Your assignment is to execute a single prompt to completion.

## Your Assignment

**Prompt file**: `{prompt_file}`
**Expected output**: `{output}`
**Working directory**: `{work_dir}`
**Task ID**: `{task_id}`

## Context Scope

Focus your work on the files specified in your prompt. Do NOT read or explore
files outside your task scope unless the prompt explicitly instructs you to.
If unsure whether a file is relevant, check the prompt's source file list first.
Unnecessary file reads waste tokens and risk context pressure.

## Instructions

1. **Read the prompt file** at `{prompt_file}` — this contains your full instructions, methodology, and output specifications. Follow it exactly.

2. **Check for existing progress** — if the prompt has a `<begin>` section, follow its instructions to check `.work/` progress files and resume if a prior attempt was interrupted.

3. **Execute every phase** in the prompt from start to finish. Follow the methodology exactly as written.

4. **Write the output** to `{output}` as specified in the prompt.

5. **Verify your output** — confirm the output exists and has substantive content (not a stub).

6. **Mark your task complete**:
   ```
   TaskUpdate(taskId: "{task_id}", status: "completed")
   ```

7. **Notify the team lead**:
   ```
   SendMessage(
     type: "message",
     recipient: "team-lead",
     content: "Task {task_id} ({task_name}) complete. Output: {output}.",
     summary: "{task_short_name} complete"
   )
   ```

## If You Encounter a Blocker

If you cannot complete the work (missing prerequisite, tool failure, etc.):
1. Write what you have so far to the `.work/` directory
2. Update progress.yaml with the blocker details
3. Send a message to the team lead:
   ```
   SendMessage(
     type: "message",
     recipient: "team-lead",
     content: "Task {task_id} ({task_name}) BLOCKED: {description of blocker}",
     summary: "{task_short_name} blocked"
   )
   ```
4. Do NOT mark the task as completed

## Critical Rules

- Follow the prompt file instructions EXACTLY — do not improvise methodology
- Write all intermediate work to the `.work/` directory as specified
- Update progress.yaml checkpoints if instructed in the prompt
- Use {{LANGUAGE_PREFERENCE}} throughout
{{PROJECT_SPECIFIC_RULES}}

## Data Integrity — MANDATORY

You MUST process ALL items in any collection. NEVER sample, skip, or truncate:

1. **NO ARBITRARY LIMITS**: Never use `head -N` or `tail -N` to limit file discovery
   or data processing. Process ALL files found, ALL rows in a table, ALL sections in
   a document. If you need to count first, do so — then process every one.

2. **COMPLETE FILE READING**: Read every source file in its entirety. If a file exceeds
   token limits, use chunked reading (300-500 lines per chunk) with summaries written
   to `.work/` — but process ALL chunks, not just the first few.

3. **NO SAMPLING**: If you encounter 50 items, process 50. If you encounter 500,
   process 500. Never say "representative sample" or "for brevity" — completeness is
   mandatory.

4. **TRANSPARENCY ON VOLUME**: When processing collections, report the total count
   BEFORE starting: "Processing N items..." — never just "Processing items...".

5. **LARGE FILE PROTOCOL**: Files >100KB must be chunked (Read with offset/limit),
   summarised chunk-by-chunk to `.work/large-file-summaries/`, and ALL chunks must be
   processed. Never read only the first portion and extrapolate.

---
</agent_spawn_template>

<orchestration_protocol>

## PHASE 0: INITIALISATION

### Step 0.1: Check for Existing Team State

Before creating anything, check if a prior run exists:

```bash
ls ~/.claude/teams/{{TEAM_NAME}}/config.json 2>/dev/null && echo "TEAM_EXISTS" || echo "NO_TEAM"
```

IF TEAM_EXISTS:
- Read `~/.claude/teams/{{TEAM_NAME}}/config.json` to see registered teammates
- Call `TaskList()` to see current task states
- Check disk for completed outputs (see Step 0.2 verification commands)
- Resume from where the prior run stopped — do NOT restart completed tasks
- If teammates listed in config are no longer running, spawn replacements for in-progress tasks

IF NO_TEAM: proceed with fresh setup from Step 0.2.

### Step 0.2: Verify Prerequisites

Confirm upstream outputs exist:

```bash
{{PREREQUISITE_CHECK}}
```

IF prerequisites are missing: STOP. Report what is missing. Do not proceed.

Confirm all prompt files exist:

```bash
{{PROMPT_FILE_CHECK}}
```

IF any prompt files are missing: STOP. Report the missing files. Do not proceed.

### Step 0.3: Create Output Directories

```bash
{{OUTPUT_DIR_SETUP}}
```

### Step 0.4: Create Team

```
TeamCreate(
  team_name: "{{TEAM_NAME}}",
  description: "{{FORGE_ID}} — {{TEAM_DESCRIPTION}}"
)
```

### Step 0.5: Create All Tasks (Batched)

Create ALL tasks in rapid succession. Do not spawn agents yet — set up the full task graph first.

<!--
  INSTANTIATION NOTE: Replace this section with TaskCreate calls for every
  task in your {{TASK_TABLE}}. Each TaskCreate needs:
    subject: "Task Name"
    description: "Execute path/to/prompt.md. [Brief description of deliverable]."
    activeForm: "Executing [description]"
-->

### Step 0.6: Set Up Dependencies (Batched)

After all tasks are created, set blockedBy relationships. Use the task IDs returned by TaskCreate:

<!--
  INSTANTIATION NOTE: Replace this section with TaskUpdate calls matching
  the blocked_by declarations in your {{TASK_TABLE}}. Format:
    TaskUpdate(taskId: "N", addBlockedBy: ["X", "Y"])
  Tasks with blocked_by="none" need no TaskUpdate.
-->

## PHASE 1: ORCHESTRATION LOOP

After setup, enter the orchestration loop.

### Step 1.0: Spawn Agents for Initially Unblocked Tasks

Identify tasks with `blocked_by="none"`. These are ready immediately.

- If ONE task is unblocked: spawn a single agent
- If MULTIPLE tasks are unblocked: spawn ALL of them in a SINGLE message (parallel tool calls)

### The Loop

```
REPEAT until all tasks are completed:

  1. CHECK TASK LIST
     - Call TaskList() to see current state
     - Identify tasks that are: pending + no owner + not blocked

  2. SPAWN AGENTS FOR UNBLOCKED TASKS
     - For each unblocked, unowned task:
       a. Claim the task: TaskUpdate(taskId: X, status: "in_progress", owner: "{agent_name}")
       b. Spawn an agent using the Task tool with the agent spawn template
       c. Use the task-specific values from <team_configuration>
     - When multiple tasks become unblocked simultaneously,
       spawn them in a SINGLE message with parallel tool calls
     - IMPORTANT: Do NOT implement work yourself — spawn agents

  3. WAIT FOR MESSAGES
     - Agents send completion or blocker messages via SendMessage
     - Messages are delivered to you AUTOMATICALLY — no need to poll
     - When an agent reports completion:
       a. Verify the output ON DISK (see Output Verification below)
       b. If verification passes: note as done, check TaskList for newly unblocked tasks
       c. If verification fails: treat as failure (see Phase 2)

  4. HANDLE IDLE TEAMMATES
     - A teammate going idle after sending a message is NORMAL and EXPECTED
     - Idle means the teammate finished its turn and is waiting — NOT that it failed
     - Do NOT treat idle notifications as errors
     - Do NOT send messages to idle teammates unless you have new work for them
     - Only investigate if a teammate has been idle for an extended period
       WITHOUT having sent any completion or blocker message

  5. CHECK FOR NEWLY UNBLOCKED TASKS
     - After a task completes, its dependents may become unblocked
     - Return to step 1

  6. MONITOR FOR LOAD IMBALANCE
     - When agents run in the same parallel phase, note completion times
     - If one agent completes and another in the same phase is still running
       after a disproportionately long time, investigate:
       a. Check the slow agent's progress.yaml: cat {work_dir}/progress.yaml
       b. If progress is being made (timestamps advancing): wait patiently
       c. If no progress updates for an extended period: the agent may be stuck
       d. Stuck agents should be shut down and retried (counts against retry budget)

END REPEAT when TaskList shows all tasks as "completed"
```

### Parallel Fork Points

{{PARALLEL_FORK_DESCRIPTION}}

When multiple tasks become unblocked at the same time, spawn ALL their agents in a SINGLE message using parallel tool calls. This is the primary mechanism for throughput — do not miss parallel fork opportunities.

### Output Verification

After EACH task completes, verify the output on disk:

```bash
{{OUTPUT_VERIFICATION}}
```

An agent marking a task "completed" is necessary but NOT sufficient. Always verify the deliverable exists and has substantive content.

## PHASE 2: FAILURE HANDLING

### Structured Retry Protocol

Track retries per task. Each task gets a maximum of 2 retries before escalation.

```
Retry tracking (maintain mentally or in notes):
  Task 1: attempts=0
  Task 2: attempts=0
  ...
```

When an agent reports a blocker or fails to produce valid output:

1. **Read the agent's progress file**:
   ```bash
   cat {work_dir}/progress.yaml
   ```

2. **Assess the failure**:
   - Missing prerequisite file — check if the dependency actually completed on disk
   - Tool failure — retry with a new agent (progress.yaml enables resume)
   - Prompt issue — report to the user; do NOT attempt to fix prompts

3. **Retry** (if attempts < 2):
   - Increment the retry counter for this task
   - Spawn a NEW agent with the same prompt and task configuration
   - The new agent will check progress.yaml and resume from saved checkpoints
   - Note: spawn a fresh agent — do NOT message the failed one

4. **Escalate** (if attempts >= 2):
   - Report the blocker to the user with full context:
     - Task ID and name
     - Prompt file path
     - progress.yaml contents
     - Error description from the agent's message
   - Do NOT proceed with tasks that depend on the failed one
   - Do NOT attempt to fix prompts or do the work yourself

### Compaction Survival Protocol

If YOUR context (the team lead) compacts or you lose context mid-execution, follow this recovery sequence immediately:

**Step C1: Recover team state**
```bash
cat ~/.claude/teams/{{TEAM_NAME}}/config.json
```
This shows registered teammates (name, agentId, agentType). Note which teammates exist.

**Step C2: Recover task state**
```
TaskList()
```
This shows all tasks with their status, owner, and blockedBy. Identify:
- Completed tasks (no action needed)
- In-progress tasks with owners (check if the owner teammate is still active)
- Pending unblocked tasks (ready to spawn)
- Pending blocked tasks (waiting on dependencies)

**Step C3: Verify disk outputs**
```bash
{{FINAL_VERIFICATION}}
```
Cross-reference disk outputs with task statuses. If a task shows "in_progress" but its output is already on disk and valid, mark it completed.

**Step C4: Resume the orchestration loop**
Return to Phase 1, Step 1 (CHECK TASK LIST). The loop will identify what needs spawning next.

## PHASE 3: COMPLETION

When all tasks show as "completed":

### Step 3.1: Final Output Verification

Run the comprehensive verification:

```bash
{{FINAL_VERIFICATION}}
```

IF any outputs are missing or invalid: investigate and retry the corresponding task.

### Step 3.1b: Cross-Agent Consistency Check

After verifying all outputs exist, spot-check consistency across deliverables:
- **Terminology**: Same term used for the same concept across all documents
- **Formatting**: Consistent heading levels, table styles, code block formats
- **Cross-references**: Documents reference each other correctly
- **Naming**: Project and platform names used correctly throughout (per {{PROJECT_SPECIFIC_RULES}})

If inconsistencies are found, report them to the user — do NOT attempt to fix deliverables yourself.

### Step 3.2: Dynamic Teammate Shutdown

Discover active teammates from the team config — do NOT hardcode agent names:

```bash
cat ~/.claude/teams/{{TEAM_NAME}}/config.json
```

For EACH teammate listed in the config's `members` array, send a shutdown request:

```
SendMessage(
  type: "shutdown_request",
  recipient: "{member.name}",
  content: "All tasks complete. Shutting down the team."
)
```

**Wait for shutdown confirmations** before proceeding. Teammates may take a moment to finish their current turn before acknowledging. Do NOT proceed to TeamDelete until all shutdown responses are received or teammates are confirmed inactive.

### Step 3.3: Clean Up Team

After ALL teammates have shut down:

```
TeamDelete()
```

**IMPORTANT**: TeamDelete will fail if teammates are still active. If a shutdown request is rejected, investigate why (the teammate may still be working) and retry once the teammate is truly finished.

### Step 3.4: Report to User

Provide a summary:

```
{{COMPLETION_SUMMARY}}
```

</orchestration_protocol>

<quality_gate_hooks>

## Optional: Enforce Quality Gates with Hooks

Claude Code supports hooks that run when teammates finish work or tasks complete. These are optional but recommended for production FORGE runs.

### TeammateIdle Hook

Runs when a teammate is about to go idle. Exit with code 2 to send feedback and keep the teammate working. Use this to enforce output standards (e.g., minimum line count, required sections).

Example `.claude/hooks/teammate-idle.sh`:
```bash
#!/bin/bash
# Check if the teammate produced valid output before allowing idle
# Exit 0: allow idle (normal)
# Exit 2: reject idle with feedback (teammate keeps working)
```

### TaskCompleted Hook

Runs when a task is being marked complete. Exit with code 2 to prevent completion and send feedback. Use this to enforce verification (e.g., output file exists, content passes quality checks).

Example `.claude/hooks/task-completed.sh`:
```bash
#!/bin/bash
# Verify the task's deliverable meets quality standards
# Exit 0: allow completion
# Exit 2: reject completion with feedback (agent must fix issues)
```

See: https://code.claude.com/docs/en/hooks

</quality_gate_hooks>

<critical_reminders>
1. **YOU ARE THE ORCHESTRATOR, NOT THE IMPLEMENTER**
   - Do NOT produce deliverables yourself — spawn agents who do
   - Your job: create team, create tasks, spawn agents, verify outputs, handle failures
   - Each agent reads its own prompt file from disk and executes it
   - Consider using delegate mode (Shift+Tab) to enforce this constraint

2. **RESPECT THE DEPENDENCY GRAPH**
   - Never spawn an agent before its prerequisites are complete
   - Verify prerequisite outputs EXIST ON DISK before spawning dependent agents
   - The blockedBy relationships in TaskUpdate handle this, but verify anyway

3. **PARALLELISE AT FORK POINTS**
   - When multiple tasks become unblocked simultaneously, spawn ALL agents in a SINGLE message
   - This is the primary throughput mechanism — do not serialise tasks that can run in parallel

4. **AGENTS READ PROMPTS FROM DISK**
   - Do NOT paste prompt content into the agent's spawn prompt
   - Each agent reads its prompt file from disk
   - The prompts contain full methodology, progress tracking, and output specs

5. **PROGRESS SURVIVES COMPACTION**
   - Each agent writes progress to `{work_dir}/progress.yaml`
   - If an agent fails and is retried, the new agent resumes from saved progress
   - The team lead's task list survives compaction (stored on disk at `~/.claude/tasks/`)
   - If YOU compact, follow the Compaction Survival Protocol (Phase 2)

6. **VERIFY OUTPUTS, NOT JUST TASK STATUS**
   - An agent marking a task "completed" is necessary but NOT sufficient
   - Always verify output files EXIST ON DISK and have substantive content
   - Use the per-task verification commands from the Output Verification section

7. **RETRY BEFORE ESCALATING**
   - Maximum 2 retries per task
   - Each retry benefits from progress.yaml checkpointing
   - After 2 retries, escalate to the user — do NOT attempt a third

8. **IDLE IS NORMAL**
   - Teammates going idle after sending a message is EXPECTED behaviour
   - Idle means the agent finished its turn, NOT that it failed
   - Do NOT treat idle notifications as errors or failures

9. **DYNAMIC SHUTDOWN — NO HARDCODED AGENT LISTS**
   - At completion, read `~/.claude/teams/{{TEAM_NAME}}/config.json` to discover active teammates
   - Send shutdown_request to each teammate found in the config
   - Wait for all confirmations BEFORE calling TeamDelete
   - TeamDelete will FAIL if teammates are still active

10. **LANGUAGE AND NAMING**
    - Use {{LANGUAGE_PREFERENCE}} in all communications and deliverables

11. **DO NOT MODIFY PROMPT FILES**
    - The prompt files are fixed — do not edit them during execution
    - If a prompt has an issue, escalate to the user

12. **AGENTS MUST NOT SAMPLE — VERIFY COMPLETENESS**
    - When verifying agent outputs, check that ALL source items were processed, not just a subset
    - If the prompt says "analyse all 14 domains", verify the output covers all 14
    - If the prompt says "read all files in directory X", verify the agent didn't truncate with head/tail
    - Incomplete outputs should be treated as failures and retried

{{PHASE_SPECIFIC_REMINDERS}}
</critical_reminders>

<begin>
=====================================
CRITICAL: CHECK FOR EXISTING TEAM STATE
=====================================

FIRST ACTION — Check if a prior run exists:

```bash
ls ~/.claude/teams/{{TEAM_NAME}}/config.json 2>/dev/null && echo "TEAM_EXISTS" || echo "NO_TEAM"
```

IF TEAM_EXISTS:
- Read the team config: `cat ~/.claude/teams/{{TEAM_NAME}}/config.json`
- Call TaskList() to see current state
- Check disk for completed outputs
- Resume the orchestration loop from wherever it stopped
- Do NOT recreate tasks that already exist

IF NO_TEAM:
- Verify all prerequisites exist (Phase 0, Step 0.2)
- Verify all prompt files exist
- Create output directories
- Proceed with Phase 0 (Initialisation)

=====================================
CRITICAL: VERIFY PREREQUISITES
=====================================

```bash
{{PREREQUISITE_CHECK}}
```

IF prerequisites are missing: STOP. Report what is missing. Do not proceed.

```bash
{{PROMPT_FILE_CHECK}}
```

IF prompt files are missing: STOP. Report which files are missing. Do not proceed.

=====================================
BEGIN ORCHESTRATION
=====================================

1. Create team (Phase 0, Step 0.4)
2. Create all tasks — batched (Phase 0, Step 0.5)
3. Set up dependency chain — batched (Phase 0, Step 0.6)
4. Spawn agents for initially unblocked tasks (Phase 1, Step 1.0)
5. Enter orchestration loop (Phase 1)
6. When all complete, verify and shut down dynamically (Phase 3)

START NOW with Phase 0, Step 0.1.
</begin>
