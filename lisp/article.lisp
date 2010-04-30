
(in-package :mwiki)

(defclass article ()
  ((name 
    :type string
    :initform ""
    :accessor article-name)
   (source
    :type string
    :initform "")
   (html 
    :initform nil
    :accessor article-html)))

(defgeneric verify (article)
  (:documentation 
   "Test whether the content of the article is logically valid."))

(defgeneric as-html (article)
  (:documentation
   "An HTML representation of the article.  The value is a string.

We may want to explore later other representations (structured sexps,
rather than strings, for example)."))
	       

;;; article.lisp ends here