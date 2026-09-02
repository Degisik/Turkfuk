# Turkfuk

**Turkish Keylayout for US Keylayouts**

🇹🇷 [Türkçe](README.md) · 🇬🇧 English

The shortest way to type Turkish letters on an ANSI/US keyboard: hold the key, get the
Turkish letter.

```
i → ı      s → ş      g → ğ
c → ç      o → ö      u → ü
```

Hold with Shift for the uppercase forms: `İ Ş Ğ Ç Ö Ü`

## Why

ANSI MacBook keyboards have no Turkish letters. Switching macOS to the Turkish Q layout
moves the punctuation and brackets too, which is painful when you write code. Turkfuk
leaves your layout alone and only adds a press-and-hold gesture to six keys.

## How it works

Keys are observed through a `CGEventTap`. When one of the six letters goes down, the
event is held back:

- **Released before the threshold** → the plain letter is typed.
- **Held past the threshold** → the Turkish letter is typed.
- **Another key pressed before release** → the pending letter is typed immediately,
  then the new key.

That last rule is the important one. Most press-and-hold rule sets drop the pending
letter in this case, so you lose characters when typing fast. Turkfuk never drops it.
To guarantee ordering it does not let the new key through — it posts a marked copy of
it itself, otherwise typing `in` could come out as `ni`.

Letters are emitted with `CGEventKeyboardSetUnicodeString` rather than by simulating
the `⌥` key, so Turkfuk is **independent of the active keyboard layout** — it works on
a plain US layout as well as on Turkish Q Legacy. (An `⌥`-simulation fallback mode
exists for layouts that carry the Turkish letters on the Option layer.)

## Install

### Prebuilt

Download the `.dmg` from the [releases page](https://github.com/Degisik/Turkfuk/releases)
and drag `Turkfuk.app` into `Applications`.

### Homebrew

```bash
brew tap Degisik/turkfuk
brew trust degisik/turkfuk
brew install --cask --no-quarantine turkfuk
```

`brew trust` is required because Homebrew refuses casks from third-party taps by
default. `--no-quarantine` skips the Gatekeeper prompt, since the app is not notarized;
without it you have to allow the app manually (see below).

### From source

```bash
git clone https://github.com/Degisik/Turkfuk.git
cd Turkfuk
./install.sh
```

The installer asks two questions: start at login, and show a menu bar icon. If
Karabiner-Elements has a rule doing the same job, it detects the conflict and offers to
remove it. To remove Turkfuk: `./uninstall.sh`.

## Two steps after installing

**1. Gatekeeper.** The app is not notarized by Apple, so the first launch is blocked.
Go to System Settings → Privacy & Security and press *"Open Anyway"*. Or:

```bash
xattr -dr com.apple.quarantine /Applications/Turkfuk.app
```

**2. Accessibility permission.** System Settings → Privacy & Security → Accessibility →
Turkfuk. Without it no keystrokes can be observed.

## Settings

From the menu bar icon:

| Setting | What it does |
|---|---|
| On / Off | Disables press-and-hold |
| Shortcut | Changes or clears the toggle shortcut (default `⌃⌥⌘T`) |
| Global threshold | Base hold time for every letter (80–300 ms, or a custom value) |
| Per-letter thresholds | A separate time per letter — raise it for keys your finger rests on |
| Start at login | Registers the app with `SMAppService` |

Why per-letter thresholds exist: fingers do not dwell on keys for the same length of
time. `c`, typed with the left middle finger, usually stays down longer than `i`. You
can keep the global threshold low and raise only `c`.

If you turned the menu bar icon off, bring it back with:

```bash
defaults write com.degisik.turkfuk showMenuBarIcon -bool true
```

## Building

No Xcode required — Command Line Tools are enough.

```bash
./Tools/make-cert.sh   # once: stable signing certificate
./build.sh             # native architecture
./build.sh universal   # arm64 + x86_64
./make-dmg.sh beta     # distributable .dmg
```

Output: `dist/Turkfuk.app`

Why `make-cert.sh` matters: macOS ties the accessibility permission to the app's code
signature. An ad-hoc signature changes on every build, so the permission is revoked each
time. A stable certificate keeps the designated requirement constant, so you grant the
permission once. The certificate is not recognised by Apple — it only gives local
permission persistence, it does not satisfy Gatekeeper.

## Requirements

macOS 13 or later · Accessibility permission

## License

MIT
