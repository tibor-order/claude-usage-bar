# Agent brief — build & publish the official signed release

**You are Claude, running on the Mac that holds the Developer ID signing certificate.**
Goal: produce a **signed + notarized `ClaudeUsageBar.dmg`** and publish it to the project's GitHub
Releases. The pipeline already exists in this repo (`release.sh`, `build.sh --universal`,
`RELEASE.md`) — you orchestrate, verify, and report.

Repo: <https://github.com/tibor-order/claude-usage-bar>

---

## Safety / constraints (read first)
- **Never print, paste, or pass secrets through chat** — app-specific password, macOS login password,
  or `.p12` password. When a secret is needed, the **human** types it into their own terminal or the
  native macOS prompt. Do not run commands that embed those secrets on their behalf.
- Building & notarizing **does NOT need a Claude subscription or token.** Do **not** run
  `setup-token` / `seed-token.sh` — those are only for *running* the app, not releasing it.
- Don't edit app source unless a build error forces it; if so, keep it minimal and explain.

## Step 0 — Preflight (run, report results)
```sh
swiftc --version | head -1
security find-identity -v -p codesigning | grep "Developer ID Application" || echo "NO DEVELOPER ID CERT"
xcrun notarytool --version
command -v gh >/dev/null && gh auth status 2>&1 | grep -i 'logged in' || echo "gh: not authed"
```
- If **NO DEVELOPER ID CERT**: stop. Either this is the wrong Mac, or the cert+private key aren't
  installed here. The private key only exists where the cert was created — re-downloading the `.cer`
  won't help. See `RELEASE.md` section A to create a fresh one.
- From the cert line `Developer ID Application: <Name> (TEAMID)`, note the **TEAMID** — you'll hand it
  to the human in Step 2.

## Step 1 — Get the code
```sh
git clone https://github.com/tibor-order/claude-usage-bar && cd claude-usage-bar
# (already cloned? cd in and `git pull`)
```

## Step 2 — Notary credential (HUMAN does this once)
Tell the human, in plain terms:
1. Make an app-specific password: <https://appleid.apple.com> → **Sign-In & Security ▸ App-Specific
   Passwords**.
2. In **their own terminal**, run (you supply the TEAMID from Step 0; they supply their Apple ID +
   the password):
   ```sh
   xcrun notarytool store-credentials claude-usage-notary \
     --apple-id "their-apple-id@example.com" --team-id "TEAMID" --password "xxxx-xxxx-xxxx-xxxx"
   ```
Then verify (no secret involved):
```sh
xcrun notarytool history --keychain-profile claude-usage-notary >/dev/null 2>&1 \
  && echo "notary profile OK" || echo "notary profile MISSING/INVALID"
```

## Step 3 — Build → sign → notarize → staple → .dmg
```sh
./release.sh
```
- Takes a few minutes (Apple notary round-trips).
- macOS may pop **"codesign wants to use key …"** → tell the human to click **Always Allow** once.
- If `stapler` is missing (Command-Line-Tools-only) the script says so — that's OK, the app is still
  notarized and Gatekeeper verifies online. Install full Xcode later if you want offline stapling.

## Step 4 — Verify the artifact
```sh
spctl -a -t open --context context:primary-signature -v ClaudeUsageBar.dmg
codesign -dvv ClaudeUsageBar.app 2>&1 | grep -E 'Authority|TeamIdentifier|Runtime'
```
Pass = `accepted`, an Apple **Developer ID** Authority, and the `Runtime` flag present.

## Step 5 — Publish
Pick a version (e.g. `v1.0.0`).
```sh
gh release create v1.0.0 ClaudeUsageBar.dmg \
  -t "Claude Usage 1.0.0" \
  -n "Signed + notarized macOS menu-bar Claude usage meter. Each user runs 'claude setup-token' + seed-token.sh once for their own token. Unofficial; not affiliated with Anthropic."
```
If `gh` isn't authed: have the human `gh auth login`, or upload `ClaudeUsageBar.dmg` manually at
<https://github.com/tibor-order/claude-usage-bar/releases/new>.

## Report back to the human
- The **release URL**, the DMG size, and the `spctl` verdict.
- If anything failed: the exact error and which step.

## Troubleshooting
- `find-identity` empty → cert/private key not on this Mac (see Step 0 note / `RELEASE.md` A).
- notarytool **401/403** → bad/missing notary credential; redo Step 2.
- notarytool status **Invalid** → `xcrun notarytool log <submission-id> --keychain-profile claude-usage-notary`
  shows why (usually a signing/hardened-runtime issue; `release.sh` already passes
  `--options runtime --timestamp`).
- Downloaded DMG still warns → confirm the **dmg itself** was notarized+stapled (release.sh step 7 does this).
