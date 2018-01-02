;;; org-project-test.el --- Tests for org-project

;;; Commentary:
;; ert tests testing a variety of `org-project' functionality.

(require 'ert)
(require 'cl)

(ert-deftest org-project-list-directory ()
  (cl-letf (((symbol-function 'directory-files)
             (lambda (dir &optional full match nosort) '("a" "b"))))
    (should (equal (org-project-list-directory "~/tmp")
                   '(("a" . "~/tmp/a") ("b" . "~/tmp/b"))))
    (should (equal (org-project-list-directory "~/tmp/")
                   '(("a" . "~/tmp/a") ("b" . "~/tmp/b"))))))

(ert-deftest org-project-list-projectile ()
  (cl-letf (((symbol-function 'projectile-relevant-known-projects)
             (lambda () '("~/foo/bar" "~/tmp/baz"))))
    (should (equal '(("bar" . "~/foo/bar")
                     ("baz" . "~/tmp/baz"))
                   (org-project-list-projectile)))))

;; TODO: Test more thoroughly. I had a test before, but it hung emacs, for
;; reasons I haven't yet figured out (probably having something to do with the
;; use of cl-letf).
(ert-deftest org-project-list ()
  (let ((org-project-list-funcs))
    (should-error (org-project-list))))
