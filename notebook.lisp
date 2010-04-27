
(in-package :mwiki)

(defclass notebook ()
  ((owner :type user)
   (title :type string)
   (repo :type repo)))

;;; notebook.lisp ends here