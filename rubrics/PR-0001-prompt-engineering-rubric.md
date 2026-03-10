# Prompt Engineering Rubric for Claude Code Prompts

## Overview

This rubric provides reusable patterns and templates for building robust Claude Code prompts that:
- Survive context compaction across long-running tasks
- Handle large files that exceed token limits
- Maintain state and enable reliable resumption
- Follow consistent structural patterns

Use this document as a reference when creating new prompts or enhancing existing ones.

---

## Table of Contents

1. [When to Use These Patterns](#when-to-use-these-patterns)
2. [Core Principles](#core-principles)
3. [Prompt Structure Template](#prompt-structure-template)
4. [Context Compaction Survival Pattern](#context-compaction-survival-pattern)
5. [Large File Handling Pattern](#large-file-handling-pattern)
6. [Avoiding Arbitrary Limits Pattern](#avoiding-arbitrary-limits-pattern)
7. [Agent Data Integrity Directive](#agent-data-integrity-directive)
8. [Progress Tracking Patterns](#progress-tracking-patterns)
9. [Checkpoint Strategies](#checkpoint-strategies)
10. [Begin Section Template](#begin-section-template)
11. [Critical Reminders Template](#critical-reminders-template)
12. [Customisation Guide](#customisation-guide)

---

## When to Use These Patterns

### Always Include Context Compaction Survival When:
- Task involves multiple phases or steps
- Work will take more than 10-15 minutes of Claude time
- Task involves reading/processing multiple source files
- Output involves creating multiple files or documents
- Task has natural checkpoint boundaries (phases, levels, personas, etc.)

### Always Include Large File Handling When:
- Source files may exceed 50KB
- Working with large specification files
- Processing documentation sets
- Reading architecture documents
- Any task where you say "read all the files in..."

### Skip These Patterns When:
- Simple single-file transformations
- Quick Q&A or analysis tasks
- Tasks completable in a single response
- No file I/O required

---

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Disk Over Memory** | Write everything to `.work/` directory; context will be lost but disk persists |
| **Progress After Every Unit** | Update `progress.yaml` after every significant work unit to enable resumption |
| **Summarise Then Discard** | For large files: read chunk → extract key info → write summary → forget chunk |
| **Reference Not Re-read** | Once summarised, reference the summary file; only re-read original for quotes |
| **Clear Next Action** | Always document exactly what to do next for cold resumption |
| **Check Before Starting** | First action is always checking for existing progress; never restart completed work |
| **Complete Then Move** | Finish one unit of work completely before starting another |
| **No Arbitrary Limits** | NEVER use `head -N` or `tail -N` to limit file discovery; process ALL files or show count + warn |
| **Separate Work from Deliverables** | `.work/` is for internal tracking; `docs/` is for final artifacts humans review |

---

## Output Directory Separation

**Critical:** The `.work/` directory is for INTERNAL tracking only. Final deliverables must go to visible directories.

### Directory Purposes

| Directory | Purpose | Visibility | Contents |
|-----------|---------|------------|----------|
| **`.work/`** | Internal tracking, compaction survival | Hidden (dot directory) | `progress.yaml`, inventories, intermediate data |
| **`docs/`** | Final deliverables | Visible, reviewable | Reports, analysis, documentation |

---

## Prompt Structure Template

A well-structured Claude Code prompt follows this pattern:

```xml
# [PROMPT TITLE]

<context>
<project>[Project name and description]</project>
<role>[What role Claude is playing]</role>
<objective>[What this prompt achieves]</objective>
</context>

<foundational_principles>
[Key principles that guide all work - numbered list]
</foundational_principles>

<context_compaction_survival>
[See pattern below]
</context_compaction_survival>

<large_file_handling>
[See pattern below]
</large_file_handling>

<data_integrity>
[See Agent Data Integrity Directive - include for prompts processing multiple files or collections]
</data_integrity>

<methodology>
[Phases and steps - the actual work to be done]
</methodology>

<output_specifications>
[What files/artifacts to produce and their format]
</output_specifications>

<critical_reminders>
[Key points that must not be forgotten - numbered list]
</critical_reminders>

<begin>
[Instructions for starting/resuming work]
</begin>
```

---

## Context Compaction Survival Pattern

### Template (Copy and Customise)

```xml
<context_compaction_survival>
  <critical_warning>
  THIS WORK WILL SPAN MULTIPLE CONTEXT COMPACTIONS.
  [Description of why this task is extensive].
  You WILL lose context multiple times during this work.
  You MUST implement strategies to survive compaction and resume work correctly.
  </critical_warning>
  
  <work_tracking_directory>
    <path>[OUTPUT_DIR]/.work/</path>
    <purpose>Persistent work state that survives context compaction</purpose>
    <critical>Create this directory FIRST before any other work</critical>
    
    <required_files>
      <file name="progress.yaml">
        <purpose>Track current [phase/level/step] and exactly what to do next</purpose>
        <updated>After EVERY [significant work unit], EVERY [milestone]</updated>
        <critical>MUST be updated frequently - this is your resumption lifeline</critical>
      </file>
      
      <file name="source-discovery.yaml">
        <purpose>Complete catalogue of all source files with sizes</purpose>
        <created>Phase 0 during discovery</created>
        <used_by>All subsequent phases for source lookup</used_by>
      </file>
      
      <!-- Add task-specific tracking files here -->
      <file name="[task-specific].yaml">
        <purpose>[What this tracks]</purpose>
        <created>[When created]</created>
        <format>[Format description]</format>
      </file>
      
      <directory name="source-summaries/">
        <purpose>Summary of each source file</purpose>
        <created>During discovery phase</created>
        <format>One .yaml per source document with key content extracted</format>
      </directory>
      
      <directory name="large-file-summaries/">
        <purpose>Chunked summaries of files too large to read at once</purpose>
        <created>When large files encountered during discovery</created>
        <format>One .yaml per large file with chunk-by-chunk summaries</format>
      </directory>
    </required_files>
  </work_tracking_directory>
  
  <progress_tracking_schema>
```yaml
# progress.yaml - UPDATE AFTER EVERY SIGNIFICANT WORK UNIT
progress:
  last_updated: "[ISO DateTime]"
  current_phase: "[Phase ID]"
  current_step: "[Step ID]"
  status: "In Progress | Blocked | Complete"
  
  # Task-specific phase tracking
  phases:
    phase_0_discovery:
      status: "Not Started | In Progress | Complete"
      # Phase-specific metrics
      
    phase_1_[name]:
      status: "Not Started | In Progress | Complete"
      # Phase-specific metrics
      
  # What's done
  work_completed:
    - item: "[Completed item]"
      completed_at: "[DateTime]"
      
  # What's in progress
  work_in_progress:
    - item: "[Current item]"
      status: "[What's done, what remains]"
      
  # What's remaining
  work_remaining:
    - "[List of pending items]"
    
  # Any blockers
  blockers:
    - "[Any issues preventing progress]"
    
  # CRITICAL: Exactly what to do next
  next_action: "[EXACTLY what to do next when resuming - be specific]"
```
  </progress_tracking_schema>
  
  <resumption_protocol>
  WHEN CONTEXT IS COMPACTED OR SESSION RESUMES:
  
  1. IMMEDIATELY check for existing progress:
     ```bash
     cat [OUTPUT_DIR]/.work/progress.yaml 2>/dev/null || echo "NO_PROGRESS_FILE"
     ```
     
  2. IF progress file exists:
     - Read current_phase, current_step
     - Read next_action (this tells you EXACTLY what to do)
     - Check which [phases/levels/items] are complete
     - Load relevant .work/ files (source-discovery.yaml, summaries as needed)
     - Resume from next_action - do NOT restart from beginning
     - Do NOT re-read source files - use .work/ summaries
     
  3. IF no progress file (fresh start):
     - Initialize .work/ directory structure
     - Begin with Phase 0 (Discovery/Prerequisites)
     
  4. After each significant unit of work:
     - Update progress.yaml immediately
     - Write next_action clearly for potential resumption
     
  5. CHECKPOINT REQUIREMENTS:
     - After EVERY [major deliverable created]
     - After EVERY [phase/level] completed
     - After EVERY [significant milestone]
     - Before ANY [complex operation]
  </resumption_protocol>
  
  <compaction_safe_practices>
    <practice>Write progress.yaml after EVERY [significant work unit]</practice>
    <practice>Write summaries to disk, don't keep in context memory</practice>
    <practice>Reference .work/ files instead of re-reading large sources</practice>
    <practice>Complete one [unit] fully before starting another</practice>
    <practice>Document "next_action" with enough detail to resume cold</practice>
    <practice>Use .work/*.yaml as source of truth, not context memory</practice>
    <practice>Never rely on context to remember what [phases/levels] are done</practice>
  </compaction_safe_practices>
</context_compaction_survival>
```

### Customisation Points

Replace these placeholders when using the template:

| Placeholder | Replace With | Examples |
|-------------|--------------|----------|
| `[OUTPUT_DIR]` | Actual output directory path | `/home/ubuntu/src/project/docs/output` |
| `[significant work unit]` | What constitutes a checkpoint | "spec file", "ADR", "page", "component" |
| `[phase/level/step]` | Your task's hierarchy | "phase", "level", "persona", "stage" |
| `[major deliverable]` | Key outputs | "spec file", "document", "verification" |
| `[task-specific].yaml` | Additional tracking files | "level-status.yaml", "adr-index.yaml" |

---

## Large File Handling Pattern

### Template (Copy and Customise)

```xml
<large_file_handling>
  <critical_warning>
  Some [file type] may exceed token limits and cannot be read in one operation.
  This is especially likely for:
  - [List of file types that tend to be large]
  - [Another type]
  - [Another type]
  You MUST detect and handle large files appropriately.
  </critical_warning>
  
  <detection_strategy>
  During [discovery phase]:
  
  1. Get file sizes for ALL source files:
     ```bash
     find [SOURCE_DIR] -type f \( -name "*.md" -o -name "*.ts" -o -name "*.ex" -o -name "*.yaml" \) -exec ls -la {} \;
     ```
     
  2. Categorise by size:
     - Small: < 50KB (safe to read entirely)
     - Medium: 50-100KB (usually OK, monitor for truncation)
     - Large: > 100KB (requires chunked reading)
     
  3. For large files, calculate estimated chunks:
     - Assume ~300-500 lines per chunk as safe default
     - Use: wc -l [file] to get line count
     - Denser content (specs, code) → smaller chunks (~300 lines)
     - Prose content (docs) → larger chunks (~500 lines)
     
  4. Record in source-discovery.yaml:
```yaml
source_files:
  - file: "[filename]"
    path: "[full path]"
    size_bytes: [size]
    size_category: "small | medium | large"
    line_count: [lines]
    requires_chunked_reading: true | false
    estimated_chunks: [N]  # if large
    content_type: "[description of content]"
    
  large_files_summary:
    count: [N]
    total_size_mb: [size]
    files:
      - "[filename1]"
      - "[filename2]"
```
  </detection_strategy>
  
  <chunked_reading_strategy>
  For files marked as "large":
  
  1. Read file in sections using line ranges:
     ```
     view /path/to/file.md [1, 300]
     view /path/to/file.md [301, 600]
     view /path/to/file.md [601, 900]
     # etc.
     ```
     
  2. After reading EACH chunk, immediately extract:
     - [Key item type 1 relevant to your task]
     - [Key item type 2]
     - [Key item type 3]
     - Cross-references to other files
     
  3. Write chunk summary to large-file-summaries/:
```yaml
# large-file-summaries/[FILE_ID].yaml
file: "[filename]"
path: "[full path]"
total_lines: [N]
total_chunks: [N]
chunks_processed: [N]
fully_summarised: true | false

chunk_summaries:
  - chunk: 1
    lines: "1-300"
    content_type: "[What this chunk contains]"
    key_items:
      - "[Item 1]"
      - "[Item 2]"
    # Task-specific extracted data
    [custom_field]:
      - [extracted data]
      
  - chunk: 2
    lines: "301-600"
    content_type: "[What this chunk contains]"
    key_items:
      - "[Item 3]"
    # ... continue pattern

aggregate_summary:
  total_[items]: [N]
  by_category:
    [category1]: [N]
    [category2]: [N]
  key_topics:
    - "[Topic 1]"
    - "[Topic 2]"
```
  </chunked_reading_strategy>
  
  <using_summaries_for_work>
  When doing work that references large files:
  
  1. FIRST: Read the summary from large-file-summaries/ (small file, fits in context)
  
  2. Use aggregate_summary for high-level information
  
  3. If specific detail needed:
     - Check chunk_summaries to find which chunk has the content
     - Read ONLY that chunk: view [file] [start, end]
     - Extract the specific [item] needed
     - Do NOT keep entire file in context
     
  4. Cite using file + chunk reference:
     "[Source: [filename], Chunk N, Lines X-Y]"
     
  5. For comprehensive outputs:
     - Use aggregate_summary from the summary file
     - Pull specific details chunk by chunk as needed
     - Write output incrementally, saving after each section
     - If compacted, resume from saved progress
  </using_summaries_for_work>
  
  <memory_efficient_patterns>
    <pattern name="Summarise then discard">
      Read chunk → Extract key info → Write to summary file → Move to next chunk
      Don't try to keep entire large file in context.
    </pattern>
    
    <pattern name="Reference not re-read">
      Once summarised, reference the summary file.
      Only re-read original when exact wording/syntax needed.
    </pattern>
    
    <pattern name="Incremental output building">
      For outputs requiring large file content:
      - Write output section by section
      - Save after each section
      - Update progress.yaml with what's done
      - If compacted, resume from saved progress
    </pattern>
    
    <pattern name="Targeted chunk access">
      Need specific item? Don't re-read whole file.
      1. Read summary to find which chunk has it
      2. Read only that chunk
      3. Extract what you need
      4. Discard chunk from context
    </pattern>
  </memory_efficient_patterns>
</large_file_handling>
```

### Size Thresholds Reference

| Category | Size | Line Count (est.) | Handling |
|----------|------|-------------------|----------|
| Small | < 50KB | < 800 lines | Read entirely, still summarise to disk |
| Medium | 50-100KB | 800-1500 lines | Usually OK, summarise anyway, monitor for truncation |
| Large | > 100KB | > 1500 lines | **Chunked reading mandatory** |

### Chunk Size Recommendations

| Content Type | Lines per Chunk | Rationale |
|--------------|-----------------|-----------|
| Specification files | 300-400 | Dense, many definitions |
| Code files (`.ts`, `.ex`) | 300-400 | Dense, need context |
| Markdown docs | 400-500 | Prose is less dense |
| YAML/JSON | 200-300 | Structured, easy to break |
| Architecture docs | 300-400 | Mixed content |

---

## Avoiding Arbitrary Limits Pattern

### The Problem

Arbitrary limits like `head -20` or `tail -50` in file discovery cause **silent data loss**:
- Files beyond the limit are never processed
- Verification passes on partial data
- Issues in truncated files go undetected
- As the project grows, more data is silently dropped

### The Rule: NEVER Truncate File Discovery

```bash
# ❌ DANGEROUS - Silent data loss
for file in $(find . -name "*.ts" | head -50); do
  process "$file"
done

# ❌ DANGEROUS - Verifies only 20 of potentially 500+ files
for file in $(find "$DIR" -name "*.json" | head -20); do
  verify "$file"
done
```

### Safe Patterns

#### Pattern 1: Process ALL Files (Preferred)
```bash
# ✅ SAFE - Processes everything
for file in $(find . -name "*.ts"); do
  process "$file"
done
```

#### Pattern 2: Show Count + Process All
```bash
# ✅ SAFE - Transparent about volume
TOTAL=$(find . -name "*.ts" | wc -l)
echo "Processing $TOTAL files..."
PROCESSED=0
for file in $(find . -name "*.ts"); do
  ((PROCESSED++))
  echo "[$PROCESSED/$TOTAL] $(basename "$file")"
  process "$file"
done
```

#### Pattern 3: Warn if Multiple When Expecting Single
```bash
# ✅ SAFE - Use when you expect exactly one file
COUNT=$(find "$DIR" -maxdepth 1 -name "plugin.json" | wc -l)
if [ "$COUNT" -eq 0 ]; then
  echo "ERROR: No plugin.json found in $DIR"
  exit 1
elif [ "$COUNT" -gt 1 ]; then
  echo "WARNING: Multiple plugin.json files in $DIR:"
  find "$DIR" -maxdepth 1 -name "plugin.json"
  echo "Using first one - verify this is correct"
fi
FILE=$(find "$DIR" -maxdepth 1 -name "plugin.json" | head -1)
```

#### Pattern 4: Explicit Sampling (When Justified)
```bash
# ✅ ACCEPTABLE - Only when full processing is impossible
# Must be explicitly justified and transparent
TOTAL=$(find . -name "*.ts" | wc -l)
SAMPLE_SIZE=100

if [ "$TOTAL" -gt "$SAMPLE_SIZE" ]; then
  echo "⚠️ SAMPLING: Checking $SAMPLE_SIZE of $TOTAL files (random sample)"
  echo "   Full verification would take too long"
  FILES=$(find . -name "*.ts" | shuf | head -$SAMPLE_SIZE)
else
  FILES=$(find . -name "*.ts")
fi

for file in $FILES; do
  verify "$file"
done
```

### When head -1 IS Safe

`head -1` is acceptable when extracting a **single value**, not when limiting results:

```bash
# ✅ SAFE - Extracting single value from command output
JAVA_VERSION=$(java -version 2>&1 | head -1)

# ✅ SAFE - Parsing YAML for specific field
STATUS=$(grep "status:" progress.yaml | head -1 | awk '{print $2}')

# ✅ SAFE - Getting first match from grep (intentional)
FIRST_ERROR=$(grep "ERROR" build.log | head -1)
```

### When tail -N IS Safe

`tail -N` is acceptable for **display purposes** (showing recent output):

```bash
# ✅ SAFE - Display only, not processing
echo "Last 20 lines of build output:"
cat build.log | tail -20

# ✅ SAFE - Showing test summary
bun test 2>&1 | tail -20
```

### Checklist for Prompt Authors

Before finalising any prompt, verify:

- [ ] No `head -N` (N>1) in any `find` pipeline
- [ ] No `tail -N` limiting file discovery
- [ ] All file loops process complete results
- [ ] Any single-file selection (`head -1`) warns if multiple found
- [ ] Sampling is explicit, justified, and transparent
- [ ] File counts are displayed before processing

### Real-World Impact

| Pattern | Files Found | Files Processed | Data Loss |
|---------|-------------|-----------------|-----------|
| `find \| head -20` | 509 | 20 | **96%** |
| `find \| head -50` | 509 | 50 | **90%** |
| `find \| head -100` | 509 | 100 | **80%** |
| `find` (no limit) | 509 | 509 | **0%** |

---

## Agent Data Integrity Directive

### Purpose

This directive provides agents with explicit rules against sampling, truncation, and partial processing. Include it in any agent spawn template or standalone prompt that processes multiple files or large datasets.

### Why This Exists

AI agents naturally tend to "sample" or "summarise" when encountering large datasets:
- Sampling misses edge cases hidden in unprocessed files
- Truncated file reads miss critical constraints buried later in documents
- Partial processing creates false confidence ("all 14 items analysed" when only 8 were)
- "Representative subsets" give incomplete results

The "Avoiding Arbitrary Limits Pattern" above addresses bash-level anti-patterns (`head -N` in `find` pipelines). This directive addresses the **higher-level agent behaviour** — the tendency to process "enough" rather than "all".

### The Directive (Injection-Ready)

Copy this block into any prompt that processes multiple files or large datasets:

```markdown
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
```

### Checklist for Prompt Authors

When creating prompts that will be executed by agents:

- [ ] Does the prompt process multiple source files? → Include the directive
- [ ] Does the prompt read large files (>50KB)? → Include large file handling + directive
- [ ] Does the prompt iterate over a collection? → Include "process ALL" instruction
- [ ] Is there a risk the agent might use head/tail? → Add explicit prohibition
- [ ] Does the output claim to be "comprehensive"? → Include verification that ALL items appear

### Integration with Agent Prompts

Copy the directive block above into any agent prompt's `<foundational_principles>` or `<critical_reminders>` section. For multi-agent orchestration templates, embed it in the agent spawn template so all spawned agents automatically receive it.

---

## Progress Tracking Patterns

### Basic Progress.yaml Structure

```yaml
progress:
  last_updated: "2025-01-06T10:30:00Z"
  current_phase: "2"
  current_step: "2.3"
  status: "In Progress"
  
  phases:
    phase_0:
      status: "Complete"
      completed_at: "2025-01-06T09:00:00Z"
    phase_1:
      status: "Complete"
      completed_at: "2025-01-06T10:00:00Z"
    phase_2:
      status: "In Progress"
      steps_completed: ["2.1", "2.2"]
      current_step: "2.3"
      
  work_completed:
    - item: "Source discovery"
      completed_at: "2025-01-06T09:00:00Z"
    - item: "File summaries"
      completed_at: "2025-01-06T09:30:00Z"
      
  work_in_progress:
    - item: "Component design - Payment service"
      status: "API defined, implementation pending"
      
  work_remaining:
    - "Component design - Notification service"
    - "Integration testing specs"
    - "Documentation"
    
  blockers: []
  
  next_action: "Complete Payment service implementation in phase 2, step 2.3. Read existing API from .work/payment-api.yaml and generate implementation."
```

### Task-Specific Progress Extensions

#### For Multi-Level Tasks
```yaml
levels:
  level_1:
    status: "Complete"
    specs_created: 5
    counterexamples_found: 2
  level_2:
    status: "In Progress"
    current_context: "Pipeline"
```

#### For Multi-Persona Tasks
```yaml
personas:
  security_architect:
    status: "Complete"
    findings_critical: 1
    findings_high: 3
  cost_analyst:
    status: "In Progress"
    sections_reviewed: 3
```

#### For Multi-Phase Architecture
```yaml
phases:
  discovery:
    status: "Complete"
  high_level:
    status: "Complete"
    adrs_created: 5
  detailed:
    status: "In Progress"
    components_designed: 3
    components_remaining: 4
```

---

## Checkpoint Strategies

### When to Checkpoint

| Event | Action |
|-------|--------|
| Phase/Level/Step completed | Update progress.yaml, write summary |
| Major deliverable created | Update progress.yaml, note file path |
| Significant finding discovered | Write to findings file immediately |
| Before complex operation | Save current state |
| After 5-10 minutes of work | Quick progress.yaml update |

### Checkpoint File Naming

```
.work/
├── progress.yaml                    # Always present
├── source-discovery.yaml            # After discovery
├── [phase]-checkpoint.yaml          # After each phase
├── [level]-checkpoint.yaml          # After each level
├── source-summaries/
│   └── [FILE_ID].yaml              # Per source file
├── large-file-summaries/
│   └── [FILE_ID].yaml              # Per large file
└── [task-specific]/
    └── [task-specific-files].yaml  # As needed
```

---

## Begin Section Template

Use this template for the `<begin>` section of any prompt:

```xml
<begin>
=====================================
CRITICAL: CHECK FOR EXISTING PROGRESS FIRST
=====================================
This work may have been started before context compaction.

FIRST ACTION - Check for existing progress:
```bash
cat [OUTPUT_DIR]/.work/progress.yaml 2>/dev/null || echo "NO_PROGRESS_FILE"
```

IF progress file exists:
- Read current_phase, current_step, next_action
- Resume from where you left off
- Do NOT restart from beginning
- Use .work/ summaries, not re-reading sources

IF no progress file (fresh start):
- Proceed with Phase 0 (Discovery/Prerequisites)
- Create .work/ directory structure first

=====================================
CRITICAL: COMPACTION SURVIVAL
=====================================
This work WILL span multiple context compactions.

ALWAYS:
- Write progress to .work/progress.yaml after each significant step
- Write summaries to .work/ directories, not to context memory
- Complete one unit of work fully before starting another
- Document next_action clearly for resumption

=====================================
CRITICAL: LARGE FILE HANDLING
=====================================
Some source files exceed token limits.

For files >100KB:
- Read in chunks of ~300-500 lines
- Summarise each chunk immediately
- Write to .work/large-file-summaries/
- Use summaries for subsequent work, not re-reading original

=====================================
BEGIN NOW
=====================================
FIRST: Check for existing progress (see command above)

IF resuming: Follow next_action from progress.yaml

IF fresh start: 
1. Create .work/ directory structure
2. Run discovery on source files
3. Proceed with Phase 0

[Add any task-specific starting instructions here]
</begin>
```

---

## Critical Reminders Template

Use this template for the `<critical_reminders>` section:

```xml
<critical_reminders>
================================================================================
                    CRITICAL REMINDERS
================================================================================

1. **STATE IN FILES, NOT CONTEXT**
   - progress.yaml is truth
   - Context may compact any time
   - Checkpoint after every [significant unit]

2. **CHECK BEFORE STARTING**
   - Always read progress.yaml first
   - Resume from next_action if exists
   - Never restart completed work

3. **LARGE FILES NEED CHUNKING**
   - Files >100KB require chunked reading
   - Summarise to .work/ as you go
   - Reference summaries, not originals

4. **COMPLETE BEFORE MOVING ON**
   - Finish one [unit] before starting another
   - Write checkpoint before transitions
   - Document what comes next

5. **[TASK-SPECIFIC REMINDER 1]**
   - [Details]

6. **[TASK-SPECIFIC REMINDER 2]**
   - [Details]

[Add more task-specific reminders as needed]

</critical_reminders>
```

---

## Customisation Guide

### Step 1: Determine Task Characteristics

Answer these questions:
1. How many phases/levels/steps? → Determines progress structure
2. What are the major deliverables? → Determines checkpoint triggers
3. What source files are involved? → Determines large file handling
4. What task-specific state needs tracking? → Determines additional .work/ files

### Step 2: Customise Progress Tracking

Based on your task structure:
- **Linear phases**: Use `phase_0`, `phase_1`, etc.
- **Levels**: Use `level_1`, `level_2`, etc.
- **Personas/Actors**: Use named personas
- **Parallel work streams**: Use named work streams

### Step 3: Customise Large File Handling

Based on your source files:
- **Specification files**: Extract invariants, rules, types
- **Architecture docs**: Extract decisions, components, constraints
- **Requirements**: Extract requirements, acceptance criteria
- **Code files**: Extract interfaces, key functions, dependencies

### Step 4: Add Task-Specific Tracking

Common additions:
- `counterexamples.yaml` - For verification tasks
- `adr-index.yaml` - For architecture tasks
- `findings.yaml` - For review/audit tasks
- `[entity]-status.yaml` - For multi-entity tasks

### Step 5: Test Resumption

Before finalising a prompt:
1. Run it until partway through
2. Simulate compaction (start fresh context)
3. Verify it resumes correctly from progress.yaml
4. Verify it uses summaries instead of re-reading files

---

## Quick Reference Card

### First Action (Always)
```bash
cat [OUTPUT_DIR]/.work/progress.yaml 2>/dev/null || echo "NO_PROGRESS_FILE"
```

### Directory Structure
```
.work/
├── progress.yaml           # ALWAYS - update frequently
├── source-discovery.yaml   # ALWAYS - file catalogue
├── source-summaries/       # Per-file summaries
├── large-file-summaries/   # Chunked summaries
└── [task-specific]/        # As needed
```

### Size Thresholds
- Small: < 50KB → Read entirely
- Medium: 50-100KB → Monitor for truncation
- Large: > 100KB → **Chunk required**

### Checkpoint Triggers
- After every major deliverable
- After every phase/level complete
- After every 5-10 minutes of work
- Before any complex operation

### Memory Patterns
1. Summarise then discard
2. Reference not re-read
3. Incremental output building
4. Targeted chunk access

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-06 | Initial rubric created from production prompt patterns |
| 1.1 | 2026-03-01 | Added Agent Data Integrity Directive (section 7), `<data_integrity>` to prompt structure template |
| 1.2 | 2026-03-10 | Generalised for plugin ecosystem use; removed project-specific references |
