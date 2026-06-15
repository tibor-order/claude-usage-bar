#!/usr/bin/env bash
# Store a Claude OAuth token in the login Keychain (service=ClaudeUsageBar, account=default).
# Token never appears on screen, in args, or in shell history.
#
# Get the token first:   claude setup-token   (authorize in browser, copy the sk-ant-oat... value)
set -euo pipefail

SERVICE="ClaudeUsageBar"
ACCOUNT="default"

printf 'Paste your Claude OAuth token (input hidden), then Enter: '
read -r -s TOKEN
printf '\n'

if [ -z "${TOKEN:-}" ]; then
  echo "No token entered. Aborting." >&2
  exit 1
fi

# -U updates the item if it already exists.
# -A lets any app on this Mac read it without a per-launch prompt. Chosen because the
#    app is ad-hoc signed and re-signed on every rebuild (so a code-signature ACL would
#    break each build). Tradeoff: other local apps could read this token. For a personal
#    usage-meter token this is acceptable; drop -A if you want the macOS access prompt.
security add-generic-password -U -A -s "$SERVICE" -a "$ACCOUNT" -w "$TOKEN" 2>/dev/null

# Confirm without revealing the secret.
LEN=$(security find-generic-password -s "$SERVICE" -a "$ACCOUNT" -w 2>/dev/null | wc -c | tr -d ' ')
echo "Stored in Keychain ($SERVICE/$ACCOUNT). Token length: $LEN bytes."
echo "Next: ./check-usage.sh"
