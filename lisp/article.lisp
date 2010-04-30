
(in-package :mwiki)

(defclass article ()
  ((source :type string
	   :initform "")
   (xml :initform nil
	:accessor article-xml)
   (html :initform nil
	 :accessor article-html)))

;;; article.lisp ends here