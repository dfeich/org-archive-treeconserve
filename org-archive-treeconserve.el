;;; org-archive-treeconserve.el --- org archiving while conserving tree structure

;; Copyright (C) 2016 Derek Feichtinger

;; Author: Derek Feichtinger <dfeich.gmail.com>
;; Keywords: org
;; Package-Requires: ((cl-lib "0.5") (org "8") (emacs "24.3"))
;; URL:
;; Version: 0.8

;;; Commentary:
;; These functions were written to enable me archiving subtrees
;; keeping the same outline path that they had in the source
;; agenda source files
;;
;; The basic idea is archiving an entry as usual and moving it
;; afterwards to the full olp that is saved during archiving
;; to the ARCHIVE_OLPATH property.
;;
;; Note about testing: When the functions in testing/ have been
;; defined, one can test a function in this file interactively by using
;; `org-test-current-defun' while point is in the function

;;; Code:
(require 'org-archive)
(require 'org-clock)


(defun org-arctc-split-escaped-olpath (olp)
  "Split an OLP string into components.

Return a list of the outline path components by splitting the
OLP string at \"/\". Do not split at escaped slashes."
  ;; first replace unescaped slashes by newlines, then replace the
  ;; escaped slashes by normal slashes. Then split on newlines.
  (org-split-string
   (replace-regexp-in-string
    "\\\\/" "/"
    (replace-regexp-in-string "[^\\]\\(/\\)" "\n" olp nil nil 1))
   "\n")
  )

(defun org-arctc-assert-heading-exists (olp &optional create)
  "Ensure that outline path OLP exists.

OLP is given as a list of heading strings.  If CREATE is non-nil,
the heading will be created.  All intermediate levels will be
created as well.  New first level headings are inserted at the end
of the buffer.  Returns a marker to the beginning of the heading
or nil if the path does not exist and CREATE is nil."
  (let (tmpolp marker)
    (cl-assert (eq major-mode 'org-mode) nil "Not in Org mode")
    (save-excursion
      (cl-dolist (elm olp marker)
	(setq tmpolp (concatenate 'list tmpolp `(,elm)))
	(unless (condition-case err
		    (setq marker (org-find-olp tmpolp t))
		  ;; return nil for heading not found, raise the error
		  ;; again for any other error
		  (error (let ((errmsg (error-message-string err)))
			   (if (string-match "^Heading not found.*" errmsg)
			       nil
			     (error errmsg)))))
	  (unless create (cl-return))
	  (org-save-outline-visibility t
	    (if marker (progn (goto-char marker)
			      ;; important to reveal before inserting!
			      (org-reveal)
	 		      (org-insert-heading-after-current)
			      (org-demote-subtree))
	      (goto-char (point-max))
	      (org-insert-heading nil nil t)
	      )
	    (insert elm))
	  (beginning-of-line)
	  (setq marker (point-marker))
	  (end-of-line)
	  (insert "\n")))))
  )

