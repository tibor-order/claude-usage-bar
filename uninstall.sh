#!/usr/bin/env bash
# Remove the login item and quit the app.
set -euo pipefail
PLIST="$HOME/Library/LaunchAgents/com.reorder.claudeusagebar.plist"
launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
pkill -x ClaudeUsageBar 2>/dev/null || true
echo "Removed login item and quit ClaudeUsageBar."
