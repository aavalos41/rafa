#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# afk-rafa.sh
# Runs Rafa in a loop — one task per iteration, fully autonomous.
#
# Usage:
#   ./afk-rafa.sh -n <iterations>
#
# Examples:
#   ./afk-rafa.sh -n 5     # Run up to 5 tasks
#   ./afk-rafa.sh -n 20    # Run up to 20 tasks
#
# Stops early when all eligible tasks are complete.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -f ".env" ]; then
  set -a && source ".env" && set +a
fi

# ── Parse flags ───────────────────────────────────────────────────────────────
N_ITERATIONS=0

while getopts ":n:" opt; do
  case $opt in
    n) N_ITERATIONS="$OPTARG" ;;
    \?) echo "❌ Unknown flag: -$OPTARG  Usage: $0 -n <iterations>"; exit 1 ;;
    :)  echo "❌ Flag -$OPTARG requires a value.  Usage: $0 -n <iterations>"; exit 1 ;;
  esac
done

if [ "$N_ITERATIONS" -le 0 ] 2>/dev/null; then
  echo "❌ Provide a positive number of iterations.  Usage: $0 -n 5"
  exit 1
fi

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Rafa — AFK Mode  (max ${N_ITERATIONS} tasks)"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Loop ──────────────────────────────────────────────────────────────────────
COMPLETED=0

for ((i=1; i<=N_ITERATIONS; i++)); do
  echo "┌─ Task ${i} of ${N_ITERATIONS} ────────────────────────────────────"
  echo "│  $(date '+%Y-%m-%d %H:%M:%S')"
  echo "│"

  RESULT=$(claude -p --dangerously-skip-permissions \
    "@TASKS.json @progress.md @rafa-config.json

You are Rafa, an autonomous coding agent. Complete one task end-to-end with no prompting or confirmation. Follow these steps exactly.

## Step 1 — Find the next eligible task
Read TASKS.json. An eligible task must meet ALL of these:
  - status is 'todo'
  - owner is 'bot' or 'both'
  - every task in its 'dependencies' array has status 'done'

If no eligible task exists, output exactly: <promise>COMPLETE</promise> — then stop.

## Step 2 — Claim the task
Update the task's status to 'in_progress' in TASKS.json.
Commit: git add TASKS.json && git commit -m 'rafa: [<id>] start — <title>'

If rafa-config.json linear.enabled is true and the task has a non-empty linear_issue_id:
  Use the Linear save_issue tool to set the issue state to the value of linear.in_progress_state_name.

If rafa-config.json slack.enabled is true:
  Use the Slack slack_send_message tool to post to channel slack.notify_channel_id:
  ':robot_face: *<project_name>* — *[<id>]* <title>\nStarting: <title>'

## Step 3 — Implement the task
Work only on what the task's 'description' field specifies. One task per run.

### TDD — apply when task has \"tdd\": true OR rafa-config.json tdd.enabled is true
A task-level \"tdd\": false overrides global; \"tdd\": true forces it on even if globally disabled.

When TDD applies, follow red-green-refactor strictly — do not skip steps:

**RED** — Write ONE failing test first:
  - Identify the observable behaviour this task delivers
  - Write a test verifying that behaviour through the public interface only
  - Run the test suite and confirm this test fails
  - Do not write implementation code yet

**GREEN** — Write minimal code to pass the test:
  - Only enough code to make the failing test pass
  - Run the suite and confirm the test passes

**Repeat** RED→GREEN for each additional behaviour (one at a time, never in bulk)

**REFACTOR** — Once all tests pass:
  - Extract duplication, improve readability
  - Run tests after every refactor step

TDD rules: public interfaces only; never refactor while RED; never write all tests upfront.

## Step 4 — Complete the task
Update the task's status to 'done' in TASKS.json.

Append to progress.md:
### [<id>] <title>
- **Date**: $(date '+%Y-%m-%d %H:%M')
- **Status**: done
- **Summary**: <1–3 sentences on what was done>

Commit: git add -A && git commit -m 'rafa: [<id>] done — <title>'

If rafa-config.json linear.enabled is true and the task has a non-empty linear_issue_id:
  Use the Linear save_issue tool to set the issue state to the value of linear.done_state_name.

If rafa-config.json slack.enabled is true:
  Use the Slack slack_send_message tool to post to channel slack.notify_channel_id:
  ':white_check_mark: *<project_name>* — *[<id>]* <title>\nCompleted: <1-line summary>'

## RULES
- One task per run — never start a second.
- Never ask for confirmation or wait for input.
- On unresolvable error: set status to 'failed', add a note in the task's 'notes' field, commit, then output <promise>COMPLETE</promise>.")

  echo "$RESULT" | sed 's/^/│  /'
  COMPLETED=$((COMPLETED + 1))

  if [[ "$RESULT" == *"<promise>COMPLETE</promise>"* ]]; then
    echo "│"
    echo "└─ ✅ All eligible tasks complete after ${i} iteration(s)."
    echo ""
    exit 0
  fi

  echo "└──────────────────────────────────────────────────────────"
  echo ""
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Reached ${N_ITERATIONS}-task cap. ${COMPLETED} task(s) processed."
echo "  Run again with -n to continue."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
