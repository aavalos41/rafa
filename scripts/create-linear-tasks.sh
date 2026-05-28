#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# create-linear-tasks.sh
# Bootstrap: reads TASKS.json and creates a Linear issue for every task
# that doesn't already have a linear_issue_id. Writes the new identifiers
# back into TASKS.json so Rafa can sync status updates from that point on.
#
# Run this ONCE when setting up a new project.
#
# Usage:
#   ./scripts/create-linear-tasks.sh
#   ./scripts/create-linear-tasks.sh --dry-run   # Preview without creating
#
# Requires:
#   - LINEAR_API_KEY in .env
#   - team_id and project_id set in rafa-config.json
#   - jq installed
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# ── Load .env ─────────────────────────────────────────────────────────────────
if [ -f "$PROJECT_ROOT/.env" ]; then
  set -a && source "$PROJECT_ROOT/.env" && set +a
fi

# ── Dry run flag ──────────────────────────────────────────────────────────────
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "🔍 DRY RUN — no issues will be created"
fi

# ── Validate dependencies ─────────────────────────────────────────────────────
if [ -z "${LINEAR_API_KEY:-}" ]; then
  echo "❌ LINEAR_API_KEY is not set. Add it to .env"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "❌ jq is required. Install: brew install jq"
  exit 1
fi

TASKS_FILE="$PROJECT_ROOT/TASKS.json"
CONFIG_FILE="$PROJECT_ROOT/rafa-config.json"

if [ ! -f "$TASKS_FILE" ]; then
  echo "❌ TASKS.json not found at $TASKS_FILE"
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ rafa-config.json not found at $CONFIG_FILE"
  exit 1
fi

# ── Read config ───────────────────────────────────────────────────────────────
TEAM_ID=$(jq -r '.linear.team_id // empty' "$CONFIG_FILE")
PROJECT_ID=$(jq -r '.linear.project_id // empty' "$CONFIG_FILE")
TODO_STATE=$(jq -r '.linear.todo_state_name // "Todo"' "$CONFIG_FILE")
GRAPHQL="https://api.linear.app/graphql"
AUTH_HEADER="Authorization: ${LINEAR_API_KEY}"

if [ -z "$TEAM_ID" ]; then
  echo "❌ linear.team_id is not set in rafa-config.json"
  exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Rafa → Linear Bootstrap"
echo "  Team: $TEAM_ID"
if [ -n "$PROJECT_ID" ]; then
  echo "  Project: $PROJECT_ID"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Resolve team UUID from slug ───────────────────────────────────────────────
echo "🔍 Resolving team '$TEAM_ID'..."

TEAMS_RESP=$(curl -s -X POST "$GRAPHQL" \
  -H "Content-Type: application/json" \
  -H "$AUTH_HEADER" \
  -d '{"query": "{ teams { nodes { id key name } } }"}')

TEAM_UUID=$(echo "$TEAMS_RESP" | jq -r \
  --arg key "$TEAM_ID" \
  '.data.teams.nodes[] | select(.key == $key) | .id' | head -1)

if [ -z "$TEAM_UUID" ]; then
  echo "❌ Could not find team with key '$TEAM_ID'."
  AVAILABLE=$(echo "$TEAMS_RESP" | jq -r '.data.teams.nodes[] | "\(.key) (\(.name))"' | tr '\n' ', ')
  echo "   Available teams: $AVAILABLE"
  echo "   Update 'team_id' in rafa-config.json to match one of the above keys."
  exit 1
fi
echo "   ✓ Team UUID: $TEAM_UUID"

# ── Resolve 'Todo' workflow state UUID ───────────────────────────────────────
echo "🔍 Finding workflow state '$TODO_STATE'..."

STATES_RESP=$(curl -s -X POST "$GRAPHQL" \
  -H "Content-Type: application/json" \
  -H "$AUTH_HEADER" \
  -d "{\"query\": \"{ workflowStates(filter: { team: { id: { eq: \\\"$TEAM_UUID\\\" } } }) { nodes { id name } } }\"}")

TODO_STATE_UUID=$(echo "$STATES_RESP" | jq -r \
  --arg name "$TODO_STATE" \
  '.data.workflowStates.nodes[] | select(.name == $name) | .id' | head -1)

if [ -z "$TODO_STATE_UUID" ]; then
  echo "⚠️  Could not find state '$TODO_STATE' — Linear will use its default. Continuing."
fi

