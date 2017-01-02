;;; test-org-archive-treeconserve.el

;; Copyright (c) Derek Feichtinger
;; Author: Derek Feichtinger


;;; Code:

(ert-deftest org-arctc-split-escaped-olpath ()
  "test basic olp splitting"
  (should
   (equal '("aaaa" "bbb" "cc")
	  (org-arctc-split-escaped-olpath "aaaa/bbb/cc")))
  (should
   (equal '("aaaa" "bbb/dd" "cc")
	  (org-arctc-split-escaped-olpath "aaaa/bbb\\/dd/cc"))))

(ert-deftest org-arctc-assert-heading-exists ()
  (should
   (org-test-with-temp-text "* H1\n** H1.1\n* H2\n"
     (org-arctc-assert-heading-exists '("H1"))))
  (should-not
   (org-test-with-temp-text "* H1\n** H1.1\n* H2\n"
     (org-arctc-assert-heading-exists '("Hunknown"))))
  (should
   ;; test creation of a first level heading
   (org-test-with-temp-text "* H1\n** H1.1\n* H2\n"
     (org-arctc-assert-heading-exists '("H3") t)
     (org-arctc-assert-heading-exists '("H3"))))
  (should
   ;; test creation of the heading with 2 levels
   (org-test-with-temp-text "* H1\n** H1.1\n* H2\n"
     (org-arctc-assert-heading-exists '("H3" "H3.1") t)
     (org-arctc-assert-heading-exists '("H3" "H3.1"))))
  (should
   ;; test creation of a 3rd level heading
   (org-test-with-temp-text "* H1\n** H1.1\n* H2\n"
     (org-cycle '(4))
     (org-arctc-assert-heading-exists '("H1" "H1.2" "H1.2.1") t)
     (org-arctc-assert-heading-exists '("H1" "H1.2" "H1.2.1"))))
  )

(ert-deftest org-arctc-refile-archive-to-olpath ()
  (should
   (org-test-with-temp-text
       "# Testfile
* H1
* H2
** H1.1
   :PROPERTIES:
   :ARCHIVE_OLPATH: H1
   :END:
"
     (org-arctc-refile-archive-to-olpath (org-find-exact-headline-in-buffer "H1.1"))
     (org-arctc-assert-heading-exists '("H1" "H1.1")))
   )
  (should-error
   ;; if target parent heading does not exist, expect an error
   (org-test-with-temp-text
       "# Testfile
* H2
** H1.1
   :PROPERTIES:
   :ARCHIVE_OLPATH: H1
   :END:
"
     (org-arctc-refile-archive-to-olpath (org-find-exact-headline-in-buffer "H1.1"))
     (org-arctc-assert-heading-exists '("H1" "H1.1")))
   )
  (should
   ;; test creation of a non existent parent headline when refiling
   (org-test-with-temp-text
       "# Testfile
* H2
** H1.1
   :PROPERTIES:
   :ARCHIVE_OLPATH: H1
   :END:
"
     (org-arctc-refile-archive-to-olpath
      (org-find-exact-headline-in-buffer "H1.1")
      t)
     (and
      (org-arctc-assert-heading-exists '("H1" "H1.1"))
      (not (org-arctc-assert-heading-exists '("H2" "H1.1")))
      ))
   )
  )

(ert-deftest org-arctc-inherited-no-file-tags ()
  (should
   (org-test-with-temp-text "# Testfile
* H1         :A:B:
** H1.1      :C:
*** H1.1.1   :D:
* H2   :tagUnrelated:
"
     (let ((org-use-tag-inheritance t))
       (goto-char (org-find-exact-headline-in-buffer "H1.1.1"))
       (org-arctc-inherited-no-file-tags)
       (string= ":A:B:C:"(org-arctc-inherited-no-file-tags))))
   ))


(ert-deftest org-archive-subtree ()
  (should
   (org-test-with-temp-text-in-dir
       "# Testfile
* H1
** H1.1
** H1.2
"
     (goto-char (org-find-exact-headline-in-buffer "H1.1"))
     ;; note that the archive file gets newly created
     (org-archive-subtree)
     (and
      ;; heading is no longer in src file
      (not (org-arctc-assert-heading-exists '("H1" "H1.1")))
      ;; but in archive file
      (progn
	(find-file (org-extract-archive-file))
	(org-mode)
	(org-arctc-assert-heading-exists '("H1" "H1.1"))))
     )

   ))


(ert-deftest org-arctc-logbook-splitter ()
  (should
   (org-test-with-temp-text-in-dir "# Testfile
* H1
* H2
** H2.1
   :LOGBOOK:
   CLOCK: [2016-09-25 Sun 19:00]--[2016-09-25 Sun 19:20] =>  0:20
   CLOCK: [2016-08-25 Thu 19:00]--[2016-08-25 Thu 19:20] =>  0:20
   CLOCK: [2016-07-25 Mon 19:00]--[2016-07-25 Mon 19:20] =>  0:20
   :END:
* H3
"
     (goto-char (org-find-exact-headline-in-buffer "H2.1"))
     (org-cycle '(64))
     (org-arctc-logbook-splitter "2016-09-01" 4)
     (and
      ;; test in source file
      (goto-char (org-find-exact-headline-in-buffer "H2.1"))
      (search-forward ":LOGBOOK:
   CLOCK: [2016-09-25 Sun 19:00]--[2016-09-25 Sun 19:20] =>  0:20
   :END:
* H3")
      (progn
	;; test in archive file
	(find-file (org-extract-archive-file))
	(org-mode)
	(goto-char (org-find-exact-headline-in-buffer "H2.1"))
	;;(org-narrow-to-subtree)
	(search-forward-regexp
	 (concat  ":LOGBOOK:[\s-]*\n"
		  "[\s-]*CLOCK: \\[2016-08-25 Thu 19:00\\]--\\[2016-08-25 Thu 19:20\\] =>  0:20\n"
		  "[\s-]*CLOCK: \\[2016-07-25 Mon 19:00\\]--\\[2016-07-25 Mon 19:20\\] =>  0:20\n"
		  "[\s-]*:END:\n"
		  )
	 nil t))))
   ))

;;; test-org-archive-treeconserve.el ends here

