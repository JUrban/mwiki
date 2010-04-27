
(in-package :mwiki)

(defvar xml-declaration
  "<?xml version='1.1' encoding='UTF-8'?>")

(defmacro with-xml-declaration (&body body)
  `(concatenate 'string
     xml-declaration
     (format nil "~%")
     *prologue*
     (with-html-output-to-string (*standard-output* nil)
       ,@body)))

(defmacro with-html (&body body)
  `(with-xml-declaration
     (:html :xmlns "http://www.w3.org/1999/xhtml"
	,@body)))

(defmacro with-title (title &body body)
  `(with-html
     (:head (:title ,title))
     (:body ,@body)))

(defmacro define-xml-handler (name (&rest args) &body body)
  `(defun ,name (,@args)
     (setf (content-type*) "application/xhtml+xml")
     ,@body))

(defmacro define-xhtml-handler (name (&rest args) &body body)
  `(defun ,name (,@args)
     (setf (content-type*) "text/html")
     ,@body))

;;; xhtml-utils.lisp ends here
