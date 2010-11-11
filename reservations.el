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

(defun position->line+column (pos)
  (let (line col)
    (save-excursion
      (goto-char pos)
      (setf line (current-line)
	    col (current-column)))
    (values line col)))

(defun position-of-keyword-before-position (keyword line column)
  (let ((keyword-begin nil)
	(prev-keyword nil)
	(begin-keyword-regexp (concat keyword "\\([ \t]\\|$\\)"))
	(end-position nil))
    (save-excursion
      (goto-char (point-min))
      (forward-line (1- line))
      (forward-char column)
      (setf end-position (point))
      (while (null keyword-begin)
	(setf prev-keyword (re-search-backward begin-keyword-regexp nil t))
	(unless (within-comment)
	  (if (bolp)
	      (setf keyword-begin prev-keyword)
	    (let ((before (char-before)))
	      (if (or (char-equal before ?\s)
		      (char-equal before ?\t))
		  (setf keyword-begin prev-keyword)))))))
    (princ (position->line+column keyword-begin))))

(defun position-of-theorem-keyword-before-position (line column)
  (position-of-keyword-before-position "theorem" line column))

(defun keyword-before-position (keyword line-number column-number)
  (let ((keyword-begin nil)
	(prev-keyword nil)
	(begin-keyword-regexp (concat keyword "\\([ \t]\\|$\\)"))
	(end-position nil))
    (save-excursion
      (goto-char (point-min))
      (forward-line (1- line-number))
      (forward-char column-number)
      (setf end-position (point))
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

(defun scheme-before-position (line column)
  (princ (keyword-before-position "scheme" line column)))

(defun extract-region (beg-line beg-col end-line end-col)
  (let (beg end)
    (save-excursion
      (goto-char (point-min))
      (forward-line (1- beg-line))
      (forward-char beg-col)
      (setf beg (point))
      (goto-char (point-min))
      (forward-line (1- end-line))
      (beginning-of-line)
      (forward-char end-col)
      (setf end (point)))
    (princ (buffer-substring-no-properties beg end))))

(defun current-line-length ()
  (let (beg end)
    (save-excursion
      (beginning-of-line)
      (setf beg (point))
      (end-of-line)
      (setf end (point)))
    (length (buffer-substring-no-properties beg end))))

(defun line-col->pos (line col)
  (let (pos)
    (save-excursion
      (goto-char (point-min))
      (forward-line (1- line))
      (if (<= col (current-line-length))
	  (forward-char col)
	  (end-of-line))
      (setf pos (point)))
    pos))

(defun region-boundary (beg-line beg-col end-line end-col)
  (values (line-col->pos beg-line beg-col) (line-col->pos end-line end-col)))

(defun funky-lex (tuple-1 tuple-2)
  ; reverse lexicographic sort on the first two components of the
  ; triples in SCHEMES-TO-REPLACE -- we need to make our replacements
  ; starting from the end of the delimited region, not the beginning
  ; (and certainly not randomly)
  (let ((line-1 (cadr tuple-1))
	(line-2 (cadr tuple-2))
	(col-1 (caddr tuple-1))
	(col-2 (caddr tuple-2)))
    (or (> line-1 line-2)
	(and (= line-1 line-2)
	     (> col-1 col-2)))))

(defun apply-scheme-replacement (instruction)
  (destructuring-bind (line col absolute-item-number)
      (cdr instruction)
    (goto-char (point-min))
    (forward-line (1- line))
    (forward-char col)
    (forward-word 1)
    (backward-kill-word 1)
    (insert (format "%d:sch 1" absolute-item-number))))

(defun apply-definition-replacement (instruction)
  (destructuring-bind (line col absolute-item-number def-number)
      (cdr instruction)
    (goto-char (point-min))
    (forward-line (1- line))
    (forward-char col)
    (backward-kill-word 1)
    (insert (format "%d:def %d" absolute-item-number def-number))))

(defun apply-theorem-replacement (instruction)
  (destructuring-bind (line col absolute-item-number)
      (cdr instruction)
    (goto-char (point-min))
    (forward-line (1- line))
    (forward-char col)
    (backward-kill-word 1)
    (insert (format "%d:1" absolute-item-number))))

(defun delimited-region (beg-line beg-col end-line end-col)
  (multiple-value-bind (beg end)
      (region-boundary beg-line beg-col end-line end-col)
    (buffer-substring-no-properties beg end)))

(defun toplevel-unexported-theorem-before-position-with-label (end-line end-col label)
  (let* ((find-label (concat label ":[ \t\n]"))
	 (len (length label))
	 (result nil))
  (save-excursion
    (goto-char (point-min))
    (forward-line (1- end-line))
    (forward-char end-col)
    (if (re-search-backward find-label nil t)
	(progn
	  (forward-char len)
	  (re-search-forward "[^ \t\n]")
	  (setf result (buffer-substring-no-properties (point)
						       (line-col->pos end-line end-col))))
      (error "Weird: we didn't find the label %s before (%d,%d)" label end-line end-col)))
  (princ result)))

(defun current-line ()
  "Return current line number."
  (+ (count-lines 1 (point))
     (if (= (current-column) 0) 1 0)))

(defun extract-region-replacing-schemes-and-definitions-and-theorems (item-keyword item-label beg-line beg-col end-line end-col &rest replacement-instructions)
  "Within the region delimited by (BEG-LINE,BEG-COL)
and (END-LINE,END-COL), replace references to article-local
schemes and definitions indicated in the arguments REPLACEMENT-INSTRUCTIONS.  REPLACEMENT-INSTRUCTIONS should be a list of 4-tuples

  (REPLACEMENT-TYPE LINE COL ABSOLUTE-ITEM-NUMBER)

REPACEMENT-TYPE must be either 'definition', 'scheme' or
'theorem'.  If it is 'scheme', then the pair (LINE,COL) means
that the cursor is immediately before the name of an
article-local scheme to be replaced.  It will be replaced by
\"<ABSOLUTE-ITEM-NUMBER>:sch 1\".  If REPLACEMENT-TYPE is
equal to 'definition', then the pair (LINE,COL) is immediately
after the name of the article-local definition, and will be
replaced by \"<ABSOLUTE-ITEM-NUMBER>:def 1\".  Finally, if
REPLACEMENT-TYPE is 'theorem', then (LINE,COL) is immediately
after the name of a reference to an article-local theorem, and it
will be replaced by \"<ABSOLUTE-ITEM-NUMBER>:1\"."
  (if (eq item-keyword 'canceled)
      (princ "theorem not contradiction")
    (let (real-beg-line real-beg-col what-we-are-looking-for)
      (if (eq item-keyword 'proposition)
	  (setf what-we-are-looking-for (concat item-label ":[ \t\n]"))
	(setf what-we-are-looking-for (format "^%s[ \t\n]+\\|[ \t\n]%s[ \t\n]+" item-keyword item-keyword)))
      (save-excursion
	(goto-char (point-min))
	(forward-line (1- end-line))
	(forward-char end-col)
	(re-search-backward what-we-are-looking-for nil t)
	(while (within-comment)
	  (re-search-backward what-we-are-looking-for nil t))
	(setf real-beg-line (current-line)
	      real-beg-col (current-column)))
      (message "the real begin line is %d and the real bein col is %d" real-beg-line real-beg-col)
      (let ((region (delimited-region real-beg-line real-beg-col end-line end-col)))
	(let ((buf (generate-new-buffer "item")))
	  (with-current-buffer buf
	    (dotimes (i (1- real-beg-line))
	      (insert ?\n))
	    (dotimes (i real-beg-col)
	      (insert ?\s))
	    (when (eq item-keyword 'proposition)
	      (insert "theorem ")) ; this is fragile and can screw up column info
	    (insert region)
	    (let ((instructions (sort replacement-instructions #'funky-lex)))
	      (dolist (instruction instructions)
		(let ((instruction-type (car instruction)))
		  (cond ((eq instruction-type 'scheme)
			 (apply-scheme-replacement instruction))
			((eq instruction-type 'definition)
			 (apply-definition-replacement instruction))
			((eq instruction-type 'theorem)
			 (apply-theorem-replacement instruction))))))
	    (princ (trim-leading-whitespace (buffer-string)))))))))
    
;;; reservations.el ends here