;;; test-org-archive-treeconserve.el

;; Copyright (c) Derek Feichtinger
;; Author: Derek Feichtinger


;;; Code:
(ert-deftest test-org-arctc/split-olp ()
  "test basic olp splitting"
  (should
   (equal '("aaaa" "bbb" "cc")
	  (org-arctc-split-escaped-olpath "aaaa/bbb/cc")))
  (should
   (equal '("aaaa" "bbb/dd" "cc")
	  (org-arctc-split-escaped-olpath "aaaa/bbb\\/dd/cc"))))

;;; test-org-archive-treeconserve.el ends here

