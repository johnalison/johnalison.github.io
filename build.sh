#!/usr/bin/env bash
# build.sh — Clone/update RoamNotes and generate the static website.
# Run from the NotesWebpage directory, or from anywhere (uses script-relative paths).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTES_DIR="$SCRIPT_DIR/RoamNotes"
PUBLIC_DIR="$SCRIPT_DIR/public"
NOTES_REPO="git@github.com:johnalison/RoamNotes.git"

# ── 1. Clone or update RoamNotes ─────────────────────────────────────────────
echo "==> Syncing RoamNotes..."
if [ -d "$NOTES_DIR/.git" ]; then
    git -C "$NOTES_DIR" pull --ff-only
else
    git clone "$NOTES_REPO" "$NOTES_DIR"
fi

# ── 2. Clean output directory ─────────────────────────────────────────────────
echo "==> Cleaning output directory..."
rm -rf "$PUBLIC_DIR"
mkdir -p "$PUBLIC_DIR"

# ── 3. Run Emacs org-publish ─────────────────────────────────────────────────
echo "==> Running Emacs org-publish..."
emacs --batch \
      --load "$SCRIPT_DIR/publish.el" \
      --eval "(pw/build-all)"

echo ""
echo "==> Build complete. Output in: $PUBLIC_DIR"
