# QuickSnip

A fast screenshot tool for macOS. Press a hotkey, the screen freezes, drag to select, annotate, then copy or save — all without leaving what you're doing.

- Lives in the menu bar (the icon can be hidden)
- Freezes every display first, so menus, tooltips and moving windows are captured as they were
- Drag over any area, or click a window to capture just that window
- Annotate with rectangles, arrows, lines, pen, marker, text and pixelate
- Read the text in any capture, recognized on your Mac, and copy what you need
- Copies or saves at full Retina resolution
- Native macOS look, keyboard-first

Requires macOS 15 or later on Apple silicon.

## Install

Download [**QuickSnip.dmg**](https://github.com/andrewaldasoro/quick-snip/releases/latest/download/QuickSnip.dmg) (or the `.zip` from [Releases](https://github.com/andrewaldasoro/quick-snip/releases)), open it and drag **QuickSnip** to **Applications**.

QuickSnip isn't notarized by Apple, so macOS blocks the first launch:

1. Open QuickSnip once; macOS says it can't be verified. Click **Done**.
2. Open **System Settings › Privacy & Security**, scroll down and click **Open Anyway** next to QuickSnip.

Or, from Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/QuickSnip.app
```

### Verify the download (optional)

Every release is built by GitHub Actions from this repository, with SHA-256 checksums, a signed build-provenance attestation, and a software bill of materials (`QuickSnip.sbom.cdx.json`, CycloneDX) listing every dependency:

```bash
gh attestation verify QuickSnip.dmg --repo andrewaldasoro/quick-snip   # built from this repo by its release workflow
shasum -a 256 -c SHA256SUMS --ignore-missing                          # matches the published checksum
```

### Screen Recording permission

QuickSnip needs **Screen Recording** to capture the screen. On first launch it shows a welcome window:

1. Click **Open System Settings** and turn on **QuickSnip** under **Screen & System Audio Recording**.
2. Click **Quit & Reopen** — macOS only applies the permission after a relaunch.

Images never leave your Mac: no accounts, no uploads. The only network request is the update check (Settings, or **Check for Updates…** in the menu).

## How to use

1. Press **⇧⌘2** (or choose **Capture Area** from the menu bar icon). Every display freezes.
2. Drag to select an area. Drag the edges or corners to resize, drag inside to move it.
3. Annotate with the toolbar or the keys below.
4. Press **Return** to copy, **⌘S** to save, or **Esc** to cancel.

After copying or saving, a thumbnail appears in the bottom-right corner for a few seconds. Click it to open the saved file.

## Shortcut guide

### Anywhere

| Shortcut | Action |
|---|---|
| **⇧⌘2** | Capture area (change it in Settings) |

### Menu bar menu

| Shortcut | Action |
|---|---|
| **⌘,** | Settings… |
| | About QuickSnip (version, open-source notices) |
| | Keyboard Shortcuts… (this guide, with your current capture hotkey) |
| | Check for Updates… |
| **⌘Q** | Quit QuickSnip |

### While capturing

| Shortcut | Action |
|---|---|
| **⌘C** / **Return** / **Enter** | Copy selection to the clipboard |
| **⇧⌘C** | Read the text in the selection (on your Mac; pixelated text stays hidden). It opens in a window: copy all of it, or select part and press ⌘C |
| **⌘S** | Save selection to the save folder |
| **Esc** | Cancel the capture |
| **⌘Z** | Undo |
| **⇧⌘Z** | Redo |
| **Delete** / **⌦** | Delete the selected annotation (click one in move mode first) |
| **?** | Show or hide all shortcuts (**Esc** closes them without cancelling) |

### Tools

Press a tool's key to pick it; press it again to go back to move mode (drag annotations around).

| Key | Tool |
|---|---|
| **R** | Rectangle |
| **A** | Arrow |
| **L** | Line |
| **P** | Pen |
| **M** | Marker |
| **T** | Text |
| **X** | Pixelate |

### Colors

| Key | Color |
|---|---|
| **1** | Red |
| **2** | Orange |
| **3** | Yellow |
| **4** | Green |
| **5** | Blue |
| **6** | Purple |
| **7** | Black |
| **8** | White |

### Text tool

| Action | Result |
|---|---|
| Click | Start typing at that point |
| **Return** or click elsewhere | Place the text |
| **Esc** | Discard the text |

### Mouse

| Action | Result |
|---|---|
| Drag an edge or corner of the selection | Resize the selection |
| Drag inside the selection, tool picked | Draw with that tool (Text: click to type) |
| Click or drag an annotation, no tool picked | Select it (for **Delete**) and move it |
| Drag inside the selection, no tool picked | Move the selection |
| Drag outside the selection, no tool picked | Start a new selection (only before you annotate, so drawings aren't lost) |

## Settings

Open **Settings…** from the menu bar icon, or open QuickSnip again from Finder or Spotlight (the only way back when the menu bar icon is hidden). The **Shortcuts** tab lists every shortcut.

- **Capture area** — record a new global shortcut
- **Save to** — folder for saved screenshots (default: Desktop). Files are named `QuickSnip 2026-10-10 at 14.30.00.png`
- **Format** — PNG or JPEG
- **Show thumbnail after capture**
- **Show menu bar icon**
- **Launch at login**
- **Check for updates automatically** — QuickSnip asks before its first automatic check. Updates are signed, and the check sends nothing about you or your Mac

## Uninstall

1. In **Settings**, turn off **Launch at login**, then quit QuickSnip.
2. Move **QuickSnip** from **Applications** to the Trash.
3. Optionally remove its settings, update cache and Screen Recording entry:

```bash
defaults delete io.github.andrewaldasoro.quicksnip
rm -rf ~/Library/Caches/io.github.andrewaldasoro.quicksnip ~/Library/HTTPStorages/io.github.andrewaldasoro.quicksnip
tccutil reset ScreenCapture io.github.andrewaldasoro.quicksnip
```

Your saved screenshots stay where they are.

## Build from source

Needs full Xcode 27 (the macOS 27 SDK) selected with `xcode-select`.

```bash
git clone git@github.com:andrewaldasoro/quick-snip.git
cd quick-snip
./scripts/run.sh          # build, bundle into build/QuickSnip.app, launch
./scripts/check.sh        # format lint, warnings-as-errors build, tests, coverage
```

See [CLAUDE.md](CLAUDE.md) for architecture and contribution rules, and [plan.md](plan.md) for the roadmap.

## Changes

See [CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE) © 2026 Andrew Aldasoro

QuickSnip is built with [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) and [Sparkle](https://github.com/sparkle-project/Sparkle), both MIT licensed. Their notices ship inside the app: **About QuickSnip** in the menu.
