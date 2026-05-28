#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# notify-slack.sh
# Posts a message to Slack — either to a channel (webhook) or as a DM (bot token).
#
# Usage:
#   ./scripts/notify-slack.sh "<message>"
#
# Mode is selected automatically based on what's configured in .env:
#   - If SLACK_BOT_TOKEN + SLACK_NOTIFY_USER_ID are set → sends a DM
#   - If SLACK_WEBHOOK_URL is set → posts to the configured channel
#   - If neither is set → skips silently
#
# Optional env vars for richer formatting (set before calling):
#   RAFA_TASK_ID      — task id, e.g. T001
#   RAFA_TASK_TITLE   — task title
#   RAFA_EVENT        — task_start | task_done | all_complete | error
#   RAFA_PROJECT      — project name (defaults to "Rafa")
#
# Requires:
#   - curl
#   - jq (for DM mode only)
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# ── Load .env ─────────────────────────────────────────────────────────────────
if [ -f "$PROJECT_ROOT/.env" ]; then
  set -a && source "$PROJECT_ROOT/.env" && set +a
fi

# ── Validate message arg ──────────────────────────────────────────────────────
if [ $# -lt 1 ]; then
  echo "Usage: $0 \"<message>\""
  exit 1
fi

MESSAGE="$1"
EVENT="${RAFA_EVENT:-info}"
TASK_ID="${RAFA_TASK_ID:-}"
TASK_TITLE="${RAFA_TASK_TITLE:-}"
PROJECT="${RAFA_PROJECT:-Rafa}"

# ── Pick emoji based on event ─────────────────────────────────────────────────
case "$EVENT" in
  task_start)   ICON=":robot_face:"  ;;
  task_done)    ICON=":white_check_mark:" ;;
  all_complete) ICON=":tada:" ;;
  error)        ICON=":x:" ;;
  *)            ICON=":gear:" ;;
esac

# ── Build message text ────────────────────────────────────────────────────────
if [ -n "$TASK_ID" ] && [ -n "$TASK_TITLE" ]; then
  FULL_TEXT="${ICON} *${PROJECT}* — *[${TASK_ID}]* ${TASK_TITLE}\n${MESSAGE}"
elif [ -n "$TASK_ID" ]; then
  FULL_TEXT="${ICON} *${PROJECT}* — *[${TASK_ID}]*\n${MESSAGE}"
else
  FULL_TEXT="${ICON} *${PROJECT}*\n${MESSAGE}"
fi

# ── Build Slack blocks payload ────────────────────────────────────────────────
build_payload() {
  local text="$1"
  jq -n --arg text "$text" '{
    "blocks": [
      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": $text
        }
      }
    ]
  }'
}

# ── Mode: DM via Bot Token ────────────────────────────────────────────────────
send_dm() {
  local bot_token="${SLACK_BOT_TOKEN}"
  local user_id="${SLACK_NOTIFY_USER_ID}"

  if [ -z "$user_id" ]; then
    echo "   ⚠️  SLACK_NOTIFY_USER_ID is not set — cannot send DM. Set it in .env."
    return 1
  fi

  if ! command -v jq &>/dev/null; then
    echo "   ⚠️  jq is required for DM mode. Install: brew install jq"
    return 1
  fi

  # Step 1: Open a DM conversation with the user
  DM_RESP=$(curl -s -X POST "https://slack.com/api/conversations.open" \
    -H "Authorization: Bearer $bot_token" \
    -H "Content-Type: application/json" \
    -d "{\"users\": \"$user_id\"}")

  DM_OK=$(echo "$DM_RESP" | jq -r '.ok')
  if [ "$DM_OK" != "true" ]; then
    ERROR=$(echo "$DM_RESP" | jq -r '.error // "unknown error"')
    echo "   ⚠️  Could not open DM channel: $ERROR"
    return 1
  fi

  DM_CHANNEL=$(echo "$DM_RESP" | jq -r '.channel.id')

  # Step 2: Post the message
  PAYLOAD=$(build_payload "$FULL_TEXT")
  PAYLOAD=$(echo "$PAYLOAD" | jq --arg ch "$DM_CHANNEL" '. + {"channel": $ch}')

  POST_RESP=$(curl -s -X POST "https://slack.com/api/chat.postMessage" \
    -H "Authorization: Bearer $bot_token" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

  POST_OK=$(echo "$POST_RESP" | jq -r '.ok')
  if [ "$POST_OK" = "true" ]; then
    echo "   ✅ Slack DM sent to $user_id (event: $EVENT)"
  else
    ERROR=$(echo "$POST_RESP" | jq -r '.error // "unknown error"')
    echo "   ⚠️  DM failed: $ERROR"
  fi
}

# ── Mode: Channel via Webhook ─────────────────────────────────────────────────
send_webhook() {
  PAYLOAD=$(build_payload "$FULL_TEXT")

  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$SLACK_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

  if [ "$HTTP_STATUS" = "200" ]; then
    echo "   ✅ Slack webhook sent (event: $EVENT)"
  else
    echo "   ⚠️  Slack webhook returned HTTP $HTTP_STATUS"
  fi
}

# ── Select mode and send ──────────────────────────────────────────────────────
if [ -n "${SLACK_BOT_TOKEN:-}" ]; then
  send_dm
elif [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
  send_webhook
else
  echo "   ⏭  Slack not configured — skipping notification."
fi