;; the ARCHIVE_OLPATH is problematic, since it separates path elements
;; by "/", but a heading string may also contain a "/".
(defun org-arctc-refile-archive-to-olpath (pom &optional create-parent)
  "Refile the entry at POM to entry's OLP.

The outline path is found in the ARCHIVE_OLPATH property.
Can deal with escaped slash in the olpath string.  If CREATE-PARENT is
non-nil it will create the parent headline in case it does not exist."
  (goto-char pom)
  (let ((olpath (org-entry-get pom "ARCHIVE_OLPATH"))
	(heading (nth 4 (org-heading-components))))
    (assert olpath nil "no property ARCHIVE_OLPATH in this entry")
    (let* ((arc-parentolp (org-arctc-split-escaped-olpath olpath))
	   (cur-parentolp (org-get-outline-path))
	   (arc-olp (concatenate 'list arc-parentolp `(,heading))))
      (when create-parent (org-arctc-assert-heading-exists arc-parentolp t))
      (cond
       ((not (org-arctc-assert-heading-exists arc-parentolp))
	(error "Target item's parent entry does not exist: %s" arc-parentolp)
	)
       ((equal cur-parentolp arc-parentolp)
	(message "item already at olpath"))
       ((org-arctc-assert-heading-exists arc-olp)
	(error "Target item already exists: aborting"))
       (t (progn (message "moving item from %s to %s"
			  (pp-to-string cur-parentolp)
			  (pp-to-string arc-parentolp))
		 ;; the approach with using org-refile did not
		 ;; work out well. RFLOC argument is difficult to
		 ;; construct.
		 ;; (org-refile nil nil
		 ;; 	       `(nil ,(buffer-file-name) nil
		 ;; 		     ,(marker-position
		 ;; 		       (save-excursion
		 ;; 			 (org-arctc-assert-heading-exists
		 ;; 			  arc-parentolp t)))) )
		 (goto-char pom)
		 (org-cut-subtree)
		 (goto-char (org-arctc-assert-heading-exists arc-parentolp))
		 (goto-char (org-entry-end-position))
		 (org-paste-subtree (length arc-olp))
		 (org-arctc-assert-heading-exists arc-olp)))))
    ))

;; modified from http://orgmode.org/worg/org-hacks.html#sec-1-6-1
;; archive subtrees conserving the top level heading and
;; conserving the tags
(defun org-arctc-inherited-no-file-tags ()
  "Return just the tags that are inherited."
  (let ((alltags (org-entry-get nil "ALLTAGS" 'selective))
        (localtags (org-entry-get nil "TAGS")))
    (mapc (lambda (tag)
            (setq alltags
                  (replace-regexp-in-string (concat tag ":") "" alltags)))
          (append org-file-tags (when localtags (split-string localtags ":" t))))
    (if (string= ":" alltags) nil alltags)))

;; modified from http://orgmode.org/worg/org-hacks.html#sec-1-6-1
;; I added escaping of slashes in the olpath
;; added check preventing archiving of a subtree where the full olpath
;; already exists
(defun org-arctc-archive-subtree-around (orig-fun &rest args)
  (let ((tags (org-arctc-inherited-no-file-tags))
	(org-archive-location
	 (if (save-excursion (org-back-to-heading)
			     (> (org-outline-level) 1))
	     (concat (car (split-string org-archive-location "::"))
		     "::* "
		     (car (org-get-outline-path)))
	   org-archive-location))
	(src-olpath (org-get-outline-path))
	(heading (nth 4 (org-heading-components))))
    (with-current-buffer (find-file-noselect (org-extract-archive-file))
      (org-mode)
      (when (org-arctc-assert-heading-exists
	     (append src-olpath (list heading)) )
	(error "Heading already exists in archive")))
    (apply orig-fun args)
    ;; the following code builds on the point being on the inserted
    ;; item when the archive file is opened
    (with-current-buffer (find-file-noselect (org-extract-archive-file))
      (let ((pom (point-marker)))
	(org-entry-put pom "ARCHIVE_OLPATH"
		       (mapconcat
			(lambda (s)
			  (setq s (replace-regexp-in-string "/" "\\\\/" s))
			  s)
			src-olpath "/"))
	(org-arctc-refile-archive-to-olpath pom t))
      (let ((pom (point-marker)))
	;; this saves inherited headings
	(save-excursion
	  (while (org-up-heading-safe))
	  (org-set-tags-to tags))
	(goto-char pom)))))
(advice-add 'org-archive-subtree :around #'org-arctc-archive-subtree-around)

(defun org-arctc-logbook-splitter (date prfx)
  "Split off an entry's older clock records to archive.

Move all the clock lines of the current org heading older than
DATE to the same existing heading in the archive location.  This
is used mainly for permanent tasks which tend to accumulate an
extreme amount of clock lines.

Without a prefix PRFX argument the function will issue an error
if the archive does not already contain an identical headline.  If
a PREFIX argument is given, the headline will be created in the
archive."
  (interactive (list (read-string  "sthreshold date: ")
		     current-prefix-arg))
  (org-back-to-heading)
  ;;(org-clock-find-position nil)
  (let* ((tstamp-inact-rgx
	  (concat "\\[\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}"
		  " *\\sw+\.? +[012][0-9]:[0-5][0-9]\\)\\]"))
	 (clockrange-rgx
	  (concat "^[ \t]*" org-clock-string " "
		  tstamp-inact-rgx "--" tstamp-inact-rgx
		  " +=> +[0-9]+:[0-5][0-9]"))
	 (entryend (org-entry-end-position))
	 (heading (nth 4 (org-heading-components)))
	 (olp (append (org-get-outline-path) (list heading)))
	 datesec rstart)
    (condition-case err
	(setq datesec (org-float-time
		       (apply 'encode-time (org-parse-time-string date))))
      (error (error "Could not parse date: %s" date)))
    (unless
	(save-excursion
	  ;; while usually exits with nil. We exit with t if the clock line
	  ;; we read is older than the given date.

	  ;;(find-file-other-window (org-extract-archive-file))
	  (find-file (org-extract-archive-file))
	  (org-mode)
	  (when prfx (org-arctc-assert-heading-exists olp t))
	  (org-arctc-assert-heading-exists olp))
      (error "The target heading does not exist (%s)" olp))
    (if
	(block nil (while (re-search-forward clockrange-rgx entryend t)
		     (let ((tmpend (match-string-no-properties 2)))
		       (when (< (org-float-time (date-to-time tmpend))
				datesec)
			 (cl-return t)))))
	(progn (outline-show-all)
	       (beginning-of-line)
	       (setq rstart (point))
	       (while (re-search-forward clockrange-rgx entryend t))
	       (next-line)
	       (beginning-of-line)
	       (kill-region rstart (point))
	       (with-current-buffer (find-file-noselect (org-extract-archive-file))
		 ;; insert region at the location for clock lines of this entry
		 (goto-char (org-arctc-assert-heading-exists olp))
		 (org-clock-find-position nil)
		 (yank))
	       )
      (message "no clock lines older than %s" date)
      )))


;; TODO: function showing all headings where the newest clockline is
;; older than a given date. Most of this functionality already exists when
;; creating a sparse tree. But there, the scheduled and deadline times
;; are used.

(provide 'org-archive-treeconserve)

;;; org-archive-treeconserve.el ends here
