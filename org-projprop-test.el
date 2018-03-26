;;; org-projprop-test.el --- Tests for org-projprop

;;; Commentary:
;; ert tests testing a variety of `org-projprop' functionality.

(require 'ert)
(require 'cl)

(ert-deftest org-projprop-list-directory ()
  (cl-letf (((symbol-function 'directory-files)
             (lambda (dir &optional full match nosort) '("a" "b"))))
    (should (equal (org-projprop-list-directory "~/tmp")
                   '(("a" . "~/tmp/a") ("b" . "~/tmp/b"))))
    (should (equal (org-projprop-list-directory "~/tmp/")
                   '(("a" . "~/tmp/a") ("b" . "~/tmp/b"))))))

(ert-deftest org-projprop-list-projectile ()
  (cl-letf (((symbol-function 'projectile-relevant-known-projects)
             (lambda () '("~/foo/bar" "~/tmp/baz"))))
    (should (equal '(("bar" . "~/foo/bar")
                     ("baz" . "~/tmp/baz"))
                   (org-projprop-list-projectile)))))

;; TODO: Test more thoroughly. I had a test before, but it hung emacs, for
;; reasons I haven't yet figured out (probably having something to do with the
;; use of cl-letf).
(ert-deftest org-projprop-list ()
  (let ((org-projprop-list-funcs))
    (should-error (org-projprop-list))))
