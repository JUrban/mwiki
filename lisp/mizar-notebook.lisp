
(in-package :mwiki)

(defclass mizar-notebook (notebook)
  ((vocabularies
    :type list
    :initform nil
    :initarg :vocabularies
    :accessor notebook-vocabularies)
   (binary-version
    :type string
    :initform ""
    :initarg :binary-version
    :accessor mizar-notebook-binary-version)
   (mml-version
    :type string
    :initform ""
    :initarg :mml-version
    :accessor notebook-mml-version)))

(defmethod add-article ((nb mizar-notebook) ((article mizar-article)))
  (if (member (article-name article)
	      (mizar-notebook-articles notebook) :test #'string=)
      (error "There is already an article with name ~A in the notebook ~A"
	     (article-name article) nb)
      (push article (mizar-notebook-articles notebook))))

(defmethod update-article ((nb mizar-notebook) (new-article mizar-article))
  (setf (notebook-articles nb)
	(remove new-article (notebook-articles notebook) 
		:test #'string=
		:key #'article-name)))

(defmethod verify ((notebook mizar-notebook))
  
	     
      

;;; mizar-notebook.lisp ends here