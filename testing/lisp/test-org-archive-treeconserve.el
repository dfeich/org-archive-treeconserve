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
   ;; test creation of the heading
   (org-test-with-temp-text "* H1\n** H1.1\n* H2\n"
     (org-arctc-assert-heading-exists '("H3") t)
     (org-arctc-assert-heading-exists '("H3"))))
  (should
   ;; test creation of the heading with 2 levels
   (org-test-with-temp-text "* H1\n** H1.1\n* H2\n"
     (org-arctc-assert-heading-exists '("H3" "H3.1") t)
     (org-arctc-assert-heading-exists '("H3" "H3.1"))))
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
;;; test-org-archive-treeconserve.el ends here

