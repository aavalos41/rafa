#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# update-linear.sh
# Updates a Linear issue's workflow state.
#
# Usage:
#   ./scripts/update-linear.sh <issue_identifier> <state_name>
#
# Examples:
#   ./scripts/update-linear.sh ENG-42 "In Progress"
#   ./scripts/update-linear.sh ENG-42 "Done"
#
# Requires:
#   - LINEAR_API_KEY env variable (or .env file in project root)
#   - jq installed (brew install jq / apt install jq)
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Load .env if present ──────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
if [ -f "$PROJECT_ROOT/.env" ]; then
  # shellcheck disable=SC1091
  set -a && source "$PROJECT_ROOT/.env" && set +a
fi

# ── Validate args & env ───────────────────────────────────────────────────────
if [ $# -lt 2 ]; then
  echo "❌ Usage: $0 <issue_identifier> <state_name>"
  echo "   Example: $0 ENG-42 Done"
  exit 1
fi

ISSUE_ID="$1"
TARGET_STATE="$2"

if [ -z "${LINEAR_API_KEY:-}" ]; then
  echo "❌ LINEAR_API_KEY is not set. Add it to your .env file."
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "❌ jq is not installed. Install it with: brew install jq (or apt install jq)"
  exit 1
fi

GRAPHQL="https://api.linear.app/graphql"
AUTH_HEADER="Authorization: ${LINEAR_API_KEY}"

# ── Step 1: Resolve issue UUID from identifier (e.g. ENG-42) ─────────────────
echo "🔍 Looking up issue ${ISSUE_ID}..."

ISSUE_QUERY=$(cat <<EOF
{
  "query": "query { issue(id: \"${ISSUE_ID}\") { id title team { id } } }"
}
EOF
)

ISSUE_RESP=$(curl -s -X POST "$GRAPHQL" \
  -H "Content-Type: application/json" \
  -H "$AUTH_HEADER" \
  -d "$ISSUE_QUERY")

ISSUE_UUID=$(echo "$ISSUE_RESP" | jq -r '.data.issue.id // empty')
TEAM_UUID=$(echo "$ISSUE_RESP" | jq -r '.data.issue.team.id // empty')

if [ -z "$ISSUE_UUID" ]; then
  echo "❌ Could not resolve issue '${ISSUE_ID}'. Check the identifier and your API key."
  echo "   Response: $ISSUE_RESP"
  exit 1
fi

echo "   ✓ Issue UUID: $ISSUE_UUID"

# ── Step 2: Find the workflow state UUID by name ──────────────────────────────
echo "🔍 Finding workflow state '${TARGET_STATE}' for team..."

STATES_QUERY=$(cat <<EOF
{
  "query": "query { workflowStates(filter: { team: { id: { eq: \"${TEAM_UUID}\" } } }) { nodes { id name } } }"
}
EOF
)

STATES_RESP=$(curl -s -X POST "$GRAPHQL" \
  -H "Content-Type: application/json" \
  -H "$AUTH_HEADER" \
  -d "$STATES_QUERY")

STATE_UUID=$(echo "$STATES_RESP" | jq -r \
  --arg name "$TARGET_STATE" \
  '.data.workflowStates.nodes[] | select(.name == $name) | .id' | head -1)

if [ -z "$STATE_UUID" ]; then
  echo "❌ Could not find workflow state named '${TARGET_STATE}'."
  AVAILABLE=$(echo "$STATES_RESP" | jq -r '.data.workflowStates.nodes[].name' | tr '\n' ', ')
  echo "   Available states: $AVAILABLE"
  echo "   Update 'done_state_name' in rafa-config.json to match one of the above."
  exit 1
fi

echo "   ✓ State UUID: $STATE_UUID"

# ── Step 3: Update the issue ──────────────────────────────────────────────────
echo "✏️  Updating issue ${ISSUE_ID} → ${TARGET_STATE}..."

UPDATE_MUTATION=$(cat <<EOF
{
  "query": "mutation { issueUpdate(id: \"${ISSUE_UUID}\", input: { stateId: \"${STATE_UUID}\" }) { success issue { identifier title state { name } } } }"
}
EOF
)

UPDATE_RESP=$(curl -s -X POST "$GRAPHQL" \
  -H "Content-Type: application/json" \
  -H "$AUTH_HEADER" \
  -d "$UPDATE_MUTATION")

SUCCESS=$(echo "$UPDATE_RESP" | jq -r '.data.issueUpdate.success // false')

if [ "$SUCCESS" = "true" ]; then
  NEW_STATE=$(echo "$UPDATE_RESP" | jq -r '.data.issueUpdate.issue.state.name')
  echo "   ✅ ${ISSUE_ID} is now: ${NEW_STATE}"
else
  echo "   ❌ Update failed. Response: $UPDATE_RESP"
  exit 1
fi
