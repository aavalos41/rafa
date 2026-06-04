#!/bin/bash
# rafa-once.sh — Run from the Rafa folder: bash ./rafa-once.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -f ".env" ]; then set -a && source ".env" && set +a; fi

DATE=$(date '+%Y-%m-%d %H:%M')
PROMPT=$(sed "s/{{DATE}}/$DATE/" rafa-prompt.txt)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Rafa — Single Task Run"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

claude -p --dangerously-skip-permissions "$PROMPT"
