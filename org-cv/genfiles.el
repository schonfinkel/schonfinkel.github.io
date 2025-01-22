(defvar cv-cwd default-directory
  "remember the current directory, find-file changes it")
(defvar cv-workdir (expand-file-name "org-cv-exports/"))
(toggle-debug-on-error)
(with-current-buffer (find-file-noselect "/tmp/install-org.el")
  (eval-buffer))

(package-refresh-contents)

(use-package ox-hugo
  :ensure t
  :pin melpa
  :after ox)

(use-package ox-moderncv
  :load-path cv-cwd
  :ensure dash
  :init
  (require 'ox-altacv)
  (require 'ox-hugocv)
  (require 'ox-awesomecv)
  (require 'ox-awesomecv2))

(defun export-with (backend file ext)
  (let ((workfile (concat cv-workdir file))
        (outfile (concat cv-workdir file ext)))
    (message (format "%s exists: %s" workfile (file-exists-p workfile)))
    (with-current-buffer
        (find-file-noselect workfile)
      (org-mode)
      (message "back %S, out %S" backend outfile)
      (org-export-to-file backend outfile))
    outfile))

(defun export-latex (backend file)
  (let ((outfile (export-with backend file ".tex"))
        (pdffile (concat cv-workdir file ".pdf")))
    (cd cv-workdir)
    (message (format "%s exists: %s" outfile (file-exists-p outfile)))
    (shell-command (format "xelatex --output-directory=%s %s" cv-workdir outfile) "*Messages*" "*Messages*")
    (message (format "%s exists: %s" pdffile (file-exists-p pdffile)))
    (copy-file pdffile (concat cv-cwd "/doc/static/" (concat file ".pdf")) t)))

(let ((readme (concat cv-cwd "readme.org")))
  (make-directory cv-workdir t)
  (with-current-buffer
      (find-file-noselect readme)
    (cd cv-workdir)
    (org-babel-tangle)))

(copy-file (concat cv-cwd "doc/smile.png") cv-workdir t)
(make-directory (concat cv-cwd "/doc/static/") t)
(export-latex 'altacv "altacv.org")
(export-latex 'moderncv "moderncv.org")
(export-latex 'awesomecv2 "awesomecv.org")
(export-latex 'awesomecv "awesomecv.org")
(export-latex 'awesomecv "awesome-letter.org")
(copy-file
 (export-with 'hugocv "hugocv.org" ".md")
 (concat cv-cwd "/doc/content/post/cv.md"))
