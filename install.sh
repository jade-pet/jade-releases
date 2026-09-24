#!/usr/bin/env bash
# Install Jade for Mac.
#
#   bash -c "$(curl -fsSL https://jadethecat.com/mac/install)"
#
# https://jadethecat.com/mac/install redirects to the copy of this file in
# jade-pet/jade-releases, the public home of Jade's downloads; publish.yml
# puts it there with each release.
#
# Checks that this Mac can run Jade, then installs it with the Homebrew cask,
# installing Homebrew first when it is missing, so `brew upgrade` keeps Jade
# up to date. With --dmg it installs the latest release's DMG instead and
# needs nothing but what macOS ships with.
#
# Options (after `_` when run with bash -c, e.g. `bash -c "$(curl …)" _ --dmg`):
#   --dmg          Install from the release DMG; no Homebrew.
#   --appdir DIR   Where Jade.app goes. Default: /Applications.
#   --no-open      Do not open Jade once it is installed.
#   --dry-run      Print what would be done, change nothing.
#   -h, --help     Show this help.

set -euo pipefail

# The public repository that carries the releases; this one is private.
REPO="jade-pet/jade-releases"
CASK="misoto22/tap/jade"
BUNDLE_ID="io.github.jade-pet.jade"
MINIMUM_MACOS=26
HOMEBREW_INSTALLER="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

method="homebrew"
appdir="/Applications"
open_after=true
dry_run=false

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }

# Runs a command, or only prints it with --dry-run.
run() {
  if $dry_run; then
    printf '    %s\n' "$*"
  else
    "$@"
  fi
}

# Spelled out rather than read from this file, which does not exist on disk
# when the script arrives through curl.
usage() {
  cat <<'USAGE'
Install Jade for Mac.

  bash -c "$(curl -fsSL https://jadethecat.com/mac/install)" _ [options]

  --dmg          Install from the release DMG; no Homebrew.
  --appdir DIR   Where Jade.app goes. Default: /Applications.
  --no-open      Do not open Jade once it is installed.
  --dry-run      Print what would be done, change nothing.
  -h, --help     Show this help.
USAGE
}

parse_options() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --dmg) method="dmg" ;;
      --appdir) [ $# -ge 2 ] || fail "--appdir needs a folder"; appdir="$2"; shift ;;
      --no-open) open_after=false ;;
      --dry-run) dry_run=true ;;
      -h | --help) usage; exit 0 ;;
      *) fail "unknown option: $1 (see --help)" ;;
    esac
    shift
  done
}

# Jade needs macOS 26 or later; it runs on Apple silicon and Intel alike.
check_system() {
  [ "$(uname -s)" = "Darwin" ] || fail "Jade is a Mac app; this is $(uname -s)."
  local version major
  version="$(sw_vers -productVersion)"
  major="${version%%.*}"
  [ "$major" -ge "$MINIMUM_MACOS" ] || fail "Jade needs macOS $MINIMUM_MACOS or later; this Mac has macOS $version."
  command -v curl >/dev/null || fail "curl is missing; it ships with macOS, so this Mac's command line tools look broken."
  say "macOS $version on $(uname -m): supported."
}

# Puts brew on PATH for this script, wherever Homebrew installed it.
load_homebrew() {
  command -v brew >/dev/null && return 0
  local candidate
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$candidate" ]; then
      eval "$("$candidate" shellenv)"
      return 0
    fi
  done
  return 1
}

# Homebrew's own installer asks for the password of an administrator; it reads
# it from the terminal even when this script arrives through a pipe.
ensure_homebrew() {
  if load_homebrew; then
    say "Homebrew $(brew --version | head -1 | awk '{print $2}') found."
    return
  fi
  say "Homebrew is missing; installing it first (it will ask for your password)."
  if $dry_run; then
    # shellcheck disable=SC2016 # printed for the reader, not expanded
    printf '    /bin/bash -c "$(curl -fsSL %s)"\n' "$HOMEBREW_INSTALLER"
    return
  fi
  [ -r /dev/tty ] || fail "Installing Homebrew needs a terminal to ask for your password. Run this in Terminal, or use --dmg."
  /bin/bash -c "$(curl -fsSL "$HOMEBREW_INSTALLER")" </dev/tty
  load_homebrew || fail "Homebrew installed, but brew is not where it should be; open a new Terminal and run this again."
}

