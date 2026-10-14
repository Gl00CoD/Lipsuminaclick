# Releasing a new version

1. Make the change. Run the tests: `swift test`
2. Add a section to `CHANGELOG.md`: `## 1.1.0` followed by bullet points (they become the release notes,
   and the first few lines show in the app's update dialog).
3. Put the new version in `VERSION` (just `1.1.0`).
4. Commit and push to `main`. No tag needed: the change to `VERSION` starts the **Release** workflow
   (`.github/workflows/release.yml`), which creates the `v1.1.0` tag + release itself. (Pushing tags or
   creating releases is blocked from Claude's cloud sessions, so this is deliberate.) If nothing happens:
   Actions → Release → Run workflow.

The workflow then:
- runs the tests and builds the universal app (Apple Silicon + Intel)
- signs `LipsumInAClick.zip` for the in-app updater (only when the signing key secret exists, see below)
- creates the GitHub Release with `LipsumInAClick.zip` and `LipsumInAClick.zip.sig`
- puts this version's changelog plus all earlier versions in the release notes, then **deletes all older
  releases and their tags**, so GitHub only shows the newest one

It takes a few minutes. Progress: the repo's **Actions** tab.

## How the in-app update works

Right-click the menu bar icon → **Update**. The app asks GitHub for the latest release
(`api.github.com/repos/Gl00CoD/Lipsuminaclick/releases/latest`). If it's newer than the running
version, **Install and Restart** downloads the zip, checks its Ed25519 signature against the public key
in `Sources/LipsumInAClick/Updater.swift`, checks the bundle ID and version, swaps the app in place and
relaunches it.

The app has to be somewhere it can replace itself, normally `/Applications`. If it's opened straight
from Downloads, macOS runs it from a read-only copy, and the app asks you to move it first.

## One-click app updates: the signing key (one-time setup)

The app only installs updates signed with the project's private key. Its public half is
`Updater.publicKey` in `Sources/LipsumInAClick/Updater.swift`.

Setup: GitHub repo → **Settings → Secrets and variables → Actions → New repository secret**
- Name: `UPDATE_SIGNING_KEY`
- Value: the contents of the private key file (`lipsuminaclick-update.key`, one line of base64).

Keep a copy of that key file somewhere safe (for example a password manager). If it's lost, generate a
new pair, put the new public key in `Updater.swift`, update the secret, and install the next version
manually once:

```bash
openssl genpkey -algorithm ed25519 -out key.pem
openssl pkey -in key.pem -outform DER | tail -c 32 | base64          # → secret UPDATE_SIGNING_KEY
openssl pkey -in key.pem -pubout -outform DER | tail -c 32 | base64  # → Updater.publicKey
```

The release workflow refuses to sign with a key that doesn't match `Updater.publicKey`.

Without the secret, releases still build. The app then shows a "Download" button for the update
instead of installing it itself.

Note: the updater downloads from the repo's public Releases. If the repo is made **private**, in-app
updates stop working unless that's reworked.
