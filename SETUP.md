# Rafa Setup Guide

Quick-start checklist for getting Rafa running on a new project.

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| **Claude Code CLI** | `claude` must be available in your shell |
| **Linear MCP** | Authenticated via [claude.ai/settings/integrations](https://claude.ai/settings/integrations) |
| **Slack MCP** | Authenticated via [claude.ai/settings/integrations](https://claude.ai/settings/integrations) |
| **git** | Already in your shell |

No `jq`, no API keys, no extra tools. Linear and Slack are handled through Claude Code's native MCP connections.

---

## Step 1 — Make scripts executable

```bash
chmod +x rafa-once.sh afk-rafa.sh
```

---

## Step 2 — Initialize git (if not already done)

```bash
git init
git add -A
git commit -m "chore: Rafa setup"
```

---

## Step 3 — Configure `rafa-config.json`

| Setting | What to set |
|---------|-------------|
| `project_name` | Your project name — appears in Slack messages |
| `linear.enabled` | `true` to sync status to Linear |
| `linear.done_state_name` | The Linear workflow state Rafa sets when finished (must match exactly — default: `"In Review"`) |
| `linear.in_progress_state_name` | The state Rafa sets when starting a task (default: `"In Progress"`) |
| `slack.enabled` | `true` to post Slack notifications |
| `slack.notify_channel_id` | Slack channel ID to post to (e.g. `C08CQBC1NG7`) |
| `tdd.enabled` | `true` to enforce red-green-refactor on all bot tasks |

---

## Step 4 — Authenticate MCP connections

In Claude Code, ensure both integrations are connected:

1. Open [claude.ai/settings/integrations](https://claude.ai/settings/integrations)
2. Connect **Linear** — Rafa uses this to move issues through `Todo → In Progress → In Review`
3. Connect **Slack** — Rafa uses this to post task start/done messages to your channel

No API keys go in `.env`. Authentication is handled by Claude Code's MCP layer.

---

## Step 5 — Build your task list

### Option A — Use Claude Code skills (recommended)

```
/grill-me      ← stress-test the plan
/to-prd        ← synthesize into a PRD
/to-rafa-tasks ← write tasks to TASKS.json automatically
```

### Option B — Edit TASKS.json manually

Set each task's `status` to `todo`, `owner` to `bot`, and fill in the `description` in detail. See `README.md` for the full field reference.

---

## Step 6 — Create Linear issues and link them

In a Claude Code session, ask Claude to create Linear issues for your tasks — it will use the Linear MCP tool directly. When done, paste the returned identifiers (e.g. `LF-2`, `LF-3`) into the `linear_issue_id` field of each task in `TASKS.json`.

---

## Step 7 — Run Rafa

```bash
# Single task — good for verifying the setup
./rafa-once.sh

# Multiple tasks — let it run
./afk-rafa.sh -n 5
```

Both scripts are fully autonomous (`-p --dangerously-skip-permissions`). They will not pause for input.

After the first run, check:
- [ ] A commit was made with the task changes
- [ ] The Linear issue moved to **In Progress**, then **In Review**
- [ ] A Slack message appeared in your channel

---

## Troubleshooting

**Rafa outputs `COMPLETE` immediately** — No task has `status: todo` with all dependencies satisfied. Check TASKS.json for blocked tasks or tasks still marked `in_progress` from a prior run.

**Linear not updating** — Verify `linear.enabled: true` in `rafa-config.json` and that your Claude Code MCP connection for Linear is authenticated.

**Slack not posting** — Verify `slack.enabled: true` and that `notify_channel_id` matches a channel your Slack MCP connection can post to.

**Task marked `failed`** — Read the `notes` field on that task in `TASKS.json` for Rafa's error message. Fix the underlying issue, reset `status` to `todo`, and re-run.
