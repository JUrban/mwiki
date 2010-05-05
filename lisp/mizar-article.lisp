
(in-package :mwiki)

(defclass mizar-article (article)
  ((xml :initform nil
	:accessor article-xml)))

(defmethod article-mizar-filename ((article article))
  (concatenate 'string
	       (article-name article)
	       ".miz"))

(defmethod article-xml-filename ((article article))
  (concatenate 'string
	       (article-name article)
	       ".html"))

(defmethod article-html-filename ((article article))
  (concatenate 'string
	       (article-name article)

	       ".html"))

(defmethod verify ((article mizar-article))
  (let ((miz (article-mizar-filename article))
	(xml (article-xml-filename article)))
    (cond ((file-exists-p xml)
	   (setf (article-xml article) xml))
	  (t (error "The XML representation of ~A couldn't be generated.")))))
  
;;; mizar-article.lisp ends here