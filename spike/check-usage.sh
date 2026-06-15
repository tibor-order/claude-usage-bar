#!/usr/bin/env bash
# SPIKE: confirm the /api/oauth/usage endpoint works with a setup-token, and dump the
# real JSON shape (field types, units) so we can build UsageClient against reality.
#
# Reads the token from Keychain (ClaudeUsageBar/default) or $CLAUDE_CODE_OAUTH_TOKEN.
# The token is never printed.
set -euo pipefail

SERVICE="ClaudeUsageBar"
ACCOUNT="default"
BASE="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"
URL="$BASE/api/oauth/usage"

TOKEN="${CLAUDE_CODE_OAUTH_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  TOKEN=$(security find-generic-password -s "$SERVICE" -a "$ACCOUNT" -w 2>/dev/null || true)
fi
if [ -z "$TOKEN" ]; then
  echo "No token. Run ./seed-token.sh first (or export CLAUDE_CODE_OAUTH_TOKEN)." >&2
  exit 1
fi

BODY=$(mktemp)
trap 'rm -f "$BODY"' EXIT

STATUS=$(curl -sS -o "$BODY" -w '%{http_code}' "$URL" \
  -H "Authorization: Bearer $TOKEN" \
  -H "anthropic-beta: oauth-2025-04-20" \
  -H "anthropic-version: 2023-06-01" \
  -H "User-Agent: claude-cli/2.1.138 (external; ClaudeUsageBar-spike)" \
  -H "Accept: application/json")

echo "GET $URL"
echo "HTTP $STATUS"
echo "----------------------------------------"

if [ "$STATUS" = "200" ]; then
  python3 - "$BODY" <<'PY'
import json, sys, datetime
d = json.load(open(sys.argv[1]))
print("RAW JSON:")
print(json.dumps(d, indent=2))
print("\nPARSED METERS:")
def human(ts):
    try:
        if isinstance(ts, (int, float)):
            t = datetime.datetime.fromtimestamp(ts/1000 if ts > 1e12 else ts)
        else:
            t = datetime.datetime.fromisoformat(str(ts).replace("Z", "+00:00"))
        delta = t - datetime.datetime.now(t.tzinfo)
        h = int(delta.total_seconds() // 3600); m = int((delta.total_seconds() % 3600) // 60)
        return f"{t}  (in {h}h{m}m)"
    except Exception as e:
        return f"{ts} (unparsed: {e})"
for key in ("five_hour", "seven_day", "seven_day_opus"):
    m = d.get(key)
    if m is None:
        print(f"  {key:16} MISSING"); continue
    util = m.get("utilization", m)
    reset = m.get("resets_at")
    print(f"  {key:16} utilization={util}  resets_at={human(reset)}")
PY
  echo "----------------------------------------"
  echo "SPIKE OK — headers + shape confirmed."
else
  echo "Body (first 800 chars):"
  head -c 800 "$BODY"; echo
  echo "----------------------------------------"
  echo "Non-200. Iterate headers: try removing anthropic-beta, or check token validity."
fi
