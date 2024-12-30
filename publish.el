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

(defun patch-list-with-prefix (prefix strings)
  "Prepend PREFIX to every string in STRINGS."
  (mapcar (lambda (s) (concat prefix s)) strings))

;;; Project variables:
;;;; don't ask for confirmation before evaluating a code block
(setq org-confirm-babel-evaluate nil)
(setq org-export-use-babel t)
(setq org-export-with-broken-links nil)
(setq org-element-use-cache nil)
(setq org-src-preserve-indentation t)

(setq org-src-fontify-natively t)

;; Don't show validation link
(setq org-html-validation-link nil)
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
(setq-default emacs-dir-path (concat (getenv "home") ".emacs.d/"))

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

;;;; Fix bibliography
(setq org-cite-refs-list '("articles.bib"
                           "beam.bib"
                           "databases.bib"
                           "fp_general.bib"
                           "haskell.bib"
                           "leadership.bib"
                           "math_and_logic.bib"
                           "nixos.bib"
                           "software_engineering.bib"
                           "sysadmin.bib"))
(setq org-cite-refs-path (patch-list-with-prefix (concat bibtex-dir "/") org-cite-refs-list))
(setq org-cite-global-bibliography org-cite-refs-path)
(setq org-cite-export-processors '((latex biblatex)
                                   (moderncv basic)
                                   (html csl)
                                   (t csl)))

;;;; Org-Roam Settings
(setq org-roam-directory org-roam-dir)
(setq org-roam-db-location (concat emacs-dir-path "org-roam.db"))
;;(setq org-roam-db-extra-links-exclude-keys
;;      '((node-property "ROAM_REFS" "BACKLINKS")
;;        (keyword "transclude")))


;;;; Customize the HTML output
(setq-default html-head-prefix-file (get-string-from-file (concat static-html-dir "/" "header.html")))
(setq-default html-head-prefix (patch-string-with-path html-head-prefix-file url-dir 1))
(message (format "HTML PREFIX: %s" html-head-prefix))
(setq-default website-html-head html-head-prefix)

(setq-default html-nav-file (get-string-from-file (concat static-html-dir "/" "nav.html")))
(setq-default html-nav (patch-string-with-path html-nav-file url-dir 6))
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
         :exclude "level-.*\\|.*\.draft\.org\\|.direnv*"
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
         :base-extension "org"
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
         :base-extension "json\\|xml"
         :publishing-directory ,out-static-dir
         :recursive t
         :publishing-function org-publish-attachment)

        ("all" :components ("css" "images" "html" "other" "rss" "site"))))

;; Generate the site output
(org-roam-update-org-id-locations)
(org-publish-all t)

(message "Build complete!")

;;; publish.el ends here
