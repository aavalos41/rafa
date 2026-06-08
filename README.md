![Rafa](rafa.png)

# RAFA | Recursive Autonomous Feature Agent

Drop this folder into any project. Plan your work using AI skills, write tasks in `TASKS.json`, and let Rafa execute them autonomously; committing as it goes, updating Linear to **In Review** when done, and sending you a Slack message after each one.

Rafa is a team-flavored take on the [Ralph](https://ghuntley.com/ralph/) pattern: an AI coding agent running in a loop, picking tasks, doing the work, and reporting back.

Linear and Slack are handled natively through Claude Code's MCP connections: no API keys, no shell scripts.

---

## The full workflow

```
┌─ PLAN (human, in Claude Code) ───────────────────────────────────────────┐
│                                                                          │
│  /grill-me          Stress-test your plan — Claude interviews you        │
│       ↓             one question at a time until the design is solid     │
│  /to-prd            Synthesize the conversation into a structured PRD    │
│       ↓                                                                  │
│  /to-rafa-tasks     Break the PRD into TASKS.json (vertical slices,      │
│                     dependencies, owners, priorities, TDD flags)         │
│       ↓                                                                  │
│  Create Linear      Use Claude Code to create Linear issues directly     │
│  issues             via MCP — paste the linear_issue_ids into TASKS.json │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
        ↓
┌─ EXECUTE (autonomous) ───────────────────────────────────────────────────┐
│  ./rafa-once.sh       Pick the next task, implement, commit, update      │
│  ./afk-rafa.sh -n N   Linear → In Review, and post to Slack              │
└──────────────────────────────────────────────────────────────────────────┘
```

**Task lifecycle in Linear:**

```
[Todo] → (Rafa starts) → [In Progress] → (Rafa finishes) → [In Review]
                                                                   ↓
                                             Human reviews, then closes or sends back
```

---

## Prerequisites

- **Claude Code** with the [claude.ai MCP connections](https://claude.ai/settings/integrations) for **Linear** and **Slack** authenticated
- `git` available in your shell
- That's it — no `jq`, no API keys in `.env`, no extra tools

---

## Skills

Install these Claude Code skills to power the planning phases. See [`skills/README.md`](skills/README.md) for installation instructions.

| Skill           | What it does                                                           |
| --------------- | ---------------------------------------------------------------------- |
| `grill-me`      | Interviews you about your plan, one question at a time                 |
| `to-prd`        | Synthesizes conversation into a structured PRD                         |
| `to-rafa-tasks` | Converts PRD into `TASKS.json` with Rafa's schema (lives in `skills/`) |
| `tdd`           | Red-green-refactor guidance for manual sessions                        |

---

## Setup (for each new project)

### 1. Copy this folder into your project and init git

```bash
cp -r /path/to/rafa ./Rafa
cd Rafa
git init
git add -A
git commit -m "chore: add Rafa"
```

### 2. Make scripts executable

```bash
chmod +x rafa-once.sh afk-rafa.sh
```

### 3. Configure `rafa-config.json`

Open `rafa-config.json` and set:

- `project_name` — your project name (appears in Slack messages)
- `linear.done_state_name` — must match your Linear workflow state exactly (default: `"In Review"`)
- `slack.notify_channel_id` — Slack channel ID to post messages to (e.g. `C08CQBC1NG7`)
- `tdd.enabled` — `true` to use red-green-refactor on all bot tasks

### 4. Connect Linear and Slack via Claude Code MCP

In Claude Code, connect the **Linear** and **Slack** integrations at [claude.ai/settings/integrations](https://claude.ai/settings/integrations). Rafa uses these authenticated connections directly — no API keys needed.

### 5. Plan your work

Use Claude Code skills to go from idea to tasks:

```
/grill-me      ← stress-test the plan
/to-prd        ← synthesize into a PRD
/to-rafa-tasks ← write tasks to TASKS.json automatically
```

Then, still in Claude Code, create your Linear issues using the Linear MCP tool and paste the returned identifiers (`LF-2`, `LF-3`, etc.) into each task's `linear_issue_id` field in `TASKS.json`.

### 6. Run Rafa

```bash
# One task, fully autonomous
./rafa-once.sh

# Up to N tasks autonomously
./afk-rafa.sh -n 5
```

---

## Task format

Each task in `TASKS.json` looks like this:

```json
{
  "id": "T001",
  "title": "Set up project structure",
  "description": "Create the src/, tests/, and docs/ folders. Add a .gitignore covering node_modules and .env. Create an empty README.md.",
  "status": "todo",
  "owner": "bot",
  "dependencies": [],
  "priority": 1,
  "tdd": false,
  "linear_issue_id": "LF-2",
  "notes": ""
}
```

### Field reference

| Field             | Values                                         | Notes                                                              |
| ----------------- | ---------------------------------------------- | ------------------------------------------------------------------ |
| `id`              | Any unique string                              | e.g. `T001`, `FEAT-01`                                             |
| `title`           | Short string                                   | Shown in Linear and Slack                                          |
| `description`     | Markdown string                                | Rafa reads this literally — be specific                            |
| `status`          | `todo` `pending` `in_progress` `done` `failed` | Only `todo` tasks are picked up                                    |
| `owner`           | `bot` `human` `both`                           | `human` tasks are always skipped by Rafa                           |
| `dependencies`    | Array of task IDs                              | All must be `done` before this task is eligible                    |
| `priority`        | Integer (1 = highest)                          | Informational — Rafa picks the first eligible task                 |
| `tdd`             | `true` / `false`                               | Per-task TDD override. Inherits from `rafa-config.json` if omitted |
| `linear_issue_id` | e.g. `LF-2`                                    | Set when creating issues via Claude Code MCP                       |
| `notes`           | String                                         | Rafa writes failure reasons here                                   |

### Eligibility rules

Rafa picks a task only when ALL of these are true:

- `status` is `todo`
- `owner` is `bot` or `both`
- Every task in `dependencies` has `status: done`

---

## TDD

When `tdd.enabled` is `true` in `rafa-config.json`, Rafa follows red-green-refactor on every bot task:

1. **RED** — Write a failing test for one behavior (public interface only)
2. **GREEN** — Write minimal code to pass it
3. Repeat for each behavior
4. **REFACTOR** — Clean up once all tests pass

Per-task overrides with the `"tdd"` field:

- `"tdd": true` — force TDD on this task, even if globally disabled
- `"tdd": false` — opt this task out, even if globally enabled
- Omit the field — inherit the global setting

---

## Running Rafa

```bash
# One task — fully autonomous
./rafa-once.sh

# Up to N tasks autonomously
./afk-rafa.sh -n 3
./afk-rafa.sh -n 20
```

Both scripts use `claude -p --dangerously-skip-permissions` — they run entirely without prompting. Rafa stops automatically when no more eligible tasks exist.

---

## File overview

```
Rafa/
├── README.md            ← This file
├── SETUP.md             ← Quick-start checklist
├── TASKS.json           ← Your task list (edit per project)
├── rafa-config.json     ← Integration + TDD settings (edit per project)
├── .env.example         ← Template — copy to .env if you need git overrides
├── .env                 ← Optional local overrides (gitignored)
├── rafa-once.sh         ← Run one task autonomously
├── afk-rafa.sh          ← Autonomous loop with -n flag
├── progress.md          ← Auto-updated log of completed tasks
└── skills/
    ├── README.md        ← Skill installation guide
    └── to-rafa-tasks/   ← Converts PRD → TASKS.json (install this skill)
```

---

## Tips

**Write specific task descriptions.** Rafa reads the `description` field literally and acts on it. Vague descriptions produce vague results. Treat it like a ticket you're handing to a developer — include what files to touch, what interfaces to implement, and what done looks like.

**Use `/to-rafa-tasks` to write tasks for you.** After a planning session with `/grill-me` and `/to-prd`, run `/to-rafa-tasks` and Claude will draft the full task breakdown, quiz you on it, and write it directly to `TASKS.json`.

**Use dependencies to sequence work.** If task B can't start until A is done, add `"dependencies": ["T001"]` to B. Rafa will wait.

**Mark human tasks explicitly.** Set `"owner": "human"` for decisions, design reviews, or anything requiring real-world action. Rafa skips them and keeps moving.

**Use `pending` to pause a task.** Temporarily blocked? Set status to `pending`. Change it back to `todo` when unblocked.

**Enable TDD per task, not globally, to start.** Set `"tdd": true` on specific tasks that involve complex logic or need regression protection. Once you trust the pattern, enable it globally in `rafa-config.json`.
