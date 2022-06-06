;;; consult-lean.el --- Consult interfaces for lean-mode -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2022 Leo Okawa Ericson
;;
;; Author: Leo Okawa Ericson <leo@relevant-information.com>
;; Maintainer: Leo Okawa Ericson <leo@relevant-information.com>
;; Created: June 06, 2022
;; Modified: June 06, 2022
;; Version: 0.0.1
;; Keywords: languages
;; Homepage: https://github.com/leanprover/lean-mode
;; Package-Requires: ((emacs "25.1") (consult "0.18") (lean-mode "3.3.0"))
;;
;; Released under Apache 2.0 license as described in the file LICENSE.
;;
;;; Commentary:
;;
;; Currently provides an interface for looking up Lean definitions by name
;;
;;; Code:

(require 'lean-server)
(require 'consult)

(defcustom consult-lean-keybinding-helm-lean-definitions (kbd "C-c C-d")
  "Lean Keybinding for helm-lean-definitions."
  :group 'lean-keybinding :type 'key-sequence)

(defvar consult-lean--definitions-history nil)

(defun consult-lean--definitions-annotate-candidate (s)
  "Annotate S."
  (let ((meta-data (get-text-property 0 'meta-data s)))
    (format " : %s %s"
            (plist-get meta-data :type)
            (propertize (plist-get (plist-get meta-data
                                              :source)
                                   :file)
                        'face font-lock-comment-face))))

(defun consult-lean--definitions-builder (input buffer)
  "Generate candidates from user INPUT in BUFFER."
  (with-current-buffer buffer
    (let* ((response (lean-server-send-synchronous-command 'search (list :query input)))
           (results (plist-get response :results))
           (results (seq-filter (lambda (c) (plist-get c :source)) results))
           (candidates (seq-map (lambda (c) (propertize (plist-get c :text)
                                                        'meta-data c))
                                results)))
      candidates)))

(defun consult-lean--make-async-source (async buffer)
  "Create async source for `consult--read'.
ASYNC is a sink generated by `consult--async-sink'.
BUFFER is the buffer to get candidates for."
  (lambda (action)
    (pcase-exhaustive action
      ('nil (funcall async action))
      ('setup (funcall async action))
      (stringp
       (when-let ((res (and (not (string-empty-p action))
                            (consult-lean--definitions-builder action buffer))))
         (funcall async 'flush)
         (funcall async res))
       (funcall async action))
      (_ (funcall async action)))))

(defun consult-lean--lookup (selected candidates _input _narrow)
  "Get complete metadata from SELECTED among CANDIDATES."
  (plist-get
   (get-text-property 0 'meta-data
                      (car (seq-drop-while (lambda (x)
                                             (not (string-equal selected
                                                                (substring-no-properties x))))
                                           candidates)))
   :source))

(defun consult-lean-definitions ()
  "Find a Lean definition using consult."
  (interactive)
  (let ((user-choice (consult--read
                      (thread-first (consult--async-sink)
                                    (consult--async-refresh-immediate)
                                    (consult-lean--make-async-source (current-buffer))
                                    ;; causes `candidate' in
                                    ;; `consult-lean--lookup' to not be
                                    ;; updated.  It is unchanged after the
                                    ;; command is first launched.
                                    (consult--async-throttle)
                                    (consult--async-split))
                      :prompt "Definition: "
                      :require-match t
                      :history consult-lean--definitions-history
                      :category 'lean-symbols
                      :annotate #'consult-lean--definitions-annotate-candidate
                      :lookup #'consult-lean--lookup)))
    (apply 'lean-find-definition-cont
           user-choice)))

;;;###autoload
(defun consult-lean-hook ()
  "Set up helm-lean for current buffer."
  (local-set-key consult-lean-keybinding-helm-lean-definitions #'consult-lean-definitions))

;;;###autoload
(add-hook 'lean-mode-hook #'consult-lean-hook)

(provide 'consult-lean)
;;; consult-lean.el ends here
