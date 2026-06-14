#!/usr/bin/env bash
#
# bootstrap.sh — entry point for setting up a fresh macOS machine.
#
# On a brand-new Mac, run:
#   curl -fsSL https://raw.githubusercontent.com/danlechambre/dan-le-dotfiles/main/bootstrap.sh | bash

set -euo pipefail

# ----------------------------------------------------------------------------
# Config
# ----------------------------------------------------------------------------
GITHUB_USER="danlechambre"
DOTFILES_REPO="https://github.com/${GITHUB_USER}/dan-le-dotfiles.git"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/code/dotfiles}"

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m==>\033[0m %s\n' "$*" >&2; exit 1; }

# ----------------------------------------------------------------------------
# 0. Sanity check
# ----------------------------------------------------------------------------
[ "$(uname -s)" = "Darwin" ] || die "This script is for macOS only."

# ----------------------------------------------------------------------------
# 1. Xcode Command Line Tools (provides git, compilers, etc.)
# ----------------------------------------------------------------------------
if ! xcode-select -p >/dev/null 2>&1; then
  log "Installing Xcode Command Line Tools (a GUI prompt will appear)..."
  xcode-select --install || true
  # The installer runs in a separate GUI process, so wait for it to finish.
  until xcode-select -p >/dev/null 2>&1; do
    sleep 5
  done
  log "Command Line Tools installed."
else
  log "Command Line Tools already present."
fi

# ----------------------------------------------------------------------------
# 2. Homebrew
# ----------------------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  log "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Put brew on PATH for this session (Apple Silicon and Intel use different paths).
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
command -v brew >/dev/null 2>&1 || die "Homebrew not on PATH after install."

# ----------------------------------------------------------------------------
# 3. Clone (or update) the dotfiles repo
# ----------------------------------------------------------------------------
if [ ! -d "$DOTFILES_DIR/.git" ]; then
  log "Cloning dotfiles into $DOTFILES_DIR..."
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
  log "Updating existing dotfiles in $DOTFILES_DIR..."
  git -C "$DOTFILES_DIR" pull --ff-only
fi

cd "$DOTFILES_DIR"

# ----------------------------------------------------------------------------
# 4. Hand off to the individual install steps
# ----------------------------------------------------------------------------
if [ -f "$DOTFILES_DIR/Brewfile" ]; then
  log "Installing packages from Brewfile..."
  brew bundle --file="$DOTFILES_DIR/Brewfile"
fi

# Run any additional setup scripts, in alphabetical order.
# Prefix them with numbers (10-symlinks.sh, 20-macos.sh) to control ordering.
# Each script should be idempotent — safe to run more than once.
if [ -d "$DOTFILES_DIR/install" ]; then
  for script in "$DOTFILES_DIR"/install/*.sh; do
    [ -e "$script" ] || continue
    log "Running $(basename "$script")..."
    bash "$script"
  done
fi

log "Done! Restart your shell (or your Mac) to pick up all changes."
