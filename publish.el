;; package --- Summary:
;; org-publish.el --- publish related org-mode files as a website
;;; Commentary:
;;;
;;; How to run this:
;;; * eval the buffer
;;; * M-x site-publish
;;;

(require 'citeproc)
(require 'find-lisp)
(require 'htmlize)
(require 'oc-csl)
(require 'org)
(require 'org-roam)
(require 'org-roam-export)
(require 'ox)
(require 'ox-html)
(require 'ox-publish)
(require 'ox-rss)
(require 'seq)

;;; org-babel configuration

;;; Functions:
;;;; http://xahlee.info/emacs/emacs/elisp_read_file_content.html
(defun get-string-from-file (filePath)
  "Return file content as string from FILEPATH."
  (with-temp-buffer
    (insert-file-contents filePath)
    (buffer-string)))

(defun get-bib-files-from-path (dir)
  "Return a list of full paths for all .bib files in DIR."
  (let ((expanded-dir (file-name-as-directory (expand-file-name dir))))
    (directory-files expanded-dir t "\\.bib$")))

(defun patch-string-with-path (str filePath n)
  "Patch a STR with FILEPATH and do so N times."
  (apply 'format str (make-list n filePath)))

(defun patch-list-with-prefix (prefix strings)
  "Prepend PREFIX to every string in STRINGS."
  (mapcar (lambda (s) (concat prefix s)) strings))

;;;; Taken from:
;;;; https://commonplace.doubleloop.net/publish.el
(defun notes/generate-backlinks (backend backlinks)
  "Insert BACKLINKS into org file before parsing it, targets BACKEND.
One entry per source note, regardless of how many links it contains."
  (when (org-roam-node-at-point)
    (goto-char (point-max))
    ;; Add a new header for the links
    (insert "* Backlinks:\n")
    (dolist (backlink (seq-uniq backlinks
                                (lambda (a b)
                                  (string= (org-roam-node-file (org-roam-backlink-source-node a))
                                           (org-roam-node-file (org-roam-backlink-source-node b))))))
      (let* ((source-node (org-roam-backlink-source-node backlink))
             (point (org-roam-backlink-point backlink)))
        (insert
         (format "- [[./%s][%s]]\n"
                 (file-name-nondirectory (org-roam-node-file source-node))
                 (org-roam-node-title source-node)))))))

(defun notes/collect-backlinks (backend)
  "Generate backlinks if they exist at all, targets BACKEND."
  (when (org-roam-node-at-point)
    (goto-char (point-max))
    (let* ((backlinks (org-roam-backlinks-get (org-roam-node-at-point))))
      (cond ((if (eq nil backlinks) t nil)
             (message "Ignoring backlink generation..."))
            (t (notes/generate-backlinks backend backlinks))))))

(defun notes/add-extra-sections (backend)
  "Insert extra sections on a note BACKEND before being published."
  (when (org-roam-node-at-point)
    (save-excursion
      (goto-char (point-max))
      (insert "\n* References:\n#+print_bibliography:\n")
      (notes/collect-backlinks backend))))

;;; Listing helpers

(defun schonfinkel/get-org-title (filepath)
  "Extract #+TITLE: from FILEPATH, case-insensitive."
  (with-temp-buffer
    (insert-file-contents filepath)
    (goto-char (point-min))
    (if (re-search-forward "^#\\+TITLE:\s*\\(.*\\)$" nil t)
        (string-trim-right (match-string 1))
      (file-name-base filepath))))

(defun schonfinkel/extract-date (filename nchars)
  "Extract YYYY-MM-DD date from first NCHARS of FILENAME base."
  (let* ((base (file-name-base filename))
         (s (substring base 0 (min nchars (length base)))))
    (format "%s-%s-%s" (substring s 0 4) (substring s 4 6) (substring s 6 8))))

(defconst schonfinkel/page-size 20
  "Maximum number of entries shown per index page.")

(defvar schonfinkel/entries-cache nil
  "Memoized `schonfinkel/collect-entries' results, keyed by DIR.
Entries cannot change within a single publish run, so each directory
is scanned only once.  Reset on every `publish.el' load.")

(setq schonfinkel/entries-cache (make-hash-table :test #'equal))

(defun schonfinkel/collect-entries (dir nchars exclude-regex)
  "Scan DIR (relative to root-dir) for .org files and return sorted entries.
NCHARS is the date prefix length in the filename.  EXCLUDE-REGEX is a
regexp string; files whose names match it are skipped.  Entries are
\(DATE TITLE FILENAME) lists sorted anti-chronologically by DATE."
  (or (gethash dir schonfinkel/entries-cache)
      (let* ((full-dir (concat root-dir dir))
             (files (directory-files full-dir t "\\.org$"))
             (entries '()))
        (dolist (f files)
          (let ((fname (file-name-nondirectory f)))
            (unless (or (string-prefix-p "." fname)
                        (and exclude-regex
                             (string-match-p exclude-regex fname)))
              (let ((title (schonfinkel/get-org-title f))
                    (date  (schonfinkel/extract-date fname nchars)))
                (push (list date title fname) entries)))))
        (let ((sorted (sort entries (lambda (a b) (string> (car a) (car b))))))
          (puthash dir sorted schonfinkel/entries-cache)
          sorted))))

(defun schonfinkel/index-page-count (dir nchars exclude-regex)
  "Return how many pages of `schonfinkel/page-size' DIR's entries need."
  (let ((n (length (schonfinkel/collect-entries dir nchars exclude-regex))))
    (max 1 (ceiling (/ n (float schonfinkel/page-size))))))

(defun schonfinkel/format-stub (entry dir)
  "Return the HTML stub markup for ENTRY, linking into DIR."
  (let ((date  (nth 0 entry))
        (title (nth 1 entry))
        (file  (file-name-sans-extension (nth 2 entry))))
    (format
     "\n    <div class=\"stub\">\n      <h2>\n        <a href=\"./%s%s.html\"> %s </a>\n      </h2>\n      <small>%s</small>\n    </div>"
     dir file title date)))

(defun schonfinkel/page-url (base page)
  "Return the URL of index PAGE for the section whose first page is BASE."
  (if (= page 1)
      (format "./%s.html" base)
    (format "./%s-%d.html" base page)))

(defun schonfinkel/pagination-nav (base page total-pages)
  "Return an HTML pagination bar for BASE, currently on PAGE of TOTAL-PAGES.
Minimal pager: previous/next arrows, the first and last page numbers
and the current page when it lies in between, with an ellipsis
wherever pages are hidden.  nil when everything fits on a single page."
  (when (> total-pages 1)
    (let* ((prev (when (> page 1) (schonfinkel/page-url base (1- page))))
           (next (when (< page total-pages) (schonfinkel/page-url base (1+ page))))
           (shown (if (<= total-pages 3)
                      (number-sequence 1 total-pages)
                    (sort (delq nil
                                (list 1
                                      (unless (or (= page 1) (= page total-pages)) page)
                                      total-pages))
                          #'<)))
           (parts (list (car shown)))
           (last-shown (car shown)))
      (dolist (p (cdr shown))
        (when (> (- p last-shown) 1)
          (push nil parts))                 ; nil renders as the ellipsis gap
        (push p parts)
        (setq last-shown p))
      (format
       "\n<nav class=\"pagination\" aria-label=\"Pagination\">%s%s%s</nav>"
       (if prev
           (format "<a class=\"arrow\" href=\"%s\" rel=\"prev\">&laquo;</a>" prev)
         "<span class=\"arrow disabled\">&laquo;</span>")
       (mapconcat
        (lambda (p)
          (cond
           ((null p) "<span class=\"gap\">&hellip;</span>")
           ((= p page)
            (format "<span class=\"current\" aria-current=\"page\">%d</span>" p))
           (t (format "<a href=\"%s\">%d</a>" (schonfinkel/page-url base p) p))))
        (nreverse parts) "")
       (if next
           (format "<a class=\"arrow\" href=\"%s\" rel=\"next\">&raquo;</a>" next)
         "<span class=\"arrow disabled\">&raquo;</span>")))))

(defun schonfinkel/generate-index (dir nchars exclude-regex &optional page)
  "Scan DIR (relative to root-dir) for .org files and return paginated HTML.
NCHARS is the date prefix length in the filename.  EXCLUDE-REGEX is a
regexp string; files whose names match it are skipped.  Results are
sorted anti-chronologically by extracted date and shown PAGE at a time
\(default 1), with at most `schonfinkel/page-size' entries per page and
a pagination bar when more than one page is needed."
  (let* ((entries (schonfinkel/collect-entries dir nchars exclude-regex))
         (page (or page 1))
         (base (string-trim-right dir "/"))
         (start (* (1- page) schonfinkel/page-size))
         (end (min (length entries) (+ start schonfinkel/page-size)))
         (page-entries (when (< start end) (seq-subseq entries start end))))
    (concat
     (mapconcat (lambda (e) (schonfinkel/format-stub e dir)) page-entries "")
     (schonfinkel/pagination-nav base page
                                 (schonfinkel/index-page-count dir nchars exclude-regex)))))

(defun schonfinkel/generate-blog-list (&optional page)
  "Return an HTML list of blog posts, PAGE at a time."
  (schonfinkel/generate-index "blog/" 8 "draft\\|rss" page))

(defun schonfinkel/generate-notes-list (&optional page)
  "Return an HTML list of org-roam notes, PAGE at a time."
  (schonfinkel/generate-index "notes/" 14 nil page))

(defun schonfinkel/write-index-pages (dir nchars exclude-regex base title generator)
  "Write BASE-2.org through BASE-N.org when DIR needs more than one page.
NCHARS and EXCLUDE-REGEX are as in `schonfinkel/collect-entries'.
TITLE is used in each page's #+TITLE and GENERATOR is the elisp
function, called with the page number, that fills the page body.
Returns the list of files written."
  (let* ((total-pages (schonfinkel/index-page-count dir nchars exclude-regex))
         (files '()))
    (dolist (page (number-sequence 2 total-pages))
      (let ((file (concat root-dir (format "%s-%d.org" base page))))
        (with-temp-file file
          (insert (format "#+TITLE: %s (Page %d)\n\n" title page))
          (insert "#+header: :exports results\n")
          (insert "#+header: :results html\n")
          (insert (format "#+begin_src emacs-lisp\n  (%s %d)\n#+end_src\n" generator page)))
        (push file files)))
    (nreverse files)))

;;;; Only to be used within CI environments, to generate the ORG-ROAM db
(defun notes/generate-sqlite-db ()
  "Bootstraps the ORG-ROAM db."
  (cond ((if (string= (getenv "IS_CI") "1") t nil)
         (progn (message "Running ORG-ROAM DB sync")
                (org-roam-db-sync)))
        (t (message "Not running on CI, ignoring block"))))

;;;; CV-related
(defun cv/org-cv-publish-resume (file dest)
  "Publish FILE using org-cv moderncv to DEST."
  (setq-default outfile "cv.tex")
  (setq-default outpdf "cv.pdf")
  (message (format "CHECK IF CV %s EXISTS: %s" file (file-exists-p file)))
  (with-current-buffer
      (find-file-noselect file)
    (org-mode)
    (message "CV OUTFILE: %S" outfile)
    (org-export-to-file 'moderncv outfile)
    (org-latex-compile "cv.tex"))
  (copy-file outpdf dest t))

;;; Project variables:
;;;; don't ask for confirmation before evaluating a code block
(setq org-confirm-babel-evaluate nil)
(setq org-export-use-babel t)
(setq org-export-with-broken-links nil)
(setq org-element-use-cache nil)
(setq org-src-preserve-indentation t)
(setq org-src-fontify-natively t)
;; Let the browser highlighter handle source blocks consistently across builds.
(setq org-html-htmlize-output-type nil)

;;;; No need for backup files
(setq make-backup-files nil)

;; Don't show validation link
(setq org-html-validation-link t)
;; Use our own scripts
(setq org-html-head-include-scripts nil)
;; Use our own styles
(setq org-html-head-include-default-style nil)

;;;; Settings
(setq-default root-dir (concat (getenv "PWD") "/"))
(setq-default static-dir (concat root-dir "static"))
(setq-default static-html-dir (concat static-dir "/" "html"))
(setq-default static-img-dir (concat static-dir "/" "img"))
(setq-default static-css-dir (concat static-dir "/" "css"))
(setq-default org-blog-dir (concat root-dir "blog"))
(setq-default org-roam-dir (concat root-dir "notes"))
(setq-default bibtex-dir (concat root-dir "refs"))

(message (format "SETTING ROOT DIR: %s" root-dir))
(message (format "SETTING STATIC DIR: %s" static-dir))
(message (format "SETTING BLOG DIR: %s" org-blog-dir))
(message (format "SETTING NOTES DIR: %s" org-roam-dir))
(message (format "SETTING BIBTEX DIR: %s" bibtex-dir))

(defcustom out-dir (format "%spublic" root-dir) "Directory where the HTML files are going to be exported.")
(message (format "SETTING OUT DIR: %s" out-dir))

(setq-default url-dir (if (string= (getenv "ENVIRONMENT") "dev") out-dir "https://schonfinkel.github.io"))
(message (format "SETTING URL: %s" url-dir))

(setq-default out-rss-dir (concat out-dir "/" "blog"))
(setq-default out-static-dir (concat out-dir "/static/"))
(setq-default out-css-dir (concat out-static-dir "css"))
(setq-default out-img-dir (concat out-static-dir "img"))
(setq-default out-html-dir (concat out-static-dir "html"))
(setq-default out-blog-dir (concat out-dir "/blog"))
(setq-default out-notes-dir (concat out-dir "/notes"))

;;;; Patch the notes graph URL (replaces the old fix-html.py step)
(load (concat root-dir "graph.el"))
(schonfinkel/patch-graph-url)

;;;; Fix bibliography
(setq org-cite-global-bibliography (get-bib-files-from-path (concat bibtex-dir "/")))
(setq org-cite-export-processors '((latex biblatex)
                                   (moderncv basic)
                                   (html csl)
                                   (t csl)))

;;;; Org-Roam Settings
(setq org-roam-directory org-roam-dir)
(setq org-roam-db-location (concat org-roam-dir "/org-roam.db"))
(message (format "SETTING OUT ORG-ROAM DB LOCATION: %s" org-roam-db-location))

;;;; Adds backlinks to the notes
(add-hook 'org-export-before-processing-functions 'notes/add-extra-sections)

;; RSS
(setq org-rss-use-entry-url-as-guid nil)

;;;; Customize the HTML output
(setq-default html-head-prefix-file (get-string-from-file (concat static-html-dir "/" "header.html")))
(setq-default html-head-prefix (patch-string-with-path html-head-prefix-file url-dir 1))
(message (format "HTML PREFIX: %s" html-head-prefix))
(setq-default website-html-head html-head-prefix)

(setq-default html-nav-file (get-string-from-file (concat static-html-dir "/" "nav.html")))
(setq-default html-nav (patch-string-with-path html-nav-file url-dir 7))
(message (format "HTML NAV: %s" html-nav))
(setq-default website-html-preamble html-nav)

(setq-default html-footer (get-string-from-file (concat static-html-dir "/" "footer.html")))
(message (format "HTML FOOTER: %s" html-footer))
(setq-default website-html-postamble html-footer)

;;; Code:
(setq org-publish-project-alist
      `(("site"
         :base-directory ,root-dir
         :base-extension "org"
         :publishing-directory ,out-dir
         :publishing-function org-html-publish-to-html

         :title "Benevides' Blog"
         :author "Marcos Benevides"
         :email "(concat \"marcos.schonfinkel\" \"@\" \"gmail.com\")"
         :recursive t

         :with-creator t
         :with-tags t
         :with-title t
         :with-toc nil
         :with-date t

         :export-with-tags t
         :exclude-tags ("todo" "noexport")
         :exclude "cv.org\\|level-.*\\|.*\.draft\.org\\|.direnv*\\|.devenv*"
         :section-numbers nil
         :headline-levels 5

         :auto-sitemap nil
         :sitemap-filename "index.org"
         :sitemap-title "Home"
         :sitemap-sort-files anti-chronologically
         :sitemap-file-entry-format "%d - %t"
         :sitemap-style list

         :html-doctype "html5"
         :html-html5-fancy t
         :html-divs ((preamble "header" "preamble")
                     (content "main" "content")
                     (postamble "footer" "postamble"))
         :html-head ,website-html-head
         :html-preamble ,website-html-preamble
         :html-postamble ,website-html-postamble)

        ("rss"
         :base-directory ,org-blog-dir
         :publishing-directory ,out-dir
         :html-link-home ,(concat url-dir "/blog")
         :html-link-use-abs-url t
         :rss-extension "xml"
         :publishing-function (org-rss-publish-to-rss)
         :section-numbers nil
         :table-of-contents nil)

        ("images"
         :base-directory ,static-img-dir
         :base-extension "png\\|jpg\\|gif"
         :publishing-directory ,out-img-dir
         :recursive t
         :publishing-function org-publish-attachment)

        ("css"
         :base-directory ,static-css-dir
         :base-extension "css"
         :publishing-directory ,out-css-dir
         :recursive t
         :publishing-function org-publish-attachment)

        ("html"
         :base-directory ,static-html-dir
         :base-extension "html"
         :publishing-directory ,out-html-dir
         :recursive t
         :publishing-function org-publish-attachment)

        ("other"
         :base-directory ,static-dir
         :base-extension "json\\|xml\\|pdf"
         :publishing-directory ,out-static-dir
         :recursive t
         :publishing-function org-publish-attachment)

        ("all" :components ("css" "images" "html" "other" "rss" "site"))))

;; Generate CV output
;;; We need to keep a local copy of org-cv
;;; and use only "moderncv".
(setq-default org-cv-path
              (let ((env-path (getenv "ORG_CV_PATH")))
                (if env-path
                    (file-name-as-directory env-path)
                  (concat root-dir "org-cv/"))))
(setq-default cv-path (concat root-dir "cv.org"))
(setq-default cv-out (concat static-dir "/" "cv.pdf"))

(message (format "ORG-CV LIB PATH: %s" org-cv-path))
(message (format "ORG CV PATH: %s" cv-path))
(message (format "PDF CV PATH: %s" cv-out))

(add-to-list 'load-path org-cv-path)
(require 'ox-moderncv)

(cv/org-cv-publish-resume cv-path cv-out)

(message "CV build complete!")

;; Generate the site output
(notes/generate-sqlite-db)
(org-roam-update-org-id-locations)

;; blog.org and notes.org are always page 1; generate the extra
;; paginated index pages before publishing and clean them up after.
(let ((generated
       (append
        (schonfinkel/write-index-pages "blog/" 8 "draft\\|rss"
                                       "blog" "Blog" "schonfinkel/generate-blog-list")
        (schonfinkel/write-index-pages "notes/" 14 nil
                                       "notes" "Notes" "schonfinkel/generate-notes-list"))))
  (message (format "GENERATED INDEX PAGES: %S" generated))
  (unwind-protect
      (org-publish-all t)
    (dolist (file generated)
      (when (file-exists-p file)
        (delete-file file)))))

(message "Website build complete!")

;;; publish.el ends here
