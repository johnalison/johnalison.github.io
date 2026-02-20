# NotesWebpage — Project Plan

## Goal

Automatically generate a static website from Emacs org-roam notes hosted in a
private GitHub repository, and publish it via GitHub Pages.

## Source Notes

- **Repo**: `git@github.com:johnalison/RoamNotes.git`
- Notes are **not** edited in place within this project; a fresh clone is pulled
  each build to keep the source untouched.

## High-Level Architecture

```
RoamNotes (private GitHub repo)
        |
        | push to master triggers
        v
GitHub Actions workflow (in this repo)
        |
        | 1. Clone RoamNotes into a working directory
        | 2. Run Emacs in batch mode with org-publish config
        | 3. Collect generated HTML output
        v
GitHub Pages (public static site)
```

## Components to Build

| File | Purpose |
|------|---------|
| `publish.el` | Emacs Lisp config for `org-publish`; defines input/output paths, link handling, stylesheet |
| `build.sh` | Shell script: clone notes, invoke Emacs batch mode, collect output |
| `.github/workflows/build.yml` | GitHub Actions workflow: trigger on push, run build, deploy to Pages |
| `assets/style.css` | (Optional) Custom CSS stylesheet for the generated site |

## Build Steps (detail)

1. **Clone**: `git clone git@github.com:johnalison/RoamNotes.git notes-src`
2. **Publish**: `emacs --batch -l publish.el -f org-publish-all`
3. **Output**: HTML written to `public/` directory
4. **Deploy**: `public/` pushed to `gh-pages` branch (served by GitHub Pages)

## Key Design Decisions

- **Conversion tool**: Emacs `org-publish` — chosen for full org-mode fidelity,
  especially inter-file links (`[[id:...]]` → relative HTML links) and tag support.
- **Hosting**: GitHub Pages — free, integrates with GitHub Actions, zero
  infrastructure to maintain.
- **Automation**: GitHub Actions triggers a rebuild on every push to RoamNotes,
  so the site stays up to date without manual intervention.

## Status

- [ ] Inspect cloned RoamNotes structure (file layout, link types, tags)
- [ ] Write `publish.el` (org-publish configuration)
- [ ] Write `build.sh`
- [ ] Write GitHub Actions workflow
- [ ] Test local build
- [ ] Set up GitHub Pages on target repo
- [ ] Test end-to-end automated deploy
