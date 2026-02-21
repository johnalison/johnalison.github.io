;;; publish.el --- Org-publish configuration for NotesWebpage

(require 'org)
(require 'ox-publish)

;;; Paths ------------------------------------------------------------------

(defvar pw/base-dir
  (file-name-directory (or load-file-name buffer-file-name))
  "Root directory of the NotesWebpage project.")

(defvar pw/notes-src-dir
  (expand-file-name "RoamNotes" pw/base-dir)
  "Directory containing the cloned RoamNotes repo.")

(defvar pw/output-dir
  (expand-file-name "public" pw/base-dir)
  "Output directory for the generated website.")

;;; ID resolution ----------------------------------------------------------
;; org-roam uses [[id:UUID]] links. org-publish must know every UUID->file
;; mapping before exporting, otherwise links are left unresolved.

(message "Scanning org files to build ID locations map...")
(setq org-id-locations-file
      (expand-file-name ".org-id-locations" pw/base-dir))
(org-id-update-id-locations
 (directory-files-recursively pw/notes-src-dir "\\.org\\'"))
(message "ID scan complete.")

;;; Broken links -----------------------------------------------------------
;; Some notes may contain [[id:UUID]] links to deleted/missing files.
;; Use 'mark instead of aborting so the build completes and bad links
;; are rendered as plain text with a warning annotation.
(setq org-export-with-broken-links 'mark)

;;; Backlinks index --------------------------------------------------------
;; Build a reverse map: target-UUID -> list of (source-org-path . title)
;; so each page can display which other notes link to it.

(defvar pw/backlinks-index (make-hash-table :test 'equal)
  "Maps a target UUID (uppercase) to a list of (source-path . title).")

(defun pw/file-title (file)
  "Return the #+title of FILE, or its base name if no title is found."
  (with-temp-buffer
    (insert-file-contents file nil 1 2000)
    (if (re-search-forward "^#\\+title:\\s-*\\(.+\\)$" nil t)
        (string-trim (match-string 1))
      (file-name-base file))))

(defun pw/build-backlinks-index ()
  "Scan every org file in the source tree and populate `pw/backlinks-index'."
  (message "Building backlinks index...")
  (clrhash pw/backlinks-index)
  (let ((all-files (directory-files-recursively pw/notes-src-dir "\\.org\\'")))
    (dolist (file all-files)
      (let ((title (pw/file-title file)))
        (with-temp-buffer
          (insert-file-contents file)
          (goto-char (point-min))
          (while (re-search-forward "\\[\\[id:\\([A-Za-z0-9_-]+\\)" nil t)
            (let ((target-id (upcase (match-string 1))))
              ;; Add this file as a backlinker for the target UUID
              (unless (member (cons file title)
                              (gethash target-id pw/backlinks-index))
                (push (cons file title)
                      (gethash target-id pw/backlinks-index)))))))))
  (message "Backlinks index built (%d targets)."
           (hash-table-count pw/backlinks-index)))

(defun pw/org-file-to-html-abs-path (org-file)
  "Return the absolute filesystem path of the published HTML for ORG-FILE."
  (let ((rel (file-relative-name org-file pw/notes-src-dir)))
    (cond
     ;; Notes/foo.org  ->  public/notes/foo.html
     ((string-prefix-p "Notes/" rel)
      (expand-file-name (concat (file-name-base org-file) ".html")
                        (expand-file-name "Notes" pw/output-dir)))
     ;; Journal/path/to/foo.org  ->  public/journal/path/to/foo.html
     ((string-prefix-p "Journal/" rel)
      (let ((journal-rel (substring rel (length "Journal/"))))
        (expand-file-name (concat (file-name-sans-extension journal-rel) ".html")
                          (expand-file-name "Journal" pw/output-dir))))
     ;; Top-level foo.org  ->  public/foo.html
     (t (expand-file-name (concat (file-name-base org-file) ".html")
                          pw/output-dir)))))

(defun pw/html-publish-with-backlinks (plist filename pub-dir)
  "Publish FILENAME to HTML, then inject day-nav and backlinks."
  ;; 1. Normal HTML export
  (org-html-publish-to-html plist filename pub-dir)
  (let* ((out-file (expand-file-name
                    (concat (file-name-base filename) ".html")
                    pub-dir))
         (out-dir (file-name-directory out-file)))
    ;; 2. Prev/next navigation for journal files
    (let ((nav-pair (gethash filename pw/journal-nav-index)))
      (when nav-pair
        (let* ((prev-org (car nav-pair))
               (next-org (cdr nav-pair))
               (prev-url (and prev-org
                              (file-relative-name
                               (pw/org-file-to-html-abs-path prev-org)
                               out-dir)))
               (next-url (and next-org
                              (file-relative-name
                               (pw/org-file-to-html-abs-path next-org)
                               out-dir)))
               (nav-html
                (concat "<nav class=\"day-nav\">\n"
                        (if prev-url
                            (format "  <a href=\"%s\">&#8592; Previous</a>\n" prev-url)
                          "  <span></span>\n")
                        (if next-url
                            (format "  <a href=\"%s\">Next &#8594;</a>\n" next-url)
                          "  <span></span>\n")
                        "</nav>\n")))
          (with-temp-buffer
            (insert-file-contents out-file)
            (goto-char (point-min))
            (when (search-forward "<h1 class=\"title\"" nil t)
              (beginning-of-line)
              (insert nav-html))
            (write-file out-file)))))
    ;; 3. Backlinks
    (let* ((file-id
            (with-temp-buffer
              (insert-file-contents filename nil 1 500)
              (when (re-search-forward "^:ID:\\s-+\\(\\S-+\\)" nil t)
                (upcase (string-trim (match-string 1))))))
           (backlinkers (and file-id (gethash file-id pw/backlinks-index))))
      (when backlinkers
        (let* ((items (mapconcat
                       (lambda (src)
                         (format "  <li><a href=\"%s\">%s</a></li>\n"
                                 (file-relative-name
                                  (pw/org-file-to-html-abs-path (car src))
                                  out-dir)
                                 (cdr src)))
                       backlinkers ""))
               (html (concat "<div class=\"backlinks\">\n"
                             "<h2>Backlinks</h2>\n"
                             "<ul>\n" items "</ul>\n"
                             "</div>\n")))
          (with-temp-buffer
            (insert-file-contents out-file)
            (goto-char (point-max))
            (when (search-backward "</body>" nil t)
              (insert html))
            (write-file out-file)))))))

;;; Journal navigation index -----------------------------------------------
;; Build a sorted list of all journal org files so each page knows its
;; previous and next neighbour (alphabetical path order = chronological).

(defvar pw/journal-nav-index (make-hash-table :test 'equal)
  "Maps journal org-file path to (prev-path . next-path).")

(defun pw/build-journal-nav-index ()
  "Populate `pw/journal-nav-index' with prev/next for every journal file."
  (message "Building journal navigation index...")
  (clrhash pw/journal-nav-index)
  (let* ((journal-dir (expand-file-name "Journal" pw/notes-src-dir))
         (files (sort (directory-files-recursively journal-dir "\\.org\\'")
                      #'string-lessp))
         (vec (vconcat files))
         (len (length vec)))
    (dotimes (i len)
      (let ((f (aref vec i)))
        (puthash f
                 (cons (and (> i 0)        (aref vec (1- i)))
                       (and (< (1+ i) len) (aref vec (1+ i))))
                 pw/journal-nav-index)))
    (message "Journal nav index built (%d entries)." len)))

;; Build both indexes once before any publishing begins
(pw/build-backlinks-index)
(pw/build-journal-nav-index)

;;; HTML head snippet -------------------------------------------------------
;; Using root-relative path so it works at any nesting depth.
;; Assumes the site is served from the domain root (GitHub Pages user page).

(defvar pw/html-head
  (concat "<link rel='stylesheet' type='text/css' href='/style.css'/>\n"
          "<script src='/fix-tables.js' defer='defer'></script>"))

;; Suppress org's built-in inline <style> block so our stylesheet is in full control
(setq org-html-head-include-default-style nil)

;;; Publish project --------------------------------------------------------

(setq org-publish-project-alist
      `(
        ;; Topic notes (Notes/ directory, flat — no recursion needed)
        ("rn-notes"
         :base-directory       ,(expand-file-name "Notes" pw/notes-src-dir)
         :base-extension       "org"
         :publishing-directory ,(expand-file-name "Notes" pw/output-dir)
         :publishing-function  pw/html-publish-with-backlinks
         :recursive            nil
         :with-author          nil
         :with-creator         nil
         :with-toc             nil
         :section-numbers      nil
         :html-head            ,pw/html-head
         :html-postamble       nil)

        ;; Journal entries (nested by year/month)
        ("rn-journal"
         :base-directory       ,(expand-file-name "Journal" pw/notes-src-dir)
         :base-extension       "org"
         :publishing-directory ,(expand-file-name "Journal" pw/output-dir)
         :publishing-function  pw/html-publish-with-backlinks
         :recursive            t
         :with-author          nil
         :with-creator         nil
         :with-toc             nil
         :section-numbers      nil
         :html-head            ,pw/html-head
         :html-postamble       nil)

        ;; Top-level org files (Tasks.org, Mail.org, etc.)
        ("rn-toplevel"
         :base-directory       ,pw/notes-src-dir
         :base-extension       "org"
         :publishing-directory ,pw/output-dir
         :publishing-function  pw/html-publish-with-backlinks
         :recursive            nil
         :with-author          nil
         :with-creator         nil
         :with-toc             nil
         :section-numbers      nil
         :html-head            ,pw/html-head
         :html-postamble       nil)

        ;; Images embedded in journal entries (preserves subdirectory structure)
        ("rn-journal-images"
         :base-directory       ,(expand-file-name "Journal" pw/notes-src-dir)
         :base-extension       "png\\|jpg\\|jpeg\\|gif\\|svg\\|webp"
         :publishing-directory ,(expand-file-name "Journal" pw/output-dir)
         :publishing-function  org-publish-attachment
         :recursive            t)

        ;; Images embedded in notes
        ("rn-notes-images"
         :base-directory       ,(expand-file-name "Notes" pw/notes-src-dir)
         :base-extension       "png\\|jpg\\|jpeg\\|gif\\|svg\\|webp"
         :publishing-directory ,(expand-file-name "Notes" pw/output-dir)
         :publishing-function  org-publish-attachment
         :recursive            t)

        ;; Images at the top level of the repo
        ("rn-toplevel-images"
         :base-directory       ,pw/notes-src-dir
         :base-extension       "png\\|jpg\\|jpeg\\|gif\\|svg\\|webp"
         :publishing-directory ,pw/output-dir
         :publishing-function  org-publish-attachment
         :recursive            nil)

        ;; Static assets (CSS, JS, HTML, etc.)
        ("rn-assets"
         :base-directory       ,(expand-file-name "assets" pw/base-dir)
         :base-extension       "css\\|js\\|ico\\|html"
         :publishing-directory ,pw/output-dir
         :publishing-function  org-publish-attachment
         :recursive            t)

        ;; Master target — publish everything
        ("rn-all" :components ("rn-notes" "rn-journal" "rn-toplevel"
                               "rn-notes-images" "rn-journal-images" "rn-toplevel-images"
                               "rn-assets"))))

;;; Index page generation --------------------------------------------------

(defun pw/write-index (title out-file css-path links-alist)
  "Write a simple HTML index page to OUT-FILE."
  (make-directory (file-name-directory out-file) t)
  (with-temp-buffer
    (insert "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n"
            "<meta charset=\"utf-8\"/>\n"
            "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"/>\n"
            (format "<title>%s</title>\n" title)
            (format "<link rel=\"stylesheet\" type=\"text/css\" href=\"%s\"/>\n" css-path)
            "</head>\n<body>\n<div id=\"content\">\n"
            (format "<h1 class=\"title\">%s</h1>\n" title)
            ;;"<ul>\n"
            (mapconcat (lambda (link)
                         (format "  <h2><a href=\"%s\">%s</a></h2>\n"
                                 (car link) (cdr link)))
                       links-alist "")
            "</div>\n</body>\n</html>\n")
            ;;"</ul>\n</div>\n</body>\n</html>\n")
    (write-file out-file)))

(defun pw/generate-notes-index ()
  "Generate public/notes/index.html — alphabetical list of all notes."
  (message "Generating notes index...")
  (let* ((notes-dir (expand-file-name "Notes" pw/notes-src-dir))
         (files (sort (directory-files notes-dir nil "\\.org\\'") #'string-lessp))
         (links (mapcar (lambda (f)
                          (cons (concat (file-name-base f) ".html")
                                (pw/file-title (expand-file-name f notes-dir))))
                        files)))
    (pw/write-index "Notes"
                    (expand-file-name "Notes/index.html" pw/output-dir)
                    "/style.css"
                    links)))

(defun pw/generate-journal-index ()
  "Generate public/Journal/index.html linking to the per-year notes in Notes/."
  (message "Generating journal index...")
  (let* ((notes-dir (expand-file-name "Notes" pw/notes-src-dir))
         (out-file  (expand-file-name "Journal/index.html" pw/output-dir))
         (year-files (sort (directory-files notes-dir t "^20[0-9]\\{2\\}-[0-9]+\\.org$")
                           (lambda (a b) (string> a b)))))
    (make-directory (file-name-directory out-file) t)
    (with-temp-buffer
      (insert "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n"
              "<meta charset=\"utf-8\"/>\n"
              "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"/>\n"
              "<title>Journal</title>\n"
              "<link rel=\"stylesheet\" type=\"text/css\" href=\"/style.css\"/>\n"
              "</head>\n<body>\n<div id=\"content\">\n"
              "<h1 class=\"title\">Journal</h1>\n"
              (mapconcat (lambda (f)
                           (let* ((base (file-name-base f))
                                  (year (substring base 0 4))
                                  (url  (concat "/Notes/" base ".html")))
                             (format "  <h2><a href=\"%s\">%s</a></h2>\n" url year)))
                         year-files "")
              "</div>\n</body>\n</html>\n")
      (write-file out-file))))

(defun pw/build-all ()
  "Publish everything and generate section index pages."
  (org-publish "rn-all" t)
  (pw/generate-notes-index)
  (pw/generate-journal-index))

(message "publish.el loaded — run (pw/build-all) to build.")
