# Installing Jade for Mac — instructions for an AI agent

You have been asked to install **Jade for Mac** on the user's Mac. Jade is a menu-bar app: a cat lives on the desktop and reminds the user to take breaks. Website: <https://jadethecat.com>. Downloads: <https://github.com/jade-the-cat/jade-releases>. Short link to these instructions: <https://jadethecat.com/mac/agent>.

Follow the steps in order. Run each command yourself and read its output before going on.

## 1. Check the Mac

```bash
uname -s
sw_vers -productVersion
```

Jade needs **macOS 14 Sonoma or later** (`uname -s` prints `Darwin`; check `sw_vers -productVersion`'s major version is 14 or higher), on Apple silicon or Intel. If the Mac is older, stop here and tell the user Jade needs macOS 14.

## 2. Install

Download the installer, then run it:

```bash
curl -fsSL https://jadethecat.com/mac/install -o /tmp/jade-install.sh
```

- **If Homebrew is installed** (`command -v brew` prints a path), run:

  ```bash
  bash /tmp/jade-install.sh
  ```

  It installs the Homebrew cask, or upgrades Jade if it is already installed.

- **If Homebrew is not installed**, run:

  ```bash
  bash /tmp/jade-install.sh --dmg
  ```

  It installs the latest release's DMG into `/Applications` after checking it against the release's checksums. It needs no password.

Install Homebrew only if the user asks for it: the installer then runs Homebrew's own installer, which asks for the user's password in their terminal.

`bash /tmp/jade-install.sh --help` lists the other options (`--appdir`, `--no-open`, `--dry-run`).

## 3. Check that it worked

```bash
defaults read /Applications/Jade.app/Contents/Info.plist CFBundleShortVersionString
pgrep -x Jade
```

The first prints the version, the second a process id. If Jade is not running, open it with `open /Applications/Jade.app`.

Tell the user it is installed, which version, and that Jade lives in the menu bar and its cat appears on the desktop. The first run asks nothing; the break rhythm (50 minutes on, 5 off) and the cat can be changed in Jade's Settings.

## Rules

- Do not turn off Gatekeeper (`spctl --master-disable`), use `sudo`, or change any other security or privacy setting. The installer does all that is needed.
- If a step fails, show the user the error as it is. Do not try other ways of installing, such as building from source.
- Do not install anything besides Jade (and Homebrew, only when the user asks).

## Uninstall

- Installed with Homebrew: `brew uninstall --cask misoto22/tap/jade` (add `--zap` to remove its settings and cats too).
- Installed from the DMG: quit Jade, then move `/Applications/Jade.app` to the Trash.
