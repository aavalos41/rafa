# Rafa Setup Guide

This is your autonomous agent loop. Rafa reads `TASKS.json`, picks eligible tasks, does the work, commits it, and updates Linear and Slack as it goes.

---

## What you need to do first

### 1. One-time system setup

Install the tools Rafa's scripts depend on:

```bash
# macOS
brew install jq

# Ubuntu/Debian
apt install jq curl git
```

Make all scripts executable:

```bash
chmod +x rafa-once.sh afk-rafa.sh scripts/update-linear.sh scripts/notify-slack.sh
```

Init a git repo if you haven't already:

```bash
git init
git add -A
git commit -m "chore: Rafa setup"
```

---

### 2. Set up your `.env` file

Copy the example and fill in your keys:

```bash
cp .env.example .env
```

Then edit `.env`. You only need the keys for integrations you're using.

---

### 3. Linear integration (optional)

Rafa can update Linear issue statuses as it works. Here's what you need:

**a) Get a Linear API key**
1. Go to Linear → top-left avatar → **Settings**
2. Navigate to **API** → **Personal API keys**
3. Click **Create key**, give it a name (e.g. "Rafa"), copy the key
4. Paste it as `LINEAR_API_KEY` in your `.env`

**b) Find your Team ID**
Your team ID is the slug in your Linear URL: `linear.app/YOUR-TEAM-ID/...`
Set `team_id` in `rafa-config.json` to that slug.

**c) Set your "Done" state name**
In `rafa-config.json`, set `done_state_name` to whatever your "Done" workflow state is called in Linear. It's usually `"Done"` or `"Completed"` — it must match exactly.

**d) Link tasks to Linear issues**
For each task in `TASKS.json` that has a matching Linear issue, set the `linear_issue_id` field to the issue identifier:
```json
"linear_issue_id": "ENG-42"
```

**e) Enable Linear in config**
In `rafa-config.json`, set `"enabled": true` under `"linear"`.

---

### 4. Slack integration (optional)

Rafa sends a Slack message when it starts a task, finishes a task, and when all tasks are complete.

**a) Create a Slack app**
1. Go to [api.slack.com/apps](https://api.slack.com/apps) → **Create New App** → **From scratch**
2. Name it "Rafa" and pick your workspace
3. Go to **Incoming Webhooks** → toggle **Activate Incoming Webhooks** to On
4. Click **Add New Webhook to Workspace**, select your channel
5. Copy the webhook URL (starts with `https://hooks.slack.com/services/...`)
6. Paste it as `SLACK_WEBHOOK_URL` in your `.env`

**b) Enable Slack in config**
In `rafa-config.json`, set `"enabled": true` under `"slack"`.

That's it — no bot tokens, no OAuth, just one webhook URL.

---

### 5. Fill in your tasks

Edit `TASKS.json`. For each task:

| Field | What to put |
|-------|-------------|
| `id` | Unique ID, e.g. `T001`, `T002` |
| `title` | Short task name |
| `description` | Clear instructions — Rafa will read this and act on it |
| `status` | Start with `todo` (or `pending` if blocked) |
| `owner` | `bot` = Rafa does it, `human` = Rafa skips it, `both` = either |
| `dependencies` | List of task IDs that must be `done` before this can start |
| `priority` | Lower number = higher priority (Rafa picks lowest priority number first) |
| `linear_issue_id` | Linear issue identifier, e.g. `ENG-42`. Leave empty to skip. |

---

## Running Rafa

### First time — human-in-the-loop (recommended)
Watch what Rafa does before going AFK:

```bash
./rafa-once.sh
```

This runs one task. Check the git log and files after. Run it again to do the next task.

### AFK mode — fully autonomous loop

```bash
./afk-rafa.sh -n 5     # Do up to 5 tasks, then stop
./afk-rafa.sh -n 20    # Do up to 20 tasks
```

Rafa will stop early if it runs out of eligible tasks (outputs `COMPLETE`).

---

## Task eligibility rules

Rafa will pick a task only if ALL of the following are true:
- `status` is `todo`
- `owner` is `bot` or `both`
- Every task in `dependencies` has `status: done`

Rafa skips: `pending`, `in_progress`, `done`, `failed` statuses — and any task owned by `human`.

---

## File overview

```
.
├── TASKS.json          ← Your task list (edit this)
├── rafa-config.json   ← Integration settings (edit this)
├── .env                ← API keys (create from .env.example, never commit)
├── .env.example        ← Template
├── rafa-once.sh       ← Run one task (human-in-the-loop mode)
├── afk-rafa.sh        ← Run N tasks autonomously
├── progress.md         ← Auto-updated log of completed tasks
└── scripts/
    ├── update-linear.sh    ← Called by Rafa to sync Linear
    └── notify-slack.sh     ← Called by Rafa to send Slack messages
```
