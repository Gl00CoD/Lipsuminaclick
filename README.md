# Lipsum in a Click

A tiny macOS menu bar app that puts lorem ipsum on your clipboard in one click.

- **Click** the menu bar icon: a fresh random sentence or paragraph is copied to your clipboard (the icon briefly turns into a checkmark).
- **Right-click** (or Control-click) the icon: choose **Sentence** or **Paragraph**. The checkmark shows the current choice, and it's remembered between launches.

Requires macOS 12 or later. No Dock icon.

## Build

On a Mac with Xcode or the Command Line Tools installed:

```bash
./build.sh
open "build/Lipsum in a Click.app"
```

Drag the app into `/Applications` to keep it. To start it automatically, add it under System Settings → General → Login Items.

You can also open `Package.swift` in Xcode to work on it there.

## Download a build

Every push is built by GitHub Actions; the zipped app is attached to the run as the `LipsumInAClick` artifact. It's ad-hoc signed, not notarized, so the first time macOS will block it: right-click the app → **Open**, or run:

```bash
xattr -dr com.apple.quarantine "Lipsum in a Click.app"
```

## Tests

```bash
swift test
```
