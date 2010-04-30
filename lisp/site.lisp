
(in-package :mwiki)

;;; Hunchentoot configuration

;; Dispatch table

(setq *dispatch-table*
      (list (create-prefix-dispatcher "/" 'initial-page)))

;; Logging

(setf *message-log-pathname* "/tmp/mwiki/logs/messages")
(setf *access-log-pathname* "/tmp/mwiki/logs/access")
(setf *log-lisp-errors-p* t)
(setf *log-lisp-backtraces-p* t)

;; (X)HTML output

; double quotes around attributes rather than single quotes (the default)
(setq *attribute-quote-char* #\")

; XHTML 1.1, for full RDF support
(setq *prologue*
      "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\" \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">")

(define-xml-handler initial-page ()
  (with-title "Welcome to the MIZAR Wiki!"
    (:p "Welcome to the " (:tt "MIZAR") " wiki!")))

;; Initialization and cleanup

(defvar current-acceptor nil
  "The most recently created hunchentoot acceptor object.")

(defun startup (&optional (port 8080))
  (handler-case (progn
		  (setf current-acceptor (make-instance 'acceptor :port port))
		  (values t (start current-acceptor)))
    (usocket:address-in-use-error () 
      (values nil (format nil "Port ~A is already taken" port)))))

(defun shutdown ()
  (stop current-acceptor)
  (setf current-acceptor nil))


;;; site.lisp ends here