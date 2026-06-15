# Releasing an official signed + notarized build

Produces `ClaudeUsageBar.dmg` — signed with your Developer ID, notarized by Apple, stapled.
Anyone can download and open it with **no Gatekeeper warning**. No Xcode required (Command Line
Tools + your Apple Developer account are enough).

Do **A** and **B** once; then `./release.sh` any time.

---

## A. Create the "Developer ID Application" certificate  *(no Xcode)*

1. **Make a signing request (CSR).** Open **Keychain Access** →
   menu **Keychain Access ▸ Certificate Assistant ▸ Request a Certificate From a Certificate
   Authority…**
   - *User Email Address:* your Apple ID email
   - *Common Name:* your name
   - *CA Email Address:* leave blank
   - Select **Saved to disk** → Continue → save `CertificateSigningRequest.certSigningRequest`.

2. **Generate the cert.** Go to
   <https://developer.apple.com/account/resources/certificates/list> → **＋** →
   choose **Developer ID Application** → Continue → upload the CSR → Continue → **Download** the
   `.cer`.
   - Requires the **Account Holder** role. (Individual accounts: that's you.)

3. **Install it.** Double-click the downloaded `.cer` → it lands in your **login** keychain and
   pairs with the private key from step 1.

4. **Verify:**
   ```sh
   security find-identity -v -p codesigning
   ```
   You should see `Developer ID Application: <Your Name> (<TEAMID>)`. Note the `TEAMID`.

## B. Create a notarization credential

Pick one. **App-specific password** is simplest.

**Option 1 — app-specific password**
1. <https://appleid.apple.com> → **Sign-In & Security ▸ App-Specific Passwords** → generate one
   (label it e.g. `notarytool`). Copy the `xxxx-xxxx-xxxx-xxxx` value.
2. Store a reusable notary profile (keychain-backed):
   ```sh
   xcrun notarytool store-credentials claude-usage-notary \
     --apple-id "you@example.com" \
     --team-id  "TEAMID" \
     --password "xxxx-xxxx-xxxx-xxxx"
   ```

**Option 2 — App Store Connect API key** (no password to rotate)
1. <https://appstoreconnect.apple.com/access/integrations/api> → generate a key (role: *Developer*).
   Download the `.p8` once; note the **Key ID** and **Issuer ID**.
2. ```sh
   xcrun notarytool store-credentials claude-usage-notary \
     --key "AuthKey_XXXX.p8" --key-id "KEYID" --issuer "ISSUER-UUID"
   ```

> The profile name `claude-usage-notary` is what `release.sh` expects (override with
> `NOTARY_PROFILE=…`).

## C. Build the release

```sh
./release.sh
```
Builds universal (arm64 + x86_64), signs, notarizes, staples, and writes `ClaudeUsageBar.dmg`.
First run takes a few minutes (Apple notary round-trips). The script prints a verification block;
`spctl` should report **accepted / source=Notarized Developer ID**.

## D. Publish

```sh
gh release create v1.0.0 ClaudeUsageBar.dmg \
  -t "Claude Usage 1.0.0" \
  -n "Signed + notarized. Requires a Claude Pro/Max subscription + Claude Code for the token."
```
Then anyone: download `ClaudeUsageBar.dmg` → open → drag to Applications → run `claude setup-token`
+ `seed-token.sh` once for their own token.

## Notes

- **`stapler`** ships with full Xcode. On Command-Line-Tools-only, notarization still succeeds and
  Gatekeeper verifies online on first launch; install Xcode if you want offline stapling.
- **Trademark / naming:** "Claude" is Anthropic's mark. For a public official build, keep the
  "unofficial — not affiliated with Anthropic" notice (see README), and consider a neutral product
  name to avoid confusion.
- **Auto-update** (Sparkle) and a **GitHub Actions** release workflow are possible later; not set up.