install_with_homebrew() {
  ensure_homebrew
  local options=()
  [ "$appdir" = "/Applications" ] || options+=("--appdir=$appdir")
  if $dry_run || ! brew list --cask "$CASK" >/dev/null 2>&1; then
    say "Installing the Jade cask."
    run brew install --cask ${options[@]+"${options[@]}"} "$CASK"
  else
    say "Jade is already installed with Homebrew; upgrading it."
    run brew upgrade --cask ${options[@]+"${options[@]}"} "$CASK"
  fi
}

# The latest release's version, read from where github.com redirects /latest,
# so no API token or JSON parser is needed.
latest_version() {
  local url
  url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest")"
  case "$url" in
    */tag/v*) printf '%s\n' "${url##*/tag/v}" ;;
    *) fail "could not find the latest release of $REPO." ;;
  esac
}

install_from_dmg() {
  local version base work dmg expected actual mount
  version="$(latest_version)"
  base="https://github.com/$REPO/releases/download/v$version"
  say "Installing Jade $version from the release DMG."
  if $dry_run; then
    run curl -fL "$base/Jade-$version.dmg" -o "Jade-$version.dmg"
    run hdiutil attach -nobrowse -readonly "Jade-$version.dmg"
    run ditto "<volume>/Jade.app" "$appdir/Jade.app"
    run xattr -dr com.apple.quarantine "$appdir/Jade.app"
    return
  fi
  work="$(mktemp -d)"
  mount="$work/volume"
  trap 'hdiutil detach -quiet "'"$mount"'" 2>/dev/null || true; rm -rf "'"$work"'"' EXIT
  dmg="$work/Jade-$version.dmg"
  # A progress bar for people; agents and logs get quiet output.
  local progress=(-sS)
  [ -t 2 ] && progress=(--progress-bar)
  curl -fL "${progress[@]}" "$base/Jade-$version.dmg" -o "$dmg"
  curl -fsSL "$base/checksums.txt" -o "$work/checksums.txt"
  expected="$(awk -v name="Jade-$version.dmg" '$2 == name { print $1 }' "$work/checksums.txt")"
  actual="$(shasum -a 256 "$dmg" | awk '{ print $1 }')"
  [ -n "$expected" ] && [ "$expected" = "$actual" ] || fail "the download does not match the release's checksum; not installing it."
  say "Checksum matches the release."
  mkdir -p "$mount"
  hdiutil attach -quiet -nobrowse -readonly -mountpoint "$mount" "$dmg"
  [ -d "$mount/Jade.app" ] || fail "the DMG holds no Jade.app."
  mkdir -p "$appdir"
  [ -w "$appdir" ] || fail "cannot write to $appdir; choose another folder with --appdir."
  if [ -d "$appdir/Jade.app" ]; then
    # Replacing a copy: quit it first so it is not swapped out while it runs.
    osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
    rm -rf "$appdir/Jade.app"
  fi
  ditto "$mount/Jade.app" "$appdir/Jade.app"
  # Releases are signed ad hoc until the project has a Developer ID, and
  # macOS will not open a quarantined app it cannot verify. The Homebrew cask
  # clears the flag the same way.
  xattr -dr com.apple.quarantine "$appdir/Jade.app" 2>/dev/null || true
}

main() {
  parse_options "$@"
  $dry_run && say "Dry run: nothing will be changed."
  check_system
  case "$method" in
    homebrew) install_with_homebrew ;;
    dmg) install_from_dmg ;;
  esac
  if $open_after; then
    run open "$appdir/Jade.app"
  fi
  say "Done. Jade lives in the menu bar; the cat appears on your desktop."
}

main "$@"
