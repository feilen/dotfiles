#!/bin/bash
set -e

CWD="$1"
RESULT_FILE="$2"

cd "$CWD"

git difftool --staged --no-prompt || true

echo ""
read -p "Accept this commit? [Y/n] " answer

if [[ -z "$answer" || "${answer,,}" == "y" ]]; then
  echo '{"accept":true}' > "$RESULT_FILE"
else
  read -p "Reason for rejection: " reason
  jq -n --arg reason "$reason" '{"accept":false,"reason":$reason}' > "$RESULT_FILE"
fi
