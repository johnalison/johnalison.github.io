# CLAUDE.md — NotesWebpage

Static website generator that publishes `~/RoamNotes` (private org-roam repo) to GitHub Pages at `https://johnalison.github.io`.

## How it works

1. `build.sh` clones/pulls `git@github.com:johnalison/RoamNotes.git` into `RoamNotes/`
2. Emacs runs `publish.el` in batch mode, using `org-publish` to convert all `.org` files to HTML in `public/`
3. GitHub Actions deploys `public/` to the `gh-pages` branch on every push to `master`, and on a daily cron at 4:00 AM UTC

**Never edit `RoamNotes/` directly** — it is a read-only clone that gets overwritten on every build.

## Key files

| File | Purpose |
|------|---------|
| `publish.el` | Core Emacs Lisp build config — org-publish setup, backlinks, day-nav injection |
| `build.sh` | Local build script: pull RoamNotes → clean public/ → run Emacs |
| `assets/style.css` | Custom stylesheet (org's default inline styles are suppressed) |
| `assets/fix-tables.js` | Client-side JS: fixes org separator rows into thead/tbody; adds day-number links on monthly pages; adds `monthly-page` body class for full-width tables |
| `assets/index.html` | Landing page — manually maintained, links to Writing / Notes / Books / Journal |
| `.github/workflows/build.yml` | CI/CD: SSH key setup, Emacs install, build, deploy to gh-pages |
| `.gitignore` | Excludes `RoamNotes/`, `public/`, `.org-id-locations` |

## RoamNotes structure

```
RoamNotes/
  Notes/          — flat directory of ~1300+ topic notes (UUID-linked)
  Journal/        — daily entries, nested by year and month
    2021/         — monthly .org files (e.g. "April 2021.org")
    2022/         — monthly .org files
    2023/         — monthly .org files
    2024/         — monthly .org files + daily subdirs from July 2024
      July 2024.html  — monthly overview
      07-July/    — daily entries: DD-Month-YYYY-DayName.org
    2025/         — daily subdirs for all months
    May2025.html  — some monthly overviews live at Journal/ top level
  Tasks.org, Mail.org, Archive.org, Birthdays.org  — top-level files
```

Year notes (`2020-TIMESTAMP.org` through `2026-TIMESTAMP.org`) live in `Notes/` and serve as annual journal indexes.

## publish.el internals

- **ID resolution**: `org-id-update-id-locations` scans all 1900+ org files so `[[id:UUID]]` links resolve correctly
- **Broken links**: `org-export-with-broken-links 'mark` — dead links render as annotated text instead of aborting the build
- **mu4e links**: `[[mu4e:msgid:...]]` links are stripped (exported as description text or nothing) via a custom `org-link-set-parameters` handler
- **Backlinks index**: hash table UUID → [(source-file . title)], built by scanning all files for `[[id:...]]` patterns; injected before `</body>` on every page
- **Day-nav index**: chronological sorted list of all Journal org files; prev/next links injected above `<h1>` on every journal page
- **Output paths**: use capital-case (`Notes/`, `Journal/`) to match org-generated inter-file links on case-sensitive Linux filesystems
- **`pw/build-all`**: calls `org-publish "rn-all" t` (force-rebuild all) then regenerates `Notes/index.html` and `Journal/index.html`

## fix-tables.js behaviour

Runs on every page (deferred). In order:
1. Detects `| --- |` separator rows and rebuilds tables with proper `<thead>`/`<tbody>`
2. Detects monthly pages by URL pattern and adds `body.monthly-page` class (triggers full-width table CSS)
3. On monthly pages, wraps each first-column day number in a link to the corresponding daily entry at `/Journal/YYYY/MM-Month/DD-Month-YYYY-DayName.html`

Monthly page URL patterns recognised:
- `/Notes/january_2026-TIMESTAMP.html`
- `/Journal/May2025.html`
- `/Journal/2024/July 2024.html`

## Local build and preview

Three skills are available as slash commands:

| Command | What it does |
|---------|-------------|
| `/preview-notes` | Pull latest RoamNotes → start server immediately → kick off background build. Run `/serve-notes` when done to reload. |
| `/build-notes` | Rebuild from existing `RoamNotes/`, wait for completion (~3-5 min). |
| `/serve-notes` | Kill anything on `:8080` and start a fresh server from `public/`. |

Or run manually:

```bash
# Full build (pulls latest RoamNotes first)
./build.sh

# Quick rebuild (skips git pull, uses existing RoamNotes/)
emacs --batch --load publish.el --eval "(pw/build-all)"

# Serve locally
cd public && python3 -m http.server 8080
# → http://localhost:8080
```

## Deployment

- **Trigger**: push to `master`, or daily cron at 4:00 AM UTC, or manual `workflow_dispatch`
- **SSH key**: deploy key for RoamNotes stored as GitHub Actions secret `ROAMNOTES_SSH_KEY` (base64-encoded ed25519 private key)
- **Pages source**: `gh-pages` branch, root `/`

## CSS notes

- `max-width: 740px` content column with `1in` left margin
- Tables default to content width; `body.monthly-page table` expands to `100vw` (full bleed)
- Daily journal pages are detected via `/\/Journal\/` URL pattern in JS (available for future CSS targeting)
- `nav.day-nav`: flex row with `justify-content: space-between` for prev/next links above page title
