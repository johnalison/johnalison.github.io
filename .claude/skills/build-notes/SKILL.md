---
name: build-notes
description: |
  Rebuild the NotesWebpage site from the existing RoamNotes/ checkout.
  Runs the Emacs org-publish pipeline in the background and monitors it
  to completion, reporting success or failure.
version: 1.0.0
argument-hint: ""
---

# /build-notes — Rebuild the Website

Rebuild `public/` from `RoamNotes/` using the Emacs org-publish pipeline.
Does NOT pull RoamNotes — use `/preview-notes` for a full pull + build + serve.

## Step 1: Start the build in the background

Run from `/Users/johnda/NotesWebpage/`:
```bash
emacs --batch --load /Users/johnda/NotesWebpage/publish.el --eval "(pw/build-all)"
```

Use `run_in_background: true`. Note the task ID returned.

Tell the user: "Build started (task `<id>`). This takes a few minutes..."

## Step 2: Wait for completion

Use `TaskOutput` with `block: true` and `timeout: 600000` to wait for the build task to finish.

## Step 3: Report outcome

- **Success** (exit code 0): Tell the user the build is complete and suggest running `/serve-notes` to preview, or that the server (if already running) now serves the updated site.
- **Failure** (non-zero exit): Show the last 20 lines of output so the user can diagnose the error.