# ── Resolve Linear project UUID (if project_id set) ──────────────────────────
PROJECT_UUID=""
if [ -n "$PROJECT_ID" ]; then
  echo "🔍 Resolving project '$PROJECT_ID'..."
  PROJECTS_RESP=$(curl -s -X POST "$GRAPHQL" \
    -H "Content-Type: application/json" \
    -H "$AUTH_HEADER" \
    -d "{\"query\": \"{ team(id: \\\"$TEAM_UUID\\\") { projects { nodes { id name slugId } } } }\"}")

  PROJECT_UUID=$(echo "$PROJECTS_RESP" | jq -r \
    --arg pid "$PROJECT_ID" \
    '.data.team.projects.nodes[] | select(.slugId == $pid or .name == $pid or .id == $pid) | .id' | head -1)

  if [ -z "$PROJECT_UUID" ]; then
    echo "⚠️  Could not match project '$PROJECT_ID' — issues will be created without a project."
    AVAILABLE=$(echo "$PROJECTS_RESP" | jq -r '.data.team.projects.nodes[] | "\(.slugId) — \(.name)"' | tr '\n' '\n   ')
    echo "   Available projects:"
    echo "   $AVAILABLE"
    echo "   Set linear.project_id in rafa-config.json to the slugId or name above."
  else
    echo "   ✓ Project UUID: $PROJECT_UUID"
  fi
fi

# ── Priority mapping: TASKS.json priority → Linear priority ──────────────────
# Linear: 0=none, 1=urgent, 2=high, 3=medium, 4=low
map_priority() {
  local p="${1:-4}"
  case "$p" in
    1) echo 1 ;;  # urgent
    2) echo 2 ;;  # high
    3) echo 3 ;;  # medium
    *) echo 4 ;;  # low
  esac
}

# ── Process tasks ─────────────────────────────────────────────────────────────
TASK_COUNT=$(jq '.tasks | length' "$TASKS_FILE")
CREATED=0
SKIPPED=0

echo ""
echo "Processing $TASK_COUNT tasks..."
echo ""

for ((i=0; i<TASK_COUNT; i++)); do
  TASK=$(jq ".tasks[$i]" "$TASKS_FILE")
  TASK_ID=$(echo "$TASK" | jq -r '.id')
  TASK_TITLE=$(echo "$TASK" | jq -r '.title')
  TASK_DESC=$(echo "$TASK" | jq -r '.description // ""')
  TASK_PRIORITY=$(echo "$TASK" | jq -r '.priority // 4')
  EXISTING_ISSUE_ID=$(echo "$TASK" | jq -r '.linear_issue_id // empty')

  if [ -n "$EXISTING_ISSUE_ID" ]; then
    echo "  ⏭  [$TASK_ID] $TASK_TITLE → already linked ($EXISTING_ISSUE_ID)"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  echo "  ➕ [$TASK_ID] $TASK_TITLE"

  if [ "$DRY_RUN" = true ]; then
    echo "     (dry run — would create Linear issue)"
    continue
  fi

  LINEAR_PRIORITY=$(map_priority "$TASK_PRIORITY")

  # Build the mutation input
  INPUT="{\"teamId\": \"$TEAM_UUID\", \"title\": $(echo "$TASK_TITLE" | jq -Rs .), \"description\": $(echo "$TASK_DESC" | jq -Rs .), \"priority\": $LINEAR_PRIORITY"

  if [ -n "$TODO_STATE_UUID" ]; then
    INPUT="$INPUT, \"stateId\": \"$TODO_STATE_UUID\""
  fi

  if [ -n "$PROJECT_UUID" ]; then
    INPUT="$INPUT, \"projectId\": \"$PROJECT_UUID\""
  fi

  INPUT="$INPUT}"

  MUTATION=$(jq -n --argjson input "$INPUT" \
    '{"query": "mutation IssueCreate($input: IssueCreateInput!) { issueCreate(input: $input) { success issue { id identifier title } } }", "variables": {"input": $input}}')

  RESP=$(curl -s -X POST "$GRAPHQL" \
    -H "Content-Type: application/json" \
    -H "$AUTH_HEADER" \
    -d "$MUTATION")

  SUCCESS=$(echo "$RESP" | jq -r '.data.issueCreate.success // false')

  if [ "$SUCCESS" = "true" ]; then
    LINEAR_IDENTIFIER=$(echo "$RESP" | jq -r '.data.issueCreate.issue.identifier')
    echo "     ✅ Created $LINEAR_IDENTIFIER"

    # Write the linear_issue_id back into TASKS.json
    jq --arg task_id "$TASK_ID" --arg issue_id "$LINEAR_IDENTIFIER" \
      '.tasks |= map(if .id == $task_id then .linear_issue_id = $issue_id else . end)' \
      "$TASKS_FILE" > "$TASKS_FILE.tmp" && mv "$TASKS_FILE.tmp" "$TASKS_FILE"

    CREATED=$((CREATED + 1))
  else
    ERRORS=$(echo "$RESP" | jq -r '.errors[]?.message // "Unknown error"' | head -3)
    echo "     ❌ Failed to create: $ERRORS"
  fi

  # Brief pause to avoid rate limiting
  sleep 0.3
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$DRY_RUN" = true ]; then
  echo "  Dry run complete. Re-run without --dry-run to create issues."
else
  echo "  Done. Created: $CREATED  |  Already linked: $SKIPPED"
  if [ "$CREATED" -gt 0 ]; then
    echo "  TASKS.json updated with Linear issue IDs."
    echo "  Commit the change: git add TASKS.json && git commit -m 'rafa: link Linear issues'"
  fi
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
