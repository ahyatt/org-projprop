;;; org-project.el --- Link org headings with projects -*- lexical-binding:t -*-

;; Copyright (c) 2018 Free Software Foundation, Inc.

;; Author: Andrew Hyatt <ahyatt@gmail.com>
;; Keywords: Org-mode, Projects, Projectile, Eshell
;; Version: 0.1
;; Package-Requires: ((cl-lib "0.5"))
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3 of the
;; License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;; This package allows the user to set a project property in org headings,
;; and use those properties to open a project in a variety of ways.
;;
;; To use, at a minimum, configure `org-project-list-funcs' which defines
;; what the projects available are, and in what directory they are located.
;;
;; It is also necessary to call (org-project-setup) to integrate into org mode.
;;
;; Once this is done, you can set a property "PROJECT" (or whatever the value of
;; `org-project-property-name' is) and list of project names should be available
;; for completion. Choosing one should, if you have the `persp-mode' package
;; installed, open a perspective, and put both an eshell in the project
;; directory, and a narrowed org-mode buffer in the perspective. Without
;; `persp-mode', both the eshell and org mode buffer will still be created, just
;; not in a perspective. The behavior of opening a project is defined with
;; `org-project-open-funcs', and can also be configured.

;;; Code:

(defgroup org-project nil
  "Customization for the `org-project' package."
  :prefix 'org-project
  :version "25.2.1"
  :package-version '(org-project . "0.1")
  :group 'org)

(defcustom org-project-property-name "PROJECT"
  "The name for the org property to store the project."
  :group 'org-project
  :type '(string))

;; This can't be customized easily, best to leave it to elisp to setup.
(defvar org-project-list-funcs nil
  "List of functions providing project locations.
For example:
  (setq org-project-list-funcs
     '((directory \"~/src/\")
       (directory \"~/Dropbox/src/\")
       (projectile)))

Each list item is evaluated by taking the first symbol and
calling a function prepended by org-project-list-. You can write
your own function called, for example, org-project-list-foo, and
refer to it via the symbol `foo' here.  The other parts of each
entry are the arguments that will be passed to the function.

The `directory' and `projectile' methods are already available to
use.")

(defcustom org-project-eshell-format "*eshell-%s*"
  "Format string for eshell buffers."
  :group 'org-project
  :type '(string))

(defcustom org-project-org-buffer-format "*org-%s*"
  "Format string for org buffers."
  :group 'org-project
  :type '(string))

(defcustom org-project-open-funcs '(persp eshell org-buffer)
  "List of functions to call when opening a project.
Each is called in order and each calls a function prepended by
`org-project-open-'. Each function takes as an argument the
project name and the project directory. Each is called without
save the excursion, so any windowing changes are seen by the
user. You can define your own functions following that pattern
and reference them here."
  :group 'org-project
  :type '(repeat symbol))

(defun org-project-list-directory (dir)
  "Projects are subdirectories of DIR."
  (mapcar
   (lambda (d)
     (cons d (concat (directory-file-name dir) "/" d)))
   (directory-files dir nil "^[^.]")))

(defun org-project-list-projectile ()
  "Projects are projectile known projects."
  (mapcar (lambda (p) (cons (file-name-nondirectory p) p))
          (projectile-relevant-known-projects)))

(defun org-project-open-eshell (name dir)
  "Open an eshell for project called NAME in directory DIR."
  (require 'eshell)
  (let ((default-directory dir))
    (cl-letf (((symbol-value 'eshell-buffer-name)
               (format org-project-eshell-format name)))
      (eshell))))

(defun org-project-open-persp (name dir)
  "Open a perspective for the project called NAME.
Add all buffers for files under DIR to the perspective. If the
persp package is not installed, do nothing. This only makes sense
to use if ‘persp-add-buffer-on-after-change-major-mode’ is
non-nil."
  (when (featurep 'persp-mode)
    (unless (persp-with-name-exists-p name)
      (persp-add-new name))
    (persp-switch name)
    (dolist (buffer (buffer-list))
      (let ((f (buffer-file-name buffer)))
        (when (and f (string-prefix-p
                      (expand-file-name dir)
                      (expand-file-name (buffer-file-name buffer))))
          (persp-add-buffer buffer))))
    ;; Now that we have a new perspective, clear up the windows.
    (delete-other-windows)))

(defun org-project-open-org-buffer (name _)
  "Create a new indirect buffer with only the relevant part of the org file.
Specifically, it's the same org file but with an indirecto
buffer, narrowed to the parent heading with the project NAME."
  (let* ((buf-name (format org-project-org-buffer-format name))
         (buf (make-indirect-buffer (current-buffer) buf-name t)))
    (switch-to-buffer buf)
    (let ((orig-point (point)))
      (while (not (org-entry-get (point) org-project-property-name))
        (outline-up-heading 1 t))
      (org-narrow-to-subtree)
      (goto-char orig-point))
    (when (featurep 'persp-mode)
      ;; In case we were using persp, make sure it acts on this indirect
      ;; buffer. It doesn't happen automatically, so we have to run this
      ;; manually.
      (persp-after-change-major-mode-h))))

(defun org-project-open ()
  "Open the project at the current org entry."
  (interactive)
  (let* ((buf (current-buffer))
         (name
          (org-entry-get nil org-project-property-name t))
         (dir
          (cdr (assoc name (org-project-list))))
         (point (point)))
    (dolist (f org-project-open-funcs)
      ;; Each function should assume it starts at the same place.
      (with-current-buffer buf
        (goto-char point)
        (funcall (intern (format "org-project-open-%s" (symbol-name f))) name dir)))))

(defun org-project-property-values (prop)
  "Function to populate valid property values for org property setting.
PROP is the property being set, and this function should ignore
all properties except for the project property."
  (when (equal prop org-project-property-name)
    (append (mapcar #'car
             (org-project-list)))))

(defun org-project-setup ()
  "Setup function to enable org-project behavior."
  (with-eval-after-load 'org
    (add-to-list 'org-property-allowed-value-functions
                 'org-project-property-values)))

(defun org-project-list ()
  "Return a list of projects available.
The strategy for getting that list is based on
`org-project-list-func'."
  (if org-project-list-funcs
      (cl-remove-if
       'null
       (cl-remove-duplicates
        (cl-mapcan
         (lambda (e)
           (apply
            (intern
             (concat "org-project-list-" (symbol-name (car e))))
            (cdr e)))
         org-project-list-funcs)
        :test 'equal))
    (error "org-project-list-func not defined, cannot get projects.")))

(provide 'org-project)

;;; org-project.el ends here
