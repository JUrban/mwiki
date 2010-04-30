
(in-package :mwiki)

(defclass article ()
  ((source :type string
	   :initform "")
   xml
   html))

;;; article.lisp ends here