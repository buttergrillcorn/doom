#!/usr/bin/env bash

# Doom Emacs Literate Configuration Setup Script
# Designed for Termux and other non-Nix environments.

set -e

# --- Configuration ---
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TANGLE_DIR="$REPO_DIR/tangle"
ORG_FILE="$REPO_DIR/config.org"
DOOM_CONFIG_DIR="$HOME/.config/doom"
EMACS_DIR="$HOME/.config/emacs"
DOOM_BIN="$EMACS_DIR/bin/doom"

# --- Helpers ---
info() { echo -e "\e[34m[INFO]\e[0m $1"; }
warn() { echo -e "\e[33m[WARN]\e[0m $1"; }
error() { echo -e "\e[31m[ERROR]\e[0m $1"; }

# --- 1. Dependency Checks ---
info "Checking dependencies..."

# Emacs
if ! command -v emacs >/dev/null 2>&1; then
    warn "Emacs not found."
    if command -v pkg >/dev/null 2>&1; then
        read -p "Termux detected. Install emacs via pkg? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            pkg install emacs
        else
            error "Emacs is required. Aborting."
            exit 1
        fi
    else
        error "Emacs not found. Please install it with your package manager."
        exit 1
    fi
fi

# Doom Emacs Core
if [ ! -d "$EMACS_DIR" ] && [ ! -d "$HOME/.emacs.d" ]; then
    warn "Doom Emacs core not found."
    read -p "Install Doom Emacs using official commands? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Cloning Doom Emacs..."
        git clone --depth 1 https://github.com/doomemacs/doomemacs "$EMACS_DIR"
        info "Installing Doom Emacs (this may take a while)..."
        "$DOOM_BIN" install
    else
        error "Doom Emacs is required. Aborting."
        exit 1
    fi
fi

# --- 2. Tangle config.org ---
info "Tangling $ORG_FILE into $TANGLE_DIR..."
rm -rf "$TANGLE_DIR"
mkdir -p "$TANGLE_DIR"

# Batch tangle using Emacs
# We copy config.org to the tangle directory so relative paths in :tangle resolve correctly.
cp "$ORG_FILE" "$TANGLE_DIR/config.org"
emacs -Q --batch --eval "(require 'ob-tangle)" \
      --eval "(org-babel-tangle-file \"$TANGLE_DIR/config.org\")"
rm "$TANGLE_DIR/config.org"

# --- 3. Deployment ---
if [ -e "$DOOM_CONFIG_DIR" ] || [ -L "$DOOM_CONFIG_DIR" ]; then
    warn "Existing Doom configuration (file, dir, or symlink) found at $DOOM_CONFIG_DIR"
    echo "What would you like to do?"
    echo "b) Backup existing and replace"
    echo "o) Overwrite existing (DELETE)"
    echo "c) Cancel"
    read -p "Selection (b/o/c): " -n 1 -r
    echo
    case $REPLY in
        [Bb])
            BACKUP="$DOOM_CONFIG_DIR.bak.$(date +%Y%m%d_%H%M%S)"
            info "Backing up to $BACKUP"
            mv "$DOOM_CONFIG_DIR" "$BACKUP"
            mkdir -p "$DOOM_CONFIG_DIR"
            ;;
        [Oo])
            info "Removing existing config..."
            rm -rf "$DOOM_CONFIG_DIR"
            mkdir -p "$DOOM_CONFIG_DIR"
            ;;
        *)
            info "Aborting setup."
            exit 0
            ;;
    esac
else
    mkdir -p "$DOOM_CONFIG_DIR"
fi

info "Moving tangled files to $DOOM_CONFIG_DIR..."
mv "$TANGLE_DIR"/* "$DOOM_CONFIG_DIR/"
rm -rf "$TANGLE_DIR"

# --- 4. Post-Deployment ---
info "Running doom sync..."
if [ -f "$DOOM_BIN" ]; then
    "$DOOM_BIN" sync
else
    doom sync
fi

info "Setup complete! Your Doom Emacs is ready."
