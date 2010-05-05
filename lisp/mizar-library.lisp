
(in-package :mwiki)

(defclass mizar-library ()
  ((binary-version 
    :documentation "The version of the mizar binaries being used."
    :type string
    :initform ""
    :initarg :binary-version)
   (binaries-root
    :documentation "The directory under which all mizar binaries can be found."
    :type pathname
    :initform nil
    :initarg :binaries-root)
   (mml-version
    :documentation "The version of the MML of this library."
    :type string
    :initform nil
    :initarg :mml-version)
   (articles
    :documentation "The list of (names of) articles in this library."
    :type list
    :initform nil
    :initarg :articles
    :accessor articles)
   (articles-root
    :documentation "The directory containing all the articles in this library."
    :type pathname
    :initform nil
    :initarg :articles-root)))    

;;; mizar-library.lisp ends here