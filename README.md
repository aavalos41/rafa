![Rafa](rafa.png)

# Rafa — Autonomous Task Agent

Drop this folder into any project. Plan your work using AI skills, write tasks in `TASKS.json`, and let Rafa execute them autonomously — committing as it goes, updating Linear, and sending you a Slack DM after each one.

Rafa is a team-flavored take on the [Ralph](https://ghuntley.com/ralph/) pattern: an AI coding agent running in a loop, picking tasks, doing the work, and reporting back.

---

## The full workflow

Rafa is designed to slot into a planning-to-execution pipeline. The human phases use Claude Code skills; the execution phase is fully autonomous.

```
┌─ PLAN (human, in Claude Code) ──────────────────────────────────────────┐
│                                                                          │
│  /grill-me          Stress-test your plan — Claude interviews you        │
│       ↓             one question at a time until the design is solid     │
│  /to-prd            Synthesize the conversation into a structured PRD    │
│       ↓                                                                  │
│  /to-rafa-tasks     Break the PRD into TASKS.json (vertical slices,      │
│                     dependencies, owners, priorities, TDD flags)         │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
        ↓
┌─ SYNC (one command) ────────────────────────────────────────────────────┐
│  ./scripts/create-linear-tasks.sh   Create Linear issues from TASKS.json│
└──────────────────────────────────────────────────────────────────────────┘
        ↓
┌─ EXECUTE (autonomous) ──────────────────────────────────────────────────┐
│  ./afk-rafa.sh -n N   Rafa picks tasks, implements, tests (TDD if on),  │
│                        commits, updates Linear → Ready for Review,       │
│                        and DMs you on Slack after each one               │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Skills

Install these Claude Code skills to power the planning phases. See [`skills/README.md`](skills/README.md) for installation instructions.

| Skill | Source | What it does |
|-------|--------|-------------|
| `grill-me` | [Matt Pocock's repo](https://github.com/mattpocock/skills) | Interviews you about your plan, one question at a time |
| `to-prd` | [Matt Pocock's repo](https://github.com/mattpocock/skills) | Synthesizes conversation into a structured PRD |
| `to-rafa-tasks` | **This repo** (`skills/to-rafa-tasks/`) | Converts PRD into `TASKS.json` with Rafa's schema |
| `tdd` | [Matt Pocock's repo](https://github.com/mattpocock/skills) | Red-green-refactor guidance for manual sessions |

`grill-me`, `to-prd`, and `tdd` are used as-is from Matt's repo. `to-rafa-tasks` is Rafa-specific and lives here.

---

## Setup (for each new project)

### 1. Copy this folder into your project

```bash
cp -r /path/to/rafa ./rafa
cd rafa
```

### 2. Install dependencies

```bash
# macOS
brew install jq

# Ubuntu / Debian
sudo apt install jq curl git
```

Make scripts executable:

```bash
chmod +x rafa-once.sh afk-rafa.sh scripts/*.sh
```

### 3. Initialize git (if not already done)

```bash
git init
git add -A
git commit -m "chore: add Rafa"
```

### 4. Create your `.env` file

```bash
cp .env.example .env
```

Fill in your personal API keys (see the Linear and Slack sections below). Everyone on the team has their own `.env` — it's gitignored.

### 5. Configure `rafa-config.json`

Open `rafa-config.json` and set:

- `project_name` — your project name
- `linear.team_id` — your Linear team slug (from the URL: `linear.app/YOUR-SLUG/...`)
- `linear.project_id` — your Linear project name or slugId
- `linear.done_state_name` — the Linear state Rafa moves issues to when done (default: `"Ready for Review"`)
- `slack.notify_user_id` — your Slack user ID (see Slack setup below)
- `tdd.enabled` — set to `true` if you want Rafa to use red-green-refactor on all bot tasks
- Set `linear.enabled` and `slack.enabled` to `true`

### 6. Plan your work (optional but recommended)

Use Claude Code skills to go from idea to tasks:

```
/grill-me    ← stress-test the plan
/to-prd      ← synthesize into a PRD
/to-rafa-tasks ← write tasks to TASKS.json automatically
```

Or skip straight to editing `TASKS.json` manually if you already know what to build.

### 7. Bootstrap: create Linear issues from your task list

```bash
./scripts/create-linear-tasks.sh --dry-run   # Preview first
./scripts/create-linear-tasks.sh             # Create issues + update TASKS.json
git add TASKS.json && git commit -m "rafa: link Linear issues"
```

### 8. Run Rafa

```bash
# Start with human-in-the-loop — watch one task, then decide
./rafa-once.sh

# Go AFK — run up to N tasks autonomously
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
  "linear_issue_id": "",
  "notes": ""
}
```

### Field reference

| Field | Values | Notes |
|-------|--------|-------|
| `id` | Any unique string | e.g. `T001`, `FEAT-01` |
| `title` | Short string | Shown in Linear and Slack |
| `description` | Markdown string | Rafa reads this literally — be specific |
| `status` | `todo` `pending` `in_progress` `done` `failed` | Only `todo` tasks are picked up |
| `owner` | `bot` `human` `both` | `human` tasks are always skipped by Rafa |
| `dependencies` | Array of task IDs | All must be `done` before this task is eligible |
| `priority` | Integer (1 = highest) | Maps to Linear: 1=Urgent, 2=High, 3=Medium, 4+=Low |
| `tdd` | `true` / `false` | Per-task TDD override. Inherits from `rafa-config.json` if omitted |
| `linear_issue_id` | e.g. `ENG-42` | Filled by `create-linear-tasks.sh` — leave empty |
| `notes` | String | Human notes; Rafa writes failure reasons here |

### Eligibility rules — what Rafa picks

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

You can also control TDD per task with the `"tdd"` field:
- `"tdd": true` — force TDD on this task, even if globally disabled
- `"tdd": false` — opt this task out, even if globally enabled
- Omit the field — inherit the global setting

---

## Linear setup

1. Go to **Linear → Settings → API → Personal API keys**
2. Create a key named `Rafa` and add it to `.env` as `LINEAR_API_KEY`
3. Set `linear.team_id` in `rafa-config.json` to your team slug
4. Set `linear.project_id` to your project name or slugId
5. Verify your workflow state names match the config (`todo_state_name`, `in_progress_state_name`, `done_state_name`)
6. Set `linear.enabled` to `true`

**Task lifecycle in Linear:**
```
[Todo] → (Rafa starts) → [In Progress] → (Rafa finishes) → [Ready for Review]
```
A human reviews and moves to Done, or sends back to In Progress with feedback.

---

## Slack DM setup

Rafa sends you a private DM when it starts a task, finishes one, and when all tasks are complete.

1. Go to [api.slack.com/apps](https://api.slack.com/apps) → **Create New App** → **From scratch**, name it `Rafa`
2. Go to **OAuth & Permissions** → add bot scopes: `chat:write`, `im:write`
3. Click **Install to Workspace** and copy the **Bot User OAuth Token** (`xoxb-...`) into `.env` as `SLACK_BOT_TOKEN`
4. Find your Slack user ID: click your name → **View profile** → **⋯** → **Copy member ID** → add to `.env` as `SLACK_NOTIFY_USER_ID`
5. In Slack, open a DM with your Rafa app and send it any message (this initializes the DM channel)
6. Set `slack.enabled` to `true` and `slack.mode` to `"dm"` in `rafa-config.json`

Each person on the team sets their own `SLACK_NOTIFY_USER_ID` in their personal `.env`.

---

## Running Rafa

```bash
# One task, human-in-the-loop (recommended for first run)
./rafa-once.sh

# Up to N tasks autonomously
./afk-rafa.sh -n 3
./afk-rafa.sh -n 20

# Preview Linear issue creation before committing
./scripts/create-linear-tasks.sh --dry-run
```

Rafa stops automatically when no more eligible tasks exist.

---

## File overview

```
rafa/
├── README.md                    ← This file
├── TASKS.json                   ← Your task list (edit per project)
├── rafa-config.json             ← Integration + TDD settings (edit per project)
├── .env.example                 ← Template — copy to .env and fill in keys
├── .env                         ← Your personal API keys (gitignored)
├── rafa-once.sh                 ← Single task, human-in-the-loop
├── afk-rafa.sh                  ← Autonomous loop with -n flag
├── progress.md                  ← Auto-updated log of completed tasks
├── skills/
│   ├── README.md                ← Skill installation guide
│   └── to-rafa-tasks/
│       └── SKILL.md             ← Converts PRD → TASKS.json (install this)
└── scripts/
    ├── create-linear-tasks.sh   ← Bootstrap: TASKS.json → Linear issues
    ├── update-linear.sh         ← Called by Rafa to update Linear status
    └── notify-slack.sh          ← Called by Rafa to send Slack DMs
```

---

## Tips

**Write specific task descriptions.** Rafa reads the `description` field literally and acts on it. Vague descriptions produce vague results. Treat it like a ticket you're handing to a developer — include what files to touch, what interfaces to implement, and what done looks like.

**Use `/to-rafa-tasks` to write tasks for you.** After a planning session with `/grill-me` and `/to-prd`, run `/to-rafa-tasks` and Claude will draft the full task breakdown, quiz you on it, and write it directly to `TASKS.json`.

**Use dependencies to sequence work.** If task B can't start until A is done, add `"dependencies": ["T001"]` to B. Rafa will wait.

**Mark human tasks explicitly.** Set `"owner": "human"` for decisions, design reviews, or anything requiring real-world action. Rafa skips them and keeps moving.

**Use `pending` to pause a task.** Temporarily blocked? Set status to `pending`. Change it back to `todo` when unblocked.

**Start with `rafa-once.sh`.** Always run a single iteration first on a new project. Verify the commit, check Linear updated, check your Slack DM. Then switch to `afk-rafa.sh`.

**Enable TDD per task, not globally, to start.** Set `"tdd": true` on specific tasks that involve complex logic or need regression protection. Once you trust the pattern, enable it globally in `rafa-config.json`.
