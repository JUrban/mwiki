
(in-package :mwiki)

(defclass notebook ()
  ((owner 
    :type user)
   (title 
    :type string)
   (repo 
    :type repo)
   (location 
    :type pathname
    :accessor notebook-location)
   (creation-time 
    :initform (get-universal-time)
    :accessor notebook-creation-time)
   (articles
    :type list
    :initform nil
    :initarg :articles
    :documentation "A list of articles belonging to the notebook."
    :accessor notebook-articles)))

(defgeneric verify (notebook)
  (:documenation 
   "Verfiy the logical validity of the whole contents of a notebook."))

(defgeneric add-article (notebook article)
  (:documentation
   "Attempt to add ARTICLE to NOTEBOOK, giving an error if already present."))

(defgeneric update-article (article notebook)
  (:documentation
   "Replace an older version of ARTICLE in NOTEBOOK with a new
version.  Signals an error if ARTICLE does not belong to NOTEBOOK."))


;;; notebook.lisp ends here