#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# afk-rafa.sh
# Runs Rafa in a fully autonomous loop. Go make coffee.
#
# Usage:
#   ./afk-rafa.sh -n <iterations>
#
# Examples:
#   ./afk-rafa.sh -n 5     # Run up to 5 task iterations
#   ./afk-rafa.sh -n 20    # Run up to 20 task iterations
#
# Rafa will stop early if all eligible tasks are complete.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Load .env ─────────────────────────────────────────────────────────────────
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a && source "$SCRIPT_DIR/.env" && set +a
fi

# ── Parse flags ───────────────────────────────────────────────────────────────
N_ITERATIONS=0

while getopts ":n:" opt; do
  case $opt in
    n)
      N_ITERATIONS="$OPTARG"
      ;;
    \?)
      echo "❌ Unknown flag: -$OPTARG"
      echo "   Usage: $0 -n <iterations>"
      exit 1
      ;;
    :)
      echo "❌ Flag -$OPTARG requires a value."
      echo "   Usage: $0 -n <iterations>"
      exit 1
      ;;
  esac
done

# Validate -n was provided and is a positive integer
if [ "$N_ITERATIONS" -le 0 ] 2>/dev/null; then
  echo "❌ You must provide a positive number of iterations."
  echo "   Usage: $0 -n <iterations>"
  echo "   Example: $0 -n 5"
  exit 1
fi

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Rafa — AFK Mode  (max ${N_ITERATIONS} iterations)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Loop ──────────────────────────────────────────────────────────────────────
COMPLETED=0

for ((i=1; i<=N_ITERATIONS; i++)); do
  echo "┌─ Iteration ${i} of ${N_ITERATIONS} ─────────────────────────────────"
  echo "│  $(date '+%Y-%m-%d %H:%M:%S')"
  echo "│"

  RESULT=$(claude --permission-mode acceptEdits -p \
    "@TASKS.json @progress.md @rafa-config.json

You are Rafa, an autonomous task agent. Follow these steps EXACTLY and in order.

## Step 1 — Read the task list
Read TASKS.json carefully. Understand every task's id, title, status, owner, and dependencies.

## Step 2 — Find the next eligible task
An eligible task meets ALL of these criteria:
  - status is 'todo' (skip: pending, in_progress, done, failed)
  - owner is 'bot' or 'both' (skip: human)
  - Every task listed in its 'dependencies' array has status 'done'

If NO eligible task exists, output exactly: <promise>COMPLETE</promise>
Then stop — do not take any further action.

## Step 3 — Mark the task as in_progress
Before doing any work, update the task's status to 'in_progress' in TASKS.json and commit:
  git add TASKS.json && git commit -m 'rafa: [TASK_ID] start — TASK_TITLE'

If Slack is enabled in rafa-config.json, run:
  RAFA_EVENT=task_start RAFA_TASK_ID=<id> RAFA_TASK_TITLE='<title>' RAFA_PROJECT='<project_name>' ./scripts/notify-slack.sh 'Starting task: <title>'

If the task has a linear_issue_id and Linear is enabled in rafa-config.json, run:
  ./scripts/update-linear.sh <linear_issue_id> '<value of linear.in_progress_state_name from rafa-config.json>'

## Step 4 — Implement the task
Work only on what is described in the task's 'description' field.
Do not start any other task. Stay focused on a single, complete unit of work.

## Step 5 — Mark the task as done
After completing the work, update the task's status to 'done' in TASKS.json.

## Step 6 — Update progress.md
Append a new entry to progress.md in this format:

### [TASK_ID] TASK_TITLE
- **Date**: $(date '+%Y-%m-%d %H:%M')
- **Status**: done
- **Summary**: <1–3 sentence summary of what was done>

## Step 7 — Commit all changes
  git add -A && git commit -m 'rafa: [TASK_ID] done — TASK_TITLE'

## Step 8 — External notifications (if configured in rafa-config.json)
If Slack is enabled:
  RAFA_EVENT=task_done RAFA_TASK_ID=<id> RAFA_TASK_TITLE='<title>' RAFA_PROJECT='<project_name>' ./scripts/notify-slack.sh 'Completed: <1-line summary>'

If linear_issue_id is set and Linear is enabled:
  ./scripts/update-linear.sh <linear_issue_id> '<value of linear.done_state_name from rafa-config.json>'

## IMPORTANT RULES
- ONLY work on ONE task per run.
- Do not modify tasks other than the one you are implementing.
- If you encounter an error you cannot resolve, set the task status to 'failed', add a note in its 'notes' field, commit, and output <promise>COMPLETE</promise>.
- Always check rafa-config.json to know which integrations are enabled before running scripts.")

  echo "$RESULT" | sed 's/^/│  /'

  COMPLETED=$((COMPLETED + 1))

  if [[ "$RESULT" == *"<promise>COMPLETE</promise>"* ]]; then
    echo "│"
    echo "└─ ✅ All eligible tasks complete after ${i} iteration(s)."
    echo ""

    # Final Slack notification
    if [ -f "$SCRIPT_DIR/.env" ]; then set -a && source "$SCRIPT_DIR/.env" && set +a; fi
    if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
      RAFA_EVENT=all_complete RAFA_PROJECT="$(basename "$SCRIPT_DIR")" \
        "$SCRIPT_DIR/scripts/notify-slack.sh" \
        "All eligible tasks are complete after ${i} iteration(s). Check progress.md for the full log." || true
    fi

    exit 0
  fi

  echo "└─────────────────────────────────────────────────────────"
  echo ""
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Rafa finished ${N_ITERATIONS} iteration(s). Run again with -n to continue."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Slack summary at iteration cap
if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
  RAFA_EVENT=info RAFA_PROJECT="$(basename "$SCRIPT_DIR")" \
    "$SCRIPT_DIR/scripts/notify-slack.sh" \
    "Reached the ${N_ITERATIONS}-iteration cap. ${COMPLETED} task(s) processed. More tasks may remain." || true
fi
