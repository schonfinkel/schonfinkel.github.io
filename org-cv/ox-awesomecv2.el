;;; ox-awesomecv2.el --- LaTeX awesomecv Back-End for Org Export Engine -*- lexical-binding: t; -*-

;; Copyright (C) 2018 Free Software Foundation, Inc.

;; Author: Oscar Najera <hi AT oscarnajera.com DOT com>
;; Maintainer: Óscar Nájera <hi@oscarnajera.com>

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:
;;
;; This library implements a LaTeX awesomecv back-end, derived from the
;; LaTeX one.

;;; Code:
(require 'ox-latex)
(require 'org-cv-utils)

;; Install a default set-up for awesomecv export.
(unless (assoc "awesomecv" org-latex-classes)
  (add-to-list 'org-latex-classes
               '("awesomecv"
                 "\\documentclass{awesome-cv}\n[NO-DEFAULT-PACKAGES]"
                 ("\n\\cvsection{%s}" . "\n\\cvsection{%s}")
                 ("\\cvsubsection{%s}" . "\\cvsubsection{%s}")
                 ("\\subsection{%s}" . "\\subsection*{%s}")
                 ("\\subsubsection{%s}" . "\\subsubsection*{%s}")
                 ("\\cvparagraph{%s}" . "\\cvparagraph{%s}"))))

;;; User-Configurable Variables

(defgroup org-export-cv nil
  "Options specific for using the awesomecv class in LaTeX export."
  :tag "Org awesomecv"
  :group 'org-export
  :version "25.3")

;;; Define Back-End
(org-export-define-derived-backend 'awesomecv2 'latex
  ;;  :menu-entry
  ;;  (?l 1
  ;;      ((?w "AwesomeCV format" (lambda (a s v b) (org-export-to-file 'awesomecv (org-export-output-file-name ".tex"))))))
  :options-alist
  '((:latex-class "LATEX_CLASS" nil "awesomecv" t)
    (:cvstyle "CVSTYLE" nil "classic" t)
    (:cvcolor "CVCOLOR" nil "awesome-red" t)
    (:cvcolorizelinks "CVCOLORIZELINKS" nil nil t)
    (:cvunderlinelinks "CVUNDERLINELINKS" nil nil t)
    (:mobile "MOBILE" nil nil parse)
    (:homepage "HOMEPAGE" nil nil parse)
    (:address "ADDRESS" nil nil newline)
    (:photo "PHOTO" nil nil t)
    (:photostyle "PHOTOSTYLE" nil nil t)
    (:gitlab "GITLAB" nil nil parse)
    (:github "GITHUB" nil nil parse)
    (:leanpub "LEANPUB" nil nil parse)
    (:linkedin "LINKEDIN" nil nil parse)
    (:twitter "TWITTER" nil nil parse)
    (:stackoverflow "STACKOVERFLOW" nil nil split)
    (:extrainfo "EXTRAINFO" nil nil parse)
    (:with-email nil "email" t t)
    (:fontdir "FONTDIR" nil "fonts/" t)
    (:latex-title-command "LATEX_TITLE" nil "\\makecvheader" t)
    (:cvhighlights "CVHIGHLIGHTS" nil "true" t)
    (:quote "QUOTE" nil nil t)
    (:firstname "FIRSTNAME" nil nil t)
    (:lastname "LASTNAME" nil nil t)
    (:cvfooter_left "CVFOOTER_LEFT" nil nil t)
    (:cvfooter_middle "CVFOOTER_MIDDLE" nil nil t)
    (:cvfooter_right "CVFOOTER_RIGHT" nil nil t))
  :translate-alist '((template . org-cv-awesome2-template)
                     (headline . org-cv-awesome2-headline)
                     (plain-list . org-cv-awesome2-plain-list)
                     (item . org-cv-awesome2-item)
                     (property-drawer . ignore)))

;;;; Template
;;
;; Template used is similar to the one used in `latex' back-end,
;; excepted for the table of contents and awesomecv themes.

(defun org-cv-awesome2-template (contents info)
  "Return complete document string after LaTeX conversion.
CONTENTS is the transcoded contents string.  INFO is a plist
holding export options."
  (let ((title (org-export-data (plist-get info :title) info))
        (spec (org-latex--format-spec info)))
    (concat
     ;; Time-stamp.
     (and (plist-get info :time-stamp-file)
          (format-time-string "%% Created %Y-%m-%d %a %H:%M\n"))
     ;; LaTeX compiler.
     (org-latex--insert-compiler info)
     ;; Document class and packages.
     (org-latex-make-preamble info nil t)
     ;; Possibly limit depth for headline numbering.
     (let ((sec-num (plist-get info :section-numbers)))
       (when (integerp sec-num)
         (format "\\setcounter{secnumdepth}{%d}\n" sec-num)))

     (format "\\fontdir[%s]\n" (plist-get info :fontdir))
     (format "\\colorlet{awesome}{%s}\n" (plist-get info :cvcolor))
     (format "\\setbool{acvSectionColorHighlight}{%s}\n" (plist-get info :cvhighlights))
     (let ((cvcolorizelinks (plist-get info :cvcolorizelinks))
           (cvunderlinelinks (plist-get info :cvunderlinelinks)))
       (concat
        (when (and (org-string-nw-p cvcolorizelinks)
                   (not (string-equal cvcolorizelinks "false")))
          (format "\\colorizelinks%s\n"
                  (if (not (string-equal cvcolorizelinks "true"))
                      (format "[%s]" cvcolorizelinks) "")))
        (when (and (org-string-nw-p cvunderlinelinks)
                   (not (string-equal cvunderlinelinks "false")))
          (format "\\underlinelinks%s\n"
                  (if (not (string-equal cvunderlinelinks "true"))
                      (format "[%s]" cvunderlinelinks) "")))))
     ;; Author. If FIRSTNAME or LASTNAME are not given, try to deduct
     ;; their values by splitting AUTHOR on white space.
     (let* ((author (split-string (org-export-data (plist-get info :author) info)))
            (first-name-prop (org-export-data (plist-get info :firstname) info))
            (last-name-prop (org-export-data (plist-get info :lastname) info))
            (first-name (or (org-string-nw-p first-name-prop) (car author)))
            (last-name (or (org-string-nw-p last-name-prop) (cadr author))))
       (format "\\name{%s}{%s}\n" first-name last-name))

     ;; Title
     (format "\\position{%s}\n" title)

     ;; photo
     (let* ((photo (plist-get info :photo))
            (photo-style (plist-get info :photostyle))
            (style-str (if photo-style (format "[%s]" photo-style) "")))
       (when (org-string-nw-p photo) (format "\\photo%s{%s}\n" style-str photo)))

     ;; address
     (let ((address (org-export-data (plist-get info :address) info)))
       (when (org-string-nw-p address)
         (format "\\address{%s}\n" (mapconcat (lambda (line)
                                                (format "%s" line))
                                              (split-string address "\n") " -- "))))
     ;; email
     (let ((email (and (plist-get info :with-email)
                       (org-export-data (plist-get info :email) info))))
       (when (org-string-nw-p email)
         (format "\\email{%s}\n" email)))

     ;; Other pieces of information
     (mapconcat (lambda (info-key)
                  (let ((info (org-export-data (plist-get info info-key) info)))
                    (when (org-string-nw-p info) (format "\\%s{%s}\n"
                                                         (substring (symbol-name info-key) 1)
                                                         info))))
                '(:mobile
                  :homepage
                  :github
                  :gitlab
                  :leanpub
                  :linkedin
                  :twitter
                  :skype
                  :reddit
                  :extrainfo)
                "")

     ;; Stack overflow requires two values: ID and name
     (let* ((so-list (plist-get info :stackoverflow))
            (so-id (when so-list (car so-list)))
            (so-name (when so-list (cadr so-list))))
       (when (and (org-string-nw-p so-id) (org-string-nw-p so-name))
         (format "\\stackoverflow{%s}{%s}\n" so-id so-name)))

     ;; Hyperref options.
     (let ((template (plist-get info :latex-hyperref-template)))
       (and (stringp template)
            (format-spec template spec)))

     ;; Document start.
     "\\begin{document}\n\n"

     ;; Title command.
     (let* ((title-command (plist-get info :latex-title-command))
            (command (and (stringp title-command)
                          (format-spec title-command spec))))
       (org-element-normalize-string
        (cond ((not (plist-get info :with-title)) nil)
              ((string= "" title) nil)
              ((not (stringp command)) nil)
              ((string-match "\\(?:[^%]\\|^\\)%s" command)
               (format command title))
              (t command))))
     ;; Footer command
     (let* ((footer-left (format-spec (or (plist-get info :cvfooter_left) "") spec))
            (footer-mid  (format-spec (or (plist-get info :cvfooter_middle) "") spec))
            (footer-right (format-spec (or (plist-get info :cvfooter_right) "") spec)))
       (when (not (string= "" (concat footer-left footer-mid footer-right)))
         (format "\\makecvfooter{%s}{%s}{%s}\n" footer-left footer-mid footer-right)))

     ;; Document's body.
     contents
     ;; Creator.
     (and (plist-get info :with-creator)
          (concat (plist-get info :creator) "\n"))
     ;; Document end.
     "\\end{document}")))

;;;; Produce latex code for a right-float image
(defun org-cv-awesome2--cventry-right-img-code (file)
  "Include the image on FILE."
  (if file
      (format "\\begin{wrapfigure}{r}{0.15\\textwidth}
  \\raggedleft\\vspace{-4.0mm}
  \\includegraphics[width=0.1\\textwidth]{%s}
\\end{wrapfigure}" file) ""))

;;;; Individual cventry/cvsubentry/cvemployer/cvschool headlines
(defun org-cv-awesome2--entry (headline contents info)
  "Format HEADLINE as as cventry.
CONTENTS holds the contents of the headline.  INFO is a plist used
as a communication channel."
  (let* ((entrytags (org-element-property :tags headline))
         (element (cl-find-if (lambda (s) (string-prefix-p "cv" s)) entrytags))
         (entry (org-cv-utils--parse-cventry headline info)))
    ;; Usage: \cvhonor{<position>}{<title>}{<location>}{<date>}
    ;; Usage: \cventry{<position>}{<title>}{<location>}{<date>}{<description>}
    (if (member element '("cventry" "cvhonor"))
        (format "\n\\%s%s%s\n"
                element
                (mapconcat (lambda (s) (format "{%s}" (alist-get s entry)))
                           '(title host location date)
                           "")
                (if (string= "cventry" element)
                    (concat "{" contents "}")
                  ""))
      (user-error "Incorrect section %s" (alist-get 'title entry)))))

;;;; Headlines of type "cventries"
(defun org-cv-awesome2--format-cvenvironment (environment headline contents info)
  "Format HEADLINE as a cventries/cvhonors ENVIRONMENT.
CONTENTS holds the contents of the headline.  INFO is a plist used
as a communication channel."
  (format "%s\n\\begin{%s}\n%s\\end{%s}\n"
          (org-export-with-backend 'latex headline nil info)
          environment contents environment))

;;; Headline
(defun org-cv-awesome2-headline (headline contents info)
  "Transcode HEADLINE element into moderncv code.
CONTENTS is the contents of the headline.  INFO is a plist used
as a communication channel."
  (unless (org-element-property :footnote-section-p headline)
    (let ((environment (cons (org-element-property :CV_ENV headline)
                             (org-export-get-tags headline info))))
      (cond
       ;; is a cv entry
       ((seq-intersection environment '("cventries" "cvhonors"))
        (org-cv-awesome2--format-cvenvironment
         (car (seq-intersection environment '("cventries" "cvhonors"))) headline contents info))
       ((seq-intersection environment '("cventry" "cvhonor"))
        (org-cv-awesome2--entry headline contents info))
       ((org-export-with-backend 'latex headline contents info))))))

;;;; Plain List, to intercept and transform "cvskills" lists

(defun org-cv-awesome2-plain-list (plain-list contents info)
  "Transcode a PLAIN-LIST element from Org to LaTeX.
CONTENTS is the contents of the list.  INFO is a plist holding
contextual information."
  (let* ((type (org-element-property :type plain-list))
         (tags (org-export-get-tags plain-list info nil 'inherited))
         (parent-type (car (org-element-property :parent plain-list))))
    (cond
     ((and (eq type 'descriptive) (member "skills" tags))
      (format "\\begin{cvskills}\n%s\\end{cvskills}" contents))
     ((and (eq parent-type 'section) (seq-intersection tags '("cventry" "cvsubentry" "cvschool")))
      (format "\\begin{cvitems}\n%s\\end{cvitems}" contents))
     (t
      (org-latex-plain-list plain-list contents info)))))

;;;; Item, to intercept and transform "skills" lists
(defun org-cv-awesome2-item (item contents info)
  "Transcode an ITEM element from Org to awesomecv LaTeX.
CONTENTS holds the contents of the item.  INFO is a plist holding
contextual information."
  (let* ((env-tags (org-export-get-tags item info nil 'inherited))
         (label (let ((tag (org-element-property :tag item)))
                  (and tag (org-export-data tag info)))))
    (if (and (member "skills" env-tags) label)
        (format "\\cvskill{%s}{%s}\n" label (org-trim contents))
      (org-latex-item item contents info))))

(provide 'ox-awesomecv2)
;;; ox-awesomecv2.el ends here
