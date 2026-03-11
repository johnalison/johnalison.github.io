---
name: serve-notes
description: |
  Start (or restart) the local NotesWebpage preview server on port 8080.
  Kills any existing process on that port, then starts python3 -m http.server
  from public/ in the background.
version: 1.0.0
argument-hint: ""
---

# /serve-notes — Start Local Preview Server

Start (or restart) the local preview server for the NotesWebpage at `http://localhost:8080`.

## Step 1: Kill any existing process on port 8080

Run:
```bash
lsof -ti :8080 | xargs kill -9 2>/dev/null || true
```

Don't report this to the user unless it errors.

## Step 2: Start the server in the background

Run from the `public/` directory:
```bash
cd /Users/johnda/NotesWebpage/public && python3 -m http.server 8080
```

Use `run_in_background: true`. Do NOT wait for it to complete.

## Step 3: Report

Tell the user the server is running at `http://localhost:8080`.
