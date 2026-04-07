#!/usr/bin/env bash
# build.sh — Clone/update RoamNotes and generate the static website.
# Run from the NotesWebpage directory, or from anywhere (uses script-relative paths).
#
# Usage:
#   ./build.sh          — incremental build (only changed files)
#   ./build.sh --clean  — full rebuild (wipes public/ and timestamp cache)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTES_DIR="$SCRIPT_DIR/RoamNotes"
PUBLIC_DIR="$SCRIPT_DIR/public"
TIMESTAMPS_DIR="$SCRIPT_DIR/.org-timestamps"
NOTES_REPO="git@github.com:johnalison/RoamNotes.git"

CLEAN=false
for arg in "$@"; do
  [[ "$arg" == "--clean" ]] && CLEAN=true
done

# ── 1. Clone or update RoamNotes ─────────────────────────────────────────────
echo "==> Syncing RoamNotes..."
if [ -d "$NOTES_DIR/.git" ]; then
    git -C "$NOTES_DIR" pull --ff-only
else
    git clone "$NOTES_REPO" "$NOTES_DIR"
    CLEAN=true   # first clone → always do a full build
fi

# ── 2. Clean output directory (only when requested) ───────────────────────────
if [ "$CLEAN" = true ]; then
    echo "==> Cleaning output directory and timestamp cache..."
    rm -rf "$PUBLIC_DIR" "$TIMESTAMPS_DIR"
fi
mkdir -p "$PUBLIC_DIR"

# ── 3. Run Emacs org-publish ─────────────────────────────────────────────────
echo "==> Running Emacs org-publish..."
emacs --batch \
      --load "$SCRIPT_DIR/publish.el" \
      --eval "(pw/build-all)"

echo ""
echo "==> Build complete. Output in: $PUBLIC_DIR"
