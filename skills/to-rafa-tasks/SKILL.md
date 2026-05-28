---
name: to-rafa-tasks
description: Convert a plan, PRD, or spec into Rafa's TASKS.json format using vertical tracer-bullet slices. Use after /to-prd or when you want to break a spec into tasks for autonomous execution. Outputs directly to TASKS.json.
---

# To Rafa Tasks

Convert the current plan or PRD into tasks that Rafa can execute autonomously. Each task becomes a vertical slice — thin, complete, and independently executable.

## Process

### 1. Gather context

Work from whatever is in the conversation: a PRD, a spec, a feature description, or the output of `/to-prd`. If the user passes a file path or issue reference, read it first.

### 2. Explore the codebase

If you have not already done so, explore the project structure to understand what already exists. This prevents creating tasks for things that are done, and makes descriptions more precise. Note the tech stack, file conventions, and any existing test setup — this informs how you phrase task descriptions and whether to set `tdd: true`.

### 3. Draft vertical slices

Break the plan into **tracer bullet** slices. Each slice is a thin vertical cut through all layers (data, logic, UI, tests) — NOT a horizontal layer (e.g. "write all tests" is not a valid slice).

Classify each slice as:
- **AFK** — Rafa can implement this autonomously without human input → `owner: "bot"`
- **HITL** — Requires a human decision, design review, external action, or approval → `owner: "human"`

Apply these rules:
- Each slice must be independently executable when its dependencies are done
- A completed slice is demoable or verifiable on its own
- Prefer many thin slices over few thick ones
- Write descriptions as precise instructions — Rafa reads them literally. Specify file paths, function names, interfaces, and acceptance criteria where possible.

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each slice show:

- **[ID]** Title
- **Owner**: bot (AFK) or human (HITL)
- **Priority**: 1 = highest
- **Depends on**: which other task IDs must be done first (or "none")
- **TDD**: yes/no (whether to apply red-green-refactor)
- **Description preview**: one sentence

Ask the user:
- Does the granularity feel right? (too coarse / too fine)
- Are the dependency relationships correct?
- Should any slices be merged, split, or reassigned to human?
- Are priorities roughly right?
- Should TDD apply globally, per-task, or not at all?

Iterate until the user approves.

### 5. Write to TASKS.json

Read the existing `TASKS.json`. If it already has tasks, **append** the new ones (do not replace existing tasks). Generate IDs that continue from the highest existing ID (e.g. if T005 exists, start at T006).

If `TASKS.json` does not exist, create it using the standard Rafa schema.

Write each approved slice as a task object following this exact schema:

```json
{
  "id": "T001",
  "title": "Short imperative title",
  "description": "Precise instructions Rafa will read and act on. Mention specific files, functions, interfaces, and acceptance criteria. Use markdown. Be explicit — vague descriptions produce vague results.",
  "status": "todo",
  "owner": "bot",
  "dependencies": [],
  "priority": 1,
  "tdd": false,
  "linear_issue_id": "",
  "notes": ""
}
```

Field rules:
- `id` — sequential, e.g. T001, T002. Never duplicate an existing ID.
- `status` — always `"todo"` for new tasks
- `owner` — `"bot"` for AFK slices, `"human"` for HITL slices, `"both"` if either can do it
- `dependencies` — array of task ID strings that must have `status: "done"` before this task is eligible. Empty array if none.
- `priority` — integer, 1 = highest. Assign based on dependency order and user feedback.
- `tdd` — `true` if red-green-refactor should apply, `false` otherwise. Defaults to `false`. Rafa also respects the global `tdd_enabled` flag in `rafa-config.json`.
- `linear_issue_id` — leave as `""`. The bootstrap script (`create-linear-tasks.sh`) fills this in.
- `notes` — leave as `""` for new tasks.

### 6. Confirm and commit

After writing `TASKS.json`, show the user a summary: how many tasks were added, how many are bot-owned vs human-owned, and what the dependency chain looks like.

Remind them to run:
```bash
./scripts/create-linear-tasks.sh --dry-run
```
...to preview Linear issue creation before syncing.

## Example output structure

```
T001 [bot, priority 1] Set up project scaffold
  └─ T002 [bot, priority 2] Implement data layer (depends: T001)
  └─ T003 [human, priority 2] Review data schema with team (depends: T001)
       └─ T004 [bot, priority 3] Build API endpoints (depends: T002, T003)
            └─ T005 [bot, priority 4] Add UI components (depends: T004)
            └─ T006 [bot, priority 4] Write integration tests (depends: T004, tdd: true)
```

## Important rules

- Never create a task with a vague description like "implement the feature". Write what Rafa needs to execute it without further input.
- Never set `status` to anything other than `"todo"` for new tasks.
- Always preserve existing tasks in `TASKS.json` — only append, never replace.
- If the plan includes things that are clearly already done (visible in the codebase), skip them or note them as `status: "done"` with an explanation in `notes`.
- Do NOT publish to Linear — that is handled separately by `create-linear-tasks.sh`.
