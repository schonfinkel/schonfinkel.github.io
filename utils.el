;;; utils.el --- Summary
;;;   Some utils make the code gen easier
;;;
;;; Commentary:
;;;   * eval the buffer
;;;   * M-x site-publish

;;; Code:
(defun utils/list-org-files-in-dir (directory)
  "List all Org files in a given DIRECTORY."
  (directory-files directory t "\\.org\\'" nil))

(defun utils/extract-org-title-and-date (file)
  "Extract the TITLE and DATE properties from a FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (let ((title nil)
          (date nil))
      (when (re-search-forward "^#\\+TITLE: \\(.*\\)$" nil t)
        (setq title (match-string 1)))
      (when (re-search-forward "^#\\+DATE: <\\(.*\\)\s+...>.+$" nil t)
        (setq date (match-string 1)))
      (list :title title :date date :filename (file-name-nondirectory file)))))

(defun utils/format-element (data)
  "Formats DATA into a html string."
  (setq title (plist-get data :title))
  (setq date (plist-get data :date))
  (setq filename (file-name-sans-extension (plist-get data :filename)))
  (setq path (format "./blog/%s.html" filename))
  (format "<div class=\"stub\"><h2><a href=\"%s\"> %s </a></h2><small>%s</small></div>" path title date))

(defun utils/generate-html (directory)
  "Picks all orgfiles from DIRECTORY and generate the html out of them."
  (setq-default posts (utils/list-org-files-in-dir "./blog/"))
  (setq-default elements (mapcar 'utils/extract-org-title-and-date posts))
  (mapconcat 'utils/format-element elements "\n\n"))

;;; utils.el ends here
