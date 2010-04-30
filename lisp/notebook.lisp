
(in-package :mwiki)

(defclass notebook ()
  ((owner :type user)
   (title :type string)
   (repo :type repo)
   (location :type pathname
	     :accessor notebook-location)
   (creation-time :initform (get-universal-time)
		  :accessor notebook-creation-time)))

;;; notebook.lisp ends here