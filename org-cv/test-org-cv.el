;;; test-org-cv.el --- Test Org-cv -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2022 Óscar Nájera
;;
;; Author: Óscar Nájera <hi@oscarnajera.com>
;; Maintainer: Óscar Nájera <hi@oscarnajera.com>
;; Created: August 19, 2022
;; Modified: August 19, 2022
;; Version: 0.0.1
;; Keywords: abbrev bib c calendar comm convenience data docs emulations extensions faces files frames games hardware help hypermedia i18n internal languages lisp local maint mail matching mouse multimedia news outlines processes terminals tex tools unix vc wp
;; Homepage: https://github.com/titan/test-org-cv
;; Package-Requires: ((emacs "24.3"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;;  Test Org-cv
;;
;;; Code:

(require 'org-cv-utils)
(ert-deftest test-org-cv-utils-org-timestamp-to-shortdate ()
  (pcase-dolist (`(,input ,expected)
                 '(("<2002-08-12 Mon>" "Aug 2002")
                   ("[2012-05-24]" "May 2012")
                   ("today" "today")))
    (should (string= (org-cv-utils-org-timestamp-to-shortdate input) expected))))

(provide 'test-org-cv)
;;; test-org-cv.el ends here
