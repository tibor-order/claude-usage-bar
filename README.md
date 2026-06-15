# ClaudeUsageBar

Native macOS menu-bar app showing live Claude **subscription** usage — the same numbers as
Claude Code's `/usage`. Headline `%` + reset countdown in the menu bar; full breakdown on click.

Menu bar shows e.g. `🟢 14% · 9h` (most-constrained meter + its reset). Click → Session (5h),
Week (all models), Week (Opus), Week (Sonnet), each with a bar; plus pay-as-you-go `extra_usage`.

---

## Requirements

- **macOS 13+** (Apple Silicon or Intel).
- A **Claude Pro/Max subscription** and **Claude Code** (`claude`) installed — used once to mint a token.
- **Xcode Command Line Tools** (to build): `xcode-select --install`.

> This is a power-user tool for people who already use Claude Code. It reads an **undocumented**
> endpoint (`/api/oauth/usage`) reverse-engineered from the Claude Code binary — it may break if
> Anthropic changes it.

## Install — from source (recommended)

```sh
# 1. Get the code
git clone https://github.com/tibor-order/claude-usage-bar && cd claude-usage-bar

# 2. Build + guided setup (checks toolchain, compiles, tells you the token step)
./install.sh

# 3. Mint your own token and store it in Keychain
claude setup-token            # authorize in browser, copy the sk-ant-oat... value
./spike/seed-token.sh         # paste it (input hidden)

# 4. Launch
open ./ClaudeUsageBar.app
```

### Start at login (optional)

```sh
./install-login-item.sh       # relocatable — uses wherever you put the folder
./uninstall.sh                # remove login item + quit
```

**Why from source?** Locally built apps are **not** Gatekeeper-quarantined and need no Apple
signing. The audience already has the dev tools, so this is the least-friction path.

## Distributing a prebuilt `.app` (no Apple Developer account)

You *can* zip `ClaudeUsageBar.app` and hand it to someone, but it is **unsigned / ad-hoc** —
macOS Gatekeeper will block it ("Apple cannot verify…"). The recipient clears it once:

```sh
xattr -dr com.apple.quarantine /path/to/ClaudeUsageBar.app   # or right-click → Open
```

They still need their own token (steps 3–4 above).

- **Warning-free, one-click install** requires an **Apple Developer ID** ($99/yr) + notarization —
  not set up here.
- **Intel + Apple Silicon in one binary:** build universal —
  `swiftc … -target arm64-apple-macos13` and `… -target x86_64-apple-macos13`, then `lipo -create`.
  `build.sh` currently builds for the host arch only.

## Token note

The app reads its own Keychain item (`service=ClaudeUsageBar`, `account=default`).
`claude setup-token` gives a **long-lived** token. If it ever expires the bar shows `⚠︎ auth` —
re-run `setup-token` + `seed-token.sh`. `seed-token.sh` uses `-A` (any app can read the item without
a prompt); drop that flag if you want the macOS Keychain access prompt instead.

## Verify the data path anytime

```sh
./spike/check-usage.sh        # reads the Keychain token, hits the endpoint, prints the meters
```

## Layout

```
Sources/   Models · TokenStore (Keychain) · UsageClient (the GET) · UsageModel (60s poll) · App (MenuBarExtra)
tests/     main.swift — decode test against the captured fixture
spike/     seed-token.sh · check-usage.sh · usage-sample.json
build.sh · install.sh · install-login-item.sh · uninstall.sh · Info.plist · DESIGN.md
```

## Scope (v1)

No `$`-cost history, notifications, or multi-account. See `DESIGN.md` for the full design + verified
endpoint/field facts.

## Official signed build

Maintainers: [RELEASE.md](RELEASE.md) builds a signed + notarized `ClaudeUsageBar.dmg` (Developer ID)
that opens with no Gatekeeper warning. Once published, end users can grab it from **Releases**
instead of building from source.

## Disclaimer

Unofficial — **not affiliated with or endorsed by Anthropic**. "Claude" is a trademark of Anthropic.
This tool reads your own usage via an undocumented endpoint and may break without notice; use at your
own risk.
