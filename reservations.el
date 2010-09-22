;;; reservations.el Finding mizar reservations

(require 'cl)

(defvar reservation-registry (make-hash-table :test #'equal))

(defun within-comment ()
  (let ((current-position (point))
	(commented-out? nil))
    (save-excursion
      (beginning-of-line)
      (setq commented-out? (re-search-forward "::" current-position t 1)))
    commented-out?))

(defun describe-variable-reservation-table ()
  (maphash #'(lambda (variable values)
	       (princ (format "%s: " variable))
	       (princ (format "%s" (first values)))
	       (dolist (val (cdr values))
		 (princ (format " %s" val)))
	       (terpri))
	   reservation-registry))

(defun register-variable-reservation-at-line (variable type line-number)
  (let ((old-value (gethash variable reservation-registry)))
    (puthash variable (append (list (list line-number type)) old-value) reservation-registry)))	     

(defun trim-leading-whitespace (str)
  (if (string= str "")
      ""
    (let* ((first-non-whitespace 0)
	   (char (aref str first-non-whitespace)))
      (while (or (char-equal char ?\s)
		 (char-equal char ?\t)
		 (char-equal char ?\n))
	(incf first-non-whitespace)
	(setf char (aref str first-non-whitespace)))
      (substring str first-non-whitespace))))

(defun trim-trailing-whitespace (str)
  (if (string= str "")
      ""
    (let* ((len (length str))
	   (first-non-whitespace (1- len))
	   (char (aref str first-non-whitespace)))
      (while (or (char-equal char ?\s)
		 (char-equal char ?\t)
		 (char-equal char ?\n))
	(decf first-non-whitespace)
	(setf char (aref str first-non-whitespace)))
      (substring str 0 (1+ first-non-whitespace)))))

(defun trim-whitespace (str)
  (trim-leading-whitespace (trim-trailing-whitespace str)))

(defun nullify-newlines (str)
  (subst-char-in-string ?\n ?\0 str))

(defun nuke-comments-in-buffer ()
  (goto-char (point-min))
  (let (nuke-begin nuke-end)
    (while (re-search-forward "::" nil t)
      (backward-char 2)
      (setf nuke-begin (point))
      (end-of-line)
      (setf nuke-end (point))
      (delete-region nuke-begin nuke-end))))

(defun nuke-comments (str)
  (let (cleansed)
    (with-temp-buffer
      (insert str)
      (goto-char (point-min))
      (let (nuke-begin nuke-end)
	(while (re-search-forward "::" nil t)
	  (backward-char 2)
	  (setf nuke-begin (point))
	  (end-of-line)
	  (setf nuke-end (point))
	  (delete-region nuke-begin nuke-end)))
      (setf cleansed (buffer-string)))
    cleansed))

(defun nuke-labels (str)
  ;; don't know what to do; trashing this part of the .miz seems
  ;; unsafe (couldn't there be a mizar statement that begins like
  ;; "Th1:"?). there's nothing wrong with keeping the lablels for now,
  ;; but they are unnecessary information that could safely be dumped.
  ;; We just need to consult the XML, rather than trying to solve this
  ;; problem only with the .miz.
  str)

(defun clean-mizar-string (str)
  (nuke-comments
   (nuke-labels
    (trim-whitespace str))))

(defvar reservations nil)

(defun find-reservations ()
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward "reserve[ \t\n]+" nil t)
      (unless (within-comment)
	(let ((begin-res-block (point))
	      (end-res-block nil))
	  (save-excursion
	    (while (null end-res-block)
	      (let ((next-semicolon (re-search-forward ";" nil t)))
		(unless (within-comment)
		  (setf end-res-block next-semicolon)))))
	  (push (list (line-number-at-pos)
		      (buffer-substring-no-properties begin-res-block
						      end-res-block))
		reservations)))))
  (dolist (line-number-and-reservation reservations)
    (destructuring-bind (line-number reservation)
	line-number-and-reservation
      (princ (format "%d" line-number))
      (terpri)
      (princ (format "%s" (nullify-newlines reservation)))
      (terpri))))

(defun article-environment ()
  (let (environ-begin first-section-begin)
    (save-excursion
      (goto-char (point-min))
      (while (null environ-begin)
	(let ((next-environ (re-search-forward "^[ \t]*environ\\([ \t]+\\|$\\)" nil t)))
	  (unless (within-comment)
	    (setf environ-begin next-environ))))
      (while (null first-section-begin)
	(let ((next-begin (re-search-forward "^[ \t]*begin\\([ \t]+\\|$\\)" nil t)))
	  (unless (within-comment)
	    (backward-word)
	    (setf first-section-begin (point))))))
    (princ (clean-mizar-string
	    (buffer-substring-no-properties environ-begin
					    first-section-begin)))))

(defun keyword-before-position (keyword line-number column-number)
  (let ((keyword-begin nil)
	(prev-keyword nil)
	(begin-keyword-regexp (concat keyword "\\([ \t]\\|$\\)"))
	(end-position nil))
    (save-excursion
      (goto-char (point-min))
      (forward-line (1- line-number))
      (forward-char column-number)
      (setf end-position (1+ (point)))
      (while (null keyword-begin)
	(setf prev-keyword (re-search-backward begin-keyword-regexp nil t))
	(unless (within-comment)
	  (if (bolp)
	      (setf keyword-begin prev-keyword)
	    (let ((before (char-before)))
	      (if (or (char-equal before ?\s)
		      (char-equal before ?\t))
		  (setf keyword-begin prev-keyword)))))))
    (clean-mizar-string (buffer-substring-no-properties keyword-begin
							end-position))))

(defun theorem-before-position (line column)
  (princ (keyword-before-position "theorem" line column)))

(defun definition-before-position (line column)
  (princ (keyword-before-position "definition" line column)))

(defun extract-region (beg-line beg-col end-line end-col)
  (let (beg end)
    (save-excursion
      (goto-char (point-min))
      (forward-line (1- beg-line))
      (forward-char beg-col)
      (setf beg (point))
      (forward-line (- end-line beg-line))
      (beginning-of-line)
      (forward-char end-col)
      (setf end (point)))
    (princ (buffer-substring-no-properties beg end))))

;;; reservations.el ends here