![Rafa](rafa.png)

# Rafa — Autonomous Task Agent

Drop this folder into any project. Write your tasks in `TASKS.json`. Let Rafa work through them autonomously — committing as it goes, updating Linear, and sending you a Slack DM after each one.

Rafa is a team-flavored take on the [Ralph](https://ghuntley.com/ralph/) pattern: an AI coding agent running in a loop, picking tasks, doing the work, and reporting back.

---

## How it works

1. You write tasks in `TASKS.json` with a status, owner, and optional dependencies
2. You run `./scripts/create-linear-tasks.sh` once to create matching issues in Linear
3. You run `./afk-rafa.sh -n 5` (or however many tasks you want)
4. Rafa picks the next eligible task, marks it "In Progress" in Linear, does the work, commits, then marks it "Ready for Review" and DMs you on Slack
5. Repeat until done

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
- Set `linear.enabled` and `slack.enabled` to `true`

### 6. Write your tasks in `TASKS.json`

Replace the example tasks with your real ones. See the [Task format](#task-format) section below.

### 7. Bootstrap: create Linear issues from your task list

```bash
./scripts/create-linear-tasks.sh --dry-run   # Preview first
./scripts/create-linear-tasks.sh             # Create issues + update TASKS.json
git add TASKS.json && git commit -m "rafa: link Linear issues"
```

This creates one Linear issue per task (skipping any that already have a `linear_issue_id`) and writes the identifiers back into `TASKS.json`.

### 8. Run Rafa

```bash
# Start with human-in-the-loop — watch one task, then decide
./rafa-once.sh

# Go AFK — run up to N tasks autonomously
./afk-rafa.sh -n 5
```

---

## Task format

Edit `TASKS.json`. Each task looks like this:

```json
{
  "id": "T001",
  "title": "Set up project structure",
  "description": "Create the src/, tests/, and docs/ folders. Add a .gitignore covering node_modules and .env. Create an empty README.md.",
  "status": "todo",
  "owner": "bot",
  "dependencies": [],
  "priority": 1,
  "linear_issue_id": "",
  "notes": ""
}
```

### Field reference

| Field | Values | Notes |
|-------|--------|-------|
| `id` | Any unique string | e.g. `T001`, `FEAT-01` |
| `title` | Short string | Shown in Linear and Slack |
| `description` | Markdown string | Rafa reads this and acts on it — be specific |
| `status` | `todo` `pending` `in_progress` `done` `failed` | Only `todo` tasks are eligible |
| `owner` | `bot` `human` `both` | `human` tasks are always skipped |
| `dependencies` | Array of task IDs | All must be `done` before this task is eligible |
| `priority` | Integer (1 = highest) | Maps to Linear priority: 1=Urgent, 2=High, 3=Medium, 4+=Low |
| `linear_issue_id` | e.g. `ENG-42` | Filled automatically by `create-linear-tasks.sh` |
| `notes` | String | Human notes; Rafa writes failure reasons here |

### Status rules — what Rafa picks

Rafa picks a task only when ALL of the following are true:
- `status` is `todo`
- `owner` is `bot` or `both`
- Every task in `dependencies` has `status: done`

Everything else is skipped.

---

## Linear setup

Rafa needs a Personal API key to create and update issues.

1. Go to **Linear → Settings → API → Personal API keys**
2. Click **Create key**, name it `Rafa`, copy the value
3. Add to `.env`: `LINEAR_API_KEY=lin_api_...`
4. Set your team slug in `rafa-config.json` → `linear.team_id`
5. Set your project in `rafa-config.json` → `linear.project_id` (name or slugId)
6. Verify your Linear workflow state names match what's in `rafa-config.json`:
   - `todo_state_name` — usually `"Todo"` or `"Backlog"`
   - `in_progress_state_name` — usually `"In Progress"`
   - `done_state_name` — `"Ready for Review"` by default (so a human reviews before closing)
7. Set `linear.enabled` to `true`

**Task lifecycle in Linear:**

```
[Todo] → (Rafa starts task) → [In Progress] → (Rafa finishes) → [Ready for Review]
```

A human then reviews and moves to Done (or back to In Progress with feedback).

---

## Slack DM setup

Rafa sends you a private message on Slack when it starts a task, finishes one, and when all tasks are complete. Setup takes about 5 minutes.

### Step 1 — Create a Slack app

1. Go to [api.slack.com/apps](https://api.slack.com/apps) → **Create New App** → **From scratch**
2. Name it `Rafa`, pick your workspace, click **Create App**

### Step 2 — Add bot scopes

1. In the app settings, go to **OAuth & Permissions**
2. Under **Bot Token Scopes**, add:
   - `chat:write` — to send messages
   - `im:write` — to open DM conversations
3. Click **Install to Workspace** and authorize

### Step 3 — Copy the Bot Token

Under **OAuth & Permissions → OAuth Tokens**, copy the **Bot User OAuth Token** (starts with `xoxb-`).

Add to `.env`:
```
SLACK_BOT_TOKEN=xoxb-xxxxxxxxxxxx-xxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxx
```

### Step 4 — Find your Slack User ID

In Slack: click your profile picture → **View profile** → **⋯** (More) → **Copy member ID**.

Add to `.env`:
```
SLACK_NOTIFY_USER_ID=UXXXXXXXXXX
```

Each person on the team sets their own `SLACK_NOTIFY_USER_ID` in their `.env`.

### Step 5 — Invite the bot to your DMs

In Slack, search for your app name (`Rafa`) and send it a message. This opens the DM channel and lets the bot reply.

### Step 6 — Enable in config

In `rafa-config.json`:
```json
"slack": {
  "enabled": true,
  "mode": "dm",
  ...
}
```

---

## Running Rafa

```bash
# One task at a time (human-in-the-loop, great for first run)
./rafa-once.sh

# Up to N tasks autonomously
./afk-rafa.sh -n 3
./afk-rafa.sh -n 20

# Preview what create-linear-tasks.sh would do without creating anything
./scripts/create-linear-tasks.sh --dry-run
```

Rafa stops automatically when there are no more eligible tasks and outputs `COMPLETE`.

---

## File overview

```
rafa/
├── README.md                  ← This file
├── TASKS.json                 ← Your task list (edit this per project)
├── rafa-config.json           ← Integration settings (edit this per project)
├── .env.example               ← Template — copy to .env and fill in keys
├── .env                       ← Your personal API keys (gitignored)
├── rafa-once.sh               ← Single task, human-in-the-loop
├── afk-rafa.sh                ← Autonomous loop with -n flag
├── progress.md                ← Auto-updated log of completed tasks
└── scripts/
    ├── create-linear-tasks.sh ← Bootstrap: TASKS.json → Linear issues
    ├── update-linear.sh       ← Called by Rafa to update Linear status
    └── notify-slack.sh        ← Called by Rafa to send Slack DMs
```

---

## Tips

**Write specific task descriptions.** Rafa only reads the `description` field when deciding what to do. Vague descriptions lead to vague results. Be as specific as you would be in a code review comment.

**Use dependencies to sequence work.** If task B can't start until A is done, add `"dependencies": ["T001"]` to B. Rafa will wait.

**Mark human tasks explicitly.** Set `"owner": "human"` for anything that requires judgment, approval, or real-world action. Rafa will skip it and move on.

**Use `pending` to pause a task.** If a task is temporarily blocked (waiting on an external dependency, a client decision, etc.), set its status to `pending`. Change it back to `todo` when it's unblocked.

**Start with `rafa-once.sh`.** Always run a single iteration first when setting up a new project. Check the commit, verify Linear updated, check Slack. Then switch to `afk-rafa.sh`.
