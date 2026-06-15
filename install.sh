#!/usr/bin/env bash
# One-command installer: checks toolchain, builds, guides token setup, launches.
# Works from wherever you put this folder.
set -euo pipefail
cd "$(dirname "$0")"

echo "== ClaudeUsageBar installer =="

# 1. Toolchain
if ! command -v swiftc >/dev/null 2>&1; then
  echo "✗ Swift not found. Install Apple Command Line Tools first:"
  echo "    xcode-select --install"
  exit 1
fi
echo "✓ swiftc: $(swiftc --version | head -1)"

# 2. Claude CLI (needed to mint a token)
if ! command -v claude >/dev/null 2>&1; then
  echo "! 'claude' CLI not found. You need Claude Code + a Pro/Max subscription to mint a token"
  echo "  (or set CLAUDE_CODE_OAUTH_TOKEN / store one in Keychain yourself)."
fi

# 3. Build
echo "== Building =="
./build.sh

# 4. Token
if security find-generic-password -s ClaudeUsageBar -a default -w >/dev/null 2>&1; then
  echo "✓ Keychain token present."
  open ./ClaudeUsageBar.app
  echo "✓ Launched — check your menu bar (top-right)."
else
  cat <<'MSG'

— Almost there. Store your token (one time):

    claude setup-token        # authorize in browser, copy the sk-ant-oat... value
    ./spike/seed-token.sh     # paste it (input hidden)

  Then launch:

    open ./ClaudeUsageBar.app

MSG
fi

echo "Optional — start at login:  ./install-login-item.sh"
