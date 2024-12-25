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
(require 'oc-csl)
(require 'org)
(require 'ox)
(require 'ox-html)
(require 'ox-publish)

;;; org-babel configuration

;;; Functions:
;;;; http://xahlee.info/emacs/emacs/elisp_read_file_content.html
(defun get-string-from-file (filePath)
  "Return file content as string from FILEPATH."
  (with-temp-buffer
    (insert-file-contents filePath)
    (buffer-string)))

(defun patch-string-with-path (str filePath n)
  "Patch a STR with FILEPATH and do so N times."
  (apply 'format str (make-list n filePath)))

;;; Project variables:
;;;; don't ask for confirmation before evaluating a code block
(setq org-confirm-babel-evaluate nil)
(setq org-export-use-babel t)
(setq org-export-with-broken-links "mark")
(setq org-element-use-cache nil)

;;;; Settings
(setq-default root-dir (if (string= (getenv "ENVIRONMENT") "dev") (getenv "PWD") ""))
(setq-default static-dir (concat root-dir "/static"))
(setq-default static-html-dir (concat static-dir "/html"))
(setq-default org-blog-dir (concat root-dir "/blog"))
(setq-default org-roam-dir (concat root-dir "/notes"))
(setq-default bibtex-dir (concat root-dir "/refs"))

(message (format "SETTING ROOT DIR: %s" root-dir))
(message (format "SETTING STATIC DIR: %s" static-dir))
(message (format "SETTING BLOG DIR: %s" org-blog-dir))
(message (format "SETTING NOTES DIR: %s" org-roam-dir))
(message (format "SETTING BIBTEX DIR: %s" bibtex-dir))

(defcustom out-dir (format "%s/public" root-dir) "Directory where the HTML files are going to be exported.")
(message (format "SETTING OUT DIR: %s" out-dir))

;;;(setq org-id-locations-file ".orgids")
(setq org-src-preserve-indentation t)
(setq org-cite-global-bibliography
      '("./refs/beam.bib" "./refs/beam.bib" "./refs/databases.bib" "./refs/haskell.bib" "./refs/refs.bib"))
(setq org-cite-export-processors '((latex biblatex)
                                   (moderncv basic)
                                   (html csl)
                                   (t csl)))

;;(defun org-roam-custom-link-builder (node)
;;  (let ((file (org-roam-node-file node)))
;;    (concat (file-name-base file) ".html")))
;;(setq org-roam-graph-link-builder 'org-roam-custom-link-builder)

;;;; Customize the HTML output
(setq-default html-head-prefix-file (get-string-from-file (concat static-html-dir "/" "header.html")))
(setq-default html-head-prefix (patch-string-with-path html-head-prefix-file out-dir 1))
(message (format "HTML PREFIX: %s" html-head-prefix))
(setq-default website-html-head html-head-prefix)

(setq-default html-nav-file (get-string-from-file (concat static-html-dir "/" "nav.html")))
(setq-default html-nav (patch-string-with-path html-nav-file out-dir 5))
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
         :with-title t
         :with-toc nil
         :with-date t

         :export-with-tags nil
         :exclude-tags ("todo" "noexport")
         :exclude "level-.*\\|.*\.draft\.org\\|*direnv*"
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

        ("static"
         :base-directory ,static-dir
         :base-extension "css\\|js\\|png\\|jpg\\|gif\\|pdf\\|json\\|html"
         :publishing-directory ,out-dir
         :recursive t
         :publishing-function org-publish-attachment)

        ("all" :components ("site" "static"))))

;; Generate the site output
(org-publish-all t)

(message "Build complete!")

;;; publish.el ends here
