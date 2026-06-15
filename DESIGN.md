# ClaudeUsageBar — Design

Tiny native macOS menu-bar app showing live Claude **subscription** usage: headline `%` +
reset countdown in the menu bar, full breakdown in the dropdown. Mirrors Claude Code `/usage`.

## Verified facts (from this machine, 2026-06-15)

- **Endpoint:** `GET https://api.anthropic.com/api/oauth/usage` (internal name `fetchUtilization`).
- **Response:** three meters — `five_hour`, `seven_day`, `seven_day_opus` — each `{ utilization, resets_at }`.
  (Exact field types/units confirmed by the spike, not assumed.)
- **Required headers (first guess, confirmed by spike):**
  - `Authorization: Bearer <oauth-token>`
  - `anthropic-beta: oauth-2025-04-20`
  - `anthropic-version: 2023-06-01`
  - `User-Agent: claude-cli/2.1.x` (may be optional)
- **Auth source:** `claude setup-token` mints a long-lived subscription OAuth token. Stored in our
  *own* Keychain item (`service=ClaudeUsageBar, account=default`). We do **not** read Claude.app's store.
  - Why: this Mac runs Claude Code *inside* `/Applications/Claude.app`, which injects
    `CLAUDE_CODE_OAUTH_TOKEN` at runtime. No `claudeAiOauth` sits in a standalone keychain slot, so
    `setup-token` is the sanctioned way to get a durable token for an external tool.
- **Toolchain:** Swift 6.3.1 (Command Line Tools, no full Xcode), macOS 26 / arm64.
  Build via `swiftc` + manual `.app` bundle (no `.xcodeproj`).

## Architecture — 3 isolated units

1. **TokenStore** — read/write OAuth token in Keychain (`ClaudeUsageBar`/`default`). Seeded from `setup-token`.
2. **UsageClient** — one pure async fn `fetchUsage() -> Usage`; GET endpoint w/ headers; decode 3 meters. No UI; unit-testable.
3. **MenuBarApp** — SwiftUI `MenuBarExtra`; 60s timer → UsageClient → state → label + popover.

Data flow: `timer → UsageClient.fetchUsage() → @State Usage → menu-bar label + popover`.

## UI

- **Label:** e.g. `◐ 47% · 2h` — the *most-constrained* meter (max utilization) + its reset.
  Color: green `<50`, amber `50–80`, red `≥80`.
- **Popover rows:** Session (5h) · Week (all models) · Week (Opus) — each `%` + "resets in Xh/Yd" + mini bar.
- **Footer:** subscription type · last-updated · **Refresh now** · **Re-authenticate** · **Launch at login** · **Quit**.

## Auth / refresh / errors

- Token in Keychain. On `401` → label `⚠︎ auth`; popover **Re-authenticate** re-runs `setup-token`.
- Silent refresh = v2 (only if setup-token returns a refresh token).
- Network fail → keep last good value + ⚠ tooltip; never crash. Log → `~/Library/Logs/ClaudeUsageBar.log`.

## Build / distribution

- `build.sh` → `swiftc` → assemble `ClaudeUsageBar.app` (`Info.plist` `LSUIElement=1`, no Dock icon).
- Launch-at-login via `SMAppService`. Unsigned local build (right-click → Open once).

## Plan

1. **Spike (gate):** `setup-token` → `spike/check-usage.sh` confirms headers + JSON shape. Lock them.
2. Implement `UsageClient` (+ a fixture test off the spike's captured JSON).
3. Implement `TokenStore`.
4. Implement `MenuBarApp` UI.
5. `build.sh` + launch-at-login. Manual verify in menu bar.

## Out of scope v1 (YAGNI)

No `$` cost tracking, history graphs, notifications, multi-account.

## Defaults

Headline = most-constrained meter · poll 60s · thresholds 50/80% · launch-at-login ON · `~/Developer/ClaudeUsageBar/`.
