;; Directory Local Variables
;;; For more information see (info "(emacs) Directory Variables")
(( org-mode . ((eval .
  (progn
            (setq org-confirm-babel-evaluate nil)
            (org-babel-do-load-languages
             'org-babel-load-languages
                '((awk . t)
                  (dot . t)
                  (emacs-lisp . t)
                  (eshell . t)
                  (latex . t)
                  (org . t)
                  (python . t)
                  (shell   . t))))))))
