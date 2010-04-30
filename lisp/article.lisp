
(in-package :mwiki)

(defclass article ()
  ((name :type string
	 :initform ""
	 :accessor article-name)
   (source :type string
	   :initform "")
   (html :initform nil
	 :accessor article-html)))

(defgeneric verify ((article article)))

(defgeneric as-html ((article article)))
	       

;;; article.lisp ends here