;;; test-org-archive-treeconserve.el

;; Copyright (c) Derek Feichtinger
;; Author: Derek Feichtinger


;;; Code:

(defconst org-arctc-text1
  "# Testfile
* H1
** H1.1
*** H1.1.1
*** H1.1.2
*** H1.1.3
** H1.2
")

(ert-deftest org-arctc-split-escaped-olpath ()
  "test basic olp splitting"
  (should
   (equal '("aaaa" "bbb" "cc")
	  (org-arctc-split-escaped-olpath "aaaa/bbb/cc")))
  (should
   (equal '("aaaa" "bbb/dd" "cc")
	  (org-arctc-split-escaped-olpath "aaaa/bbb\\/dd/cc"))))

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
     (org-arctc-ensure-heading-exists '("H1" "H1.1")))
   )
  )

;; TODO unfinished
(ert-deftest org-archive-subtree ()
  (should
   (org-test-with-temp-text-in-dir
       org-arctc-text1
     (goto-char (org-find-exact-headline-in-buffer "H1.1"))
     ;;(edebug)
     (org-archive-subtree)
     (find-file (org-extract-archive-file))
     (org-mode)
     (and
      (org-arctc-ensure-heading-exists '("H1")))
     )))
;;; test-org-archive-treeconserve.el ends here

