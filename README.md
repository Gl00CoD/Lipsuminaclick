# Lipsum in a Click

A tiny macOS menu bar app that puts lorem ipsum on your clipboard in one click.

- **Click** the menu bar icon: a fresh random sentence or paragraph is copied to your clipboard (the icon briefly turns into a checkmark).
- **Right-click** (or Control-click) the icon: choose **Sentence** or **Paragraph**. The checkmark shows the current choice, and it's remembered between launches.
- **Update** (in the right-click menu): checks GitHub for a newer version and installs it with one click, then restarts the app.

Requires macOS 12 or later. No Dock icon.

## Install

Download `LipsumInAClick.zip` from the [latest release](https://github.com/Gl00CoD/Lipsuminaclick/releases/latest), unzip it, and drag **Lipsum in a Click** into your **Applications** folder (the updater needs it there).

The app is ad-hoc signed, not notarized, so the first time macOS will block it: right-click the app → **Open**, or run:

```bash
xattr -dr com.apple.quarantine "/Applications/Lipsum in a Click.app"
```

To start it automatically, add it under System Settings → General → Login Items.

## Build it yourself

On a Mac with Xcode or the Command Line Tools installed:

```bash
./build.sh
open "build/Lipsum in a Click.app"
```

`UNIVERSAL=1 ./build.sh` builds for both Apple Silicon and Intel (needs Xcode). You can also open `Package.swift` in Xcode to work on it there.

## Releasing

Bump `VERSION`, add a `CHANGELOG.md` section, push to `main`. See [docs/RELEASING.md](docs/RELEASING.md), including the one-time signing key setup for one-click updates.

## Tests

```bash
swift test
```
