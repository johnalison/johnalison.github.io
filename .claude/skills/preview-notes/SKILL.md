---
name: preview-notes
description: |
  Full local preview pipeline: pull latest RoamNotes, start the server
  immediately (serving the previous build while the new one runs), then
  kick off the Emacs build in the background. Fire-and-forget — returns
  as soon as the build is launched so the user can keep working.
version: 1.0.0
argument-hint: ""
---

# /preview-notes — Pull, Build, and Serve

Full pipeline: pull the latest RoamNotes, start the local server, and kick
off a fresh build in the background. Returns immediately after launching the
build — run `/serve-notes` once the build finishes to reload the server with
new content.

## Step 1: Pull latest RoamNotes

Run synchronously (wait for it):
```bash
git -C /Users/johnda/NotesWebpage/RoamNotes pull --ff-only
```

Report how many commits were pulled (or "Already up to date.").

## Step 2: Start the server immediately

Kill any existing process on port 8080:
```bash
lsof -ti :8080 | xargs kill -9 2>/dev/null || true
```

Then start the server in the background from `public/`:
```bash
cd /Users/johnda/NotesWebpage/public && python3 -m http.server 8080
```

Use `run_in_background: true`. Tell the user the server is live at
`http://localhost:8080` (serving the previous build for now).

## Step 3: Launch the build in the background (fire and forget)

Run in the background — do NOT wait for it:
```bash
emacs --batch --load /Users/johnda/NotesWebpage/publish.el --eval "(pw/build-all)"
```

Use `run_in_background: true`. Note the task ID.

## Step 4: Report and return

Tell the user:
- Server is running at `http://localhost:8080` (showing previous build)
- Build is running in background (task `<id>`) — takes ~3-5 minutes
- When the build finishes, run `/serve-notes` to reload the server with fresh content
