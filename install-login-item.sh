#!/usr/bin/env bash
# Make ClaudeUsageBar start at login. Relocatable — uses wherever THIS folder lives.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$DIR/ClaudeUsageBar.app/Contents/MacOS/ClaudeUsageBar"
if [ ! -x "$BIN" ]; then
  echo "App not built yet. Run ./build.sh first." >&2
  exit 1
fi

PLIST="$HOME/Library/LaunchAgents/com.reorder.claudeusagebar.plist"
mkdir -p "$HOME/Library/LaunchAgents"

# Generate the LaunchAgent with the real absolute path on THIS machine.
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.reorder.claudeusagebar</string>
  <key>ProgramArguments</key>
  <array>
    <string>$BIN</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><false/>
  <key>ProcessType</key><string>Interactive</string>
  <key>LimitLoadToSessionType</key><string>Aqua</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST" 2>/dev/null || true
pkill -x ClaudeUsageBar 2>/dev/null || true
launchctl load -w "$PLIST"

echo "Installed login item → $BIN"
