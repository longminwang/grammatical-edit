;;; grammatical-edit.el --- Grammatical object edit package

;; Filename: grammatical-edit.el
;; Description: Grammatical object edit package
;; Author: Andy Stewart <lazycat.manatee@gmail.com>
;; Maintainer: Andy Stewart <lazycat.manatee@gmail.com>
;; Copyright (C) 2021, Andy Stewart, all rights reserved.
;; Created: 2021-11-25 21:24:03
;; Version: 0.1
;; Last-Updated: 2021-11-25 21:24:03
;;           By: Andy Stewart
;; URL: https://www.github.org/manateelazycat/grammatical-edit
;; Keywords:
;; Compatibility: GNU Emacs 29.0.50
;;
;; Features that might be required by this library:
;;
;;
;;

;;; This file is NOT part of GNU Emacs

;;; License
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:
;;
;; Grammatical object edit package
;;

;;; Installation:
;;
;; Put grammatical-edit.el to your load-path.
;; The load-path is usually ~/elisp/.
;; It's set in your ~/.emacs like this:
;; (add-to-list 'load-path (expand-file-name "~/elisp"))
;;
;; And the following to your ~/.emacs startup file.
;;
;; (require 'grammatical-edit)
;;
;; No need more.

;;; Customize:
;;
;;
;;
;; All of the above can customize by:
;;      M-x customize-group RET grammatical-edit RET
;;

;;; Change log:
;;
;; 2021/11/25
;;      * First released.
;;

;;; Acknowledgements:
;;
;;
;;

;;; TODO
;;
;;
;;

;;; Require
(require 'subr-x)
(require 'thingatpt)

;;; Code:

(defvar grammatical-edit-mode-map (make-sparse-keymap)
  "Keymap for the grammatical-edit minor mode.")

;;;###autoload
(define-minor-mode grammatical-edit-mode
  "Minor mode for auto parenthesis pairing with syntax table.
\\<grammatical-edit-mode-map>"
  :group 'grammatical-edit)

(defmacro grammatical-edit-ignore-errors (body)
  `(ignore-errors
     ,body
     t))

;;;;;;;;;;;;;;;;; Interactive functions ;;;;;;;;;;;;;;;;;;;;;;

(defun grammatical-edit-open-round ()
  (interactive)
  (cond
   ((region-active-p)
    (grammatical-edit-wrap-round))
   ((and (grammatical-edit-in-string-p)
         (derived-mode-p 'js-mode))
    (insert "()")
    (backward-char))
   ((or (grammatical-edit-in-string-p)
        (grammatical-edit-in-comment-p))
    (insert "("))
   (t
    (insert "()")
    (backward-char))
   ))

(defun grammatical-edit-open-curly ()
  (interactive)
  (cond
   ((region-active-p)
    (grammatical-edit-wrap-curly))
   ((and (grammatical-edit-in-string-p)
         (derived-mode-p 'js-mode))
    (insert "{}")
    (backward-char))
   ((or (grammatical-edit-in-string-p)
        (grammatical-edit-in-comment-p))
    (insert "{"))
   (t
    (cond ((derived-mode-p 'ruby-mode)
           (insert "{  }")
           (backward-char 2))
          (t
           (insert "{}")
           (backward-char)))
    )
   ))

(defun grammatical-edit-open-bracket ()
  (interactive)
  (cond
   ((region-active-p)
    (grammatical-edit-wrap-bracket))
   ((and (grammatical-edit-in-string-p)
         (derived-mode-p 'js-mode))
    (insert "[]")
    (backward-char))
   ((or (grammatical-edit-in-string-p)
        (grammatical-edit-in-comment-p))
    (insert "["))
   (t
    (insert "[]")
    (backward-char))
   ))

(defun grammatical-edit-fix-unbalanced-parentheses ()
  (interactive)
  (let ((close (grammatical-edit-missing-close)))
    (if close
        (cond ((eq ?\) (matching-paren close))
               (insert ")"))
              ((eq ?\} (matching-paren close))
               (insert "}"))
              ((eq ?\] (matching-paren close))
               (insert "]")))
      (up-list))))

(defun grammatical-edit-close-round ()
  (interactive)
  (cond ((or (grammatical-edit-in-string-p)
             (grammatical-edit-in-comment-p))
         (insert ")"))
        ;; Insert ) directly in sh-mode for case ... in syntax.
        ((or
          (derived-mode-p 'sh-mode)
          (derived-mode-p 'markdown-mode))
         (insert ")"))
        (t
         (grammatical-edit-fix-unbalanced-parentheses))))

(defun grammatical-edit-close-curly ()
  (interactive)
  (cond ((or (grammatical-edit-in-string-p)
             (grammatical-edit-in-comment-p))
         (insert "}"))
        (t
         (grammatical-edit-fix-unbalanced-parentheses))))

(defun grammatical-edit-close-bracket ()
  (interactive)
  (cond ((or (grammatical-edit-in-string-p)
             (grammatical-edit-in-comment-p))
         (insert "]"))
        (t
         (grammatical-edit-fix-unbalanced-parentheses))))

(defun grammatical-edit-double-quote ()
  (interactive)
  (cond ((region-active-p)
         (grammatical-edit-wrap-double-quote))
        ((grammatical-edit-in-string-p)
         (cond
          ((and (derived-mode-p 'python-mode)
                (and (eq (char-before) ?\") (eq (char-after) ?\")))
           (insert "\"\"")
           (backward-char))
          ;; When current mode is golang.
          ;; Don't insert \" in string that wrap by `...`
          ((and (derived-mode-p 'go-mode)
                (equal (save-excursion (nth 3 (grammatical-edit-current-parse-state))) 96))
           (insert "\""))
          (t
           (insert "\\\""))))
        ((grammatical-edit-in-comment-p)
         (insert "\""))
        (t
         (insert "\"\"")
         (backward-char))
        ))

(defun grammatical-edit-space (arg)
  "Wrap space around cursor if cursor in blank parenthesis.

input: {|} (press <SPACE> at |)
output: { | }

input: [|] (press <SPACE> at |)
output: [ | ]
"
  (interactive "p")
  (if (> arg 1)
      (self-insert-command arg)
    (cond ((or (grammatical-edit-in-comment-p)
               (grammatical-edit-in-string-p))
           (insert " "))
          ((or (and (equal (char-after) ?\} )
                    (equal (char-before) ?\{ ))
               (and (equal (char-after) ?\] )
                    (equal (char-before) ?\[ )))
           (insert "  ")
           (backward-char 1))
          (t
           (insert " ")))))

(defun grammatical-edit-match-paren (arg)
  "Go to the matching parenthesis if on parenthesis, otherwise insert %."
  (interactive "p")
  (cond ((or (grammatical-edit-in-comment-p)
             (grammatical-edit-in-string-p))
         (self-insert-command (or arg 1)))
        ((looking-at "\\s\(\\|\\s\{\\|\\s\[")
         (forward-list))
        ((looking-back "\\s\)\\|\\s\}\\|\\s\\]")
         (backward-list))
        (t
         (cond
          ;; Enhancement the automatic jump of web-mode.
          ((derived-mode-p 'web-mode)
           (grammatical-edit-web-mode-match-paren))
          (t
           (self-insert-command (or arg 1))))
         )))

(defun grammatical-edit-web-mode-match-paren ()
  (require 'sgml-mode)
  (cond ((looking-at "<")
         (sgml-skip-tag-forward 1))
        ((looking-back ">")
         (sgml-skip-tag-backward 1))
        (t (self-insert-command (or arg 1)))))

(defun grammatical-edit-backward-delete ()
  (interactive)
  (cond ((grammatical-edit-in-string-p)
         (grammatical-edit-backward-delete-in-string))
        ((grammatical-edit-in-comment-p)
         (backward-delete-char 1))
        ((grammatical-edit-after-close-pair-p)
         (if (and (derived-mode-p 'sh-mode)
                  (eq ?\) (char-before)))
             (delete-char -1)
           (grammatical-edit-backward-movein-or-delete-close-pair)))
        ((grammatical-edit-in-empty-pair-p)
         (grammatical-edit-backward-delete-in-pair))
        ((not (grammatical-edit-after-open-pair-p))
         (backward-delete-char 1))
        ))

(defun grammatical-edit-forward-delete ()
  (interactive)
  (cond ((grammatical-edit-in-string-p)
         (grammatical-edit-forward-delete-in-string))
        ((grammatical-edit-in-comment-p)
         (delete-char 1))
        ((grammatical-edit-before-open-pair-p)
         (grammatical-edit-forward-movein-or-delete-open-pair))
        ((grammatical-edit-in-empty-pair-p)
         (grammatical-edit-backward-delete-in-pair))
        ((and (derived-mode-p 'sh-mode)
              (grammatical-edit-before-close-pair-p)
              (eq ?\) (char-after)))
         (delete-char 1))
        ((not (grammatical-edit-before-close-pair-p))
         (delete-char 1))
        ))

(defun grammatical-edit-kill ()
  "Intelligent soft kill.

When inside of code, kill forward S-expressions on the line, but respecting delimeters.
When in a string, kill to the end of the string.
When in comment, kill to the end of the line."
  (interactive)
  (cond ((derived-mode-p 'web-mode)
         (grammatical-edit-web-mode-kill))
        ((derived-mode-p 'ruby-mode)
         (grammatical-edit-ruby-mode-kill))
        (t
         (grammatical-edit-common-mode-kill))))

(defun grammatical-edit-backward-kill ()
  "Intelligent soft kill.
When inside of code, kill backward S-expressions on the line, but respecting delimiters.
When in a string, kill to the beginning of the string.
When in comment, kill to the beginning of the line."
  (interactive)
  (cond ((derived-mode-p 'web-mode)
         (grammatical-edit-web-mode-backward-kill))
        ((derived-mode-p 'ruby-mode)
         (grammatical-edit-ruby-mode-backward-kill))
        (t
         (grammatical-edit-common-mode-backward-kill))))

(defun grammatical-edit-wrap-round ()
  (interactive)
  (cond
   ;; If in *.Vue file
   ;; In template area, call `grammatical-edit-web-mode-element-wrap'
   ;; Otherwise, call `grammatical-edit-wrap-round-pair'
   ((and (buffer-file-name) (string-equal (file-name-extension (buffer-file-name)) "vue"))
    (if (grammatical-edit-vue-in-template-area)
        (grammatical-edit-web-mode-element-wrap)
      (grammatical-edit-wrap-round-pair)))
   ;; If is `web-mode' but not in *.Vue file, call `grammatical-edit-web-mode-element-wrap'
   ((derived-mode-p 'web-mode)
    (if (grammatical-edit-in-script-area)
        (grammatical-edit-wrap-round-pair)
      (grammatical-edit-web-mode-element-wrap)))
   ;; Otherwise call `grammatical-edit-wrap-round-pair'
   (t
    (grammatical-edit-wrap-round-pair))
   ))

(defun grammatical-edit-wrap-round-pair ()
  (cond ((region-active-p)
         (grammatical-edit-wrap-region "(" ")"))
        ((grammatical-edit-in-string-p)
         (let ((string-bound (grammatical-edit-string-start+end-points)))
           (grammatical-edit-wrap (car string-bound) (1+ (cdr string-bound))
                                  "(" ")")))
        ((grammatical-edit-in-comment-p)
         (grammatical-edit-wrap (beginning-of-thing 'symbol) (end-of-thing 'symbol)
                                "(" ")"))
        (t
         (grammatical-edit-wrap (beginning-of-thing 'sexp) (end-of-thing 'sexp)
                                "(" ")")))
  ;; Indent wrap area.
  (grammatical-edit-indent-parenthesis-area)
  ;; Jump to internal parenthesis start position.
  (up-list)
  (grammatical-edit-match-paren 1)
  (forward-char)
  )

(defun grammatical-edit-wrap-bracket ()
  (interactive)
  (cond ((region-active-p)
         (grammatical-edit-wrap-region "[" "]"))
        ((grammatical-edit-in-string-p)
         (let ((string-bound (grammatical-edit-string-start+end-points)))
           (grammatical-edit-wrap (car string-bound) (1+ (cdr string-bound))
                                  "[" "]")))
        ((grammatical-edit-in-comment-p)
         (grammatical-edit-wrap (beginning-of-thing 'symbol) (end-of-thing 'symbol)
                                "[" "]"))
        (t
         (grammatical-edit-wrap (beginning-of-thing 'sexp) (end-of-thing 'sexp)
                                "[" "]")))
  ;; Indent wrap area.
  (grammatical-edit-indent-parenthesis-area)
  ;; Jump to internal parenthesis start position.
  (up-list)
  (grammatical-edit-match-paren 1)
  (forward-char))

(defun grammatical-edit-wrap-curly ()
  (interactive)
  (cond ((region-active-p)
         (grammatical-edit-wrap-region "{" "}"))
        ((grammatical-edit-in-string-p)
         (let ((string-bound (grammatical-edit-string-start+end-points)))
           (grammatical-edit-wrap (car string-bound) (1+ (cdr string-bound))
                                  "{" "}")))
        ((grammatical-edit-in-comment-p)
         (grammatical-edit-wrap (beginning-of-thing 'symbol) (end-of-thing 'symbol)
                                "{" "}"))
        (t
         (grammatical-edit-wrap (beginning-of-thing 'sexp) (end-of-thing 'sexp)
                                "{" "}")))
  ;; Forward to jump in parenthesis.
  (forward-char))

(defun grammatical-edit-wrap-double-quote ()
  (interactive)
  (cond ((and (region-active-p)
              (grammatical-edit-in-string-p))
         (cond ((and (derived-mode-p 'go-mode)
                     (equal (save-excursion (nth 3 (grammatical-edit-current-parse-state))) 96))
                (grammatical-edit-wrap-region "\"" "\""))
               (t
                (grammatical-edit-wrap-region "\\\"" "\\\""))))
        ((region-active-p)
         (grammatical-edit-wrap-region "\"" "\""))
        ((grammatical-edit-in-string-p)
         (goto-char (1+ (cdr (grammatical-edit-string-start+end-points)))))
        ((grammatical-edit-in-comment-p)
         (grammatical-edit-wrap (beginning-of-thing 'symbol) (end-of-thing 'symbol)
                                "\"" "\""))
        (t
         (grammatical-edit-wrap (beginning-of-thing 'sexp) (end-of-thing 'sexp)
                                "\"" "\"")))
  ;; Forward to jump in parenthesis.
  (forward-char))

(defun grammatical-edit-unwrap (&optional argument)
  (interactive "P")
  (cond ((derived-mode-p 'web-mode)
         (grammatical-edit-web-mode-element-unwrap))
        ((grammatical-edit-in-string-p)
         (grammatical-edit-splice-string argument))
        (t
         (save-excursion
           (grammatical-edit-kill-surrounding-sexps-for-splice argument)
           (backward-up-list)
           (save-excursion
             (forward-sexp)
             (backward-delete-char 1))
           (delete-char 1)
           ;; Try to indent parent expression after unwrap pair.
           ;; This feature just enable in lisp-like language.
           (when (or
                  (derived-mode-p 'lisp-mode)
                  (derived-mode-p 'emacs-lisp-mode))
             (ignore-errors
               (backward-up-list)
               (indent-sexp)))))))

(defun grammatical-edit-jump-out-pair-and-newline ()
  (interactive)
  (cond ((grammatical-edit-in-string-p)
         (goto-char (1+ (cdr (grammatical-edit-string-start+end-points))))
         (newline-and-indent))
        (t
         ;; Just do when have `up-list' in next step.
         (if (grammatical-edit-ignore-errors (save-excursion (up-list)))
             (let (up-list-point)
               (if (grammatical-edit-is-blank-line-p)
                   ;; Clean current line first if current line is blank line.
                   (grammatical-edit-kill-current-line)
                 ;; Move out of current parentheses and newline.
                 (up-list)
                 (setq up-list-point (point))
                 (newline-and-indent)
                 ;; Try to clean unnecessary whitespace before close parenthesis.
                 ;; This feature just enable in lisp-like language.
                 (when (or
                        (derived-mode-p 'lisp-mode)
                        (derived-mode-p 'emacs-lisp-mode))
                   (save-excursion
                     (goto-char up-list-point)
                     (backward-char)
                     (when (grammatical-edit-only-whitespaces-before-cursor-p)
                       (grammatical-edit-delete-whitespace-around-cursor))))))
           ;; Try to clean blank line if no pair can jump out.
           (if (grammatical-edit-is-blank-line-p)
               (grammatical-edit-kill-current-line))))))

(defun grammatical-edit-is-named-node (node)
  "Check if the NODE is not a named node."
  (and (tsc-node-p node) (not (tsc-node-named-p node))))

(defun grammatical-edit-jump-left ()
  (interactive)
  (goto-char (tsc-node-start-position (tsc-get-prev-named-sibling (tree-sitter-node-at-point)))))

(defun grammatical-edit-jump-right ()
  (interactive)
  (let* ((current-node (tree-sitter-node-at-point))
         (next-node (tsc-get-next-sibling current-node))
         (current-node-text (tsc-node-text current-node)))
    (cond ((looking-at "\\s-+")
           (search-forward-regexp "\\s-+" nil t))
          ((eolp)
           (next-line 1)
           (beginning-of-line)
           (search-forward-regexp "\\s-+" nil t))
          ((> (length current-node-text) 0)
           (forward-char (length current-node-text)))
          (next-node
           (goto-char (tsc-node-end-position next-node)))
          )))

(defun grammatical-edit-delete-whitespace-before-cursor ()
  (kill-region (save-excursion
                 (search-backward-regexp "[^ \t\n]" nil t)
                 (forward-char)
                 (point))
               (point)))

(defun grammatical-edit-delete-whitespace-around-cursor ()
  (kill-region (save-excursion
                 (search-backward-regexp "[^ \t\n]" nil t)
                 (forward-char)
                 (point))
               (save-excursion
                 (search-forward-regexp "[^ \t\n]" nil t)
                 (backward-char)
                 (point))))

(defun grammatical-edit-kill-current-line ()
  (kill-region (beginning-of-thing 'line) (end-of-thing 'line))
  (back-to-indentation))

(defun grammatical-edit-missing-close ()
  (let ((start-point (point))
        open)
    (save-excursion
      ;; Get open tag.
      (backward-up-list)
      (setq open (char-after))

      ;; Jump to start position and use `check-parens' check unbalance paren.
      (goto-char start-point)
      (ignore-errors
        (check-parens))

      ;; Return missing tag if point change after `check-parens'
      ;; Otherwhere return nil.
      (if (equal start-point (point))
          nil
        open)
      )))

(defun grammatical-edit-backward-delete-in-pair ()
  (backward-delete-char 1)
  (delete-char 1))

(defun grammatical-edit-backward-movein-or-delete-close-pair ()
  (if (grammatical-edit-ignore-errors (save-excursion (backward-sexp)))
      (backward-char)
    (backward-delete-char 1)))

(defun grammatical-edit-forward-movein-or-delete-open-pair ()
  (if (grammatical-edit-ignore-errors (save-excursion (forward-sexp)))
      (forward-char)
    (delete-char 1)))

(defun grammatical-edit-backward-delete-in-string ()
  (let ((start+end (grammatical-edit-string-start+end-points)))
    (cond
     ;; Some language, such as Python, `grammatical-edit-string-start+end-points' will return nil cause by `beginning-of-defun' retun nil.
     ;; This logical branch is handle this.
     ((not start+end)
      ;; First determine if it is in the string area?
      (when (grammatical-edit-in-string-p)
        (let ((syn-before (char-syntax (char-before)))
              (syn-after  (char-syntax (char-after))))
          (cond
           ;; Remove double quotes when the string is empty
           ((and (eq syn-before ?\" )
                 (eq syn-after  ?\" ))
            (backward-delete-char 1)
            (delete-char 1))
           ;; If there is still content in the string and the double quotation marks are in front of the cursor,
           ;; no delete operation is performed.
           ((eq syn-before ?\" ))
           ;; If the cursor is not double quotes before and after, delete the previous character.
           (t
            (backward-delete-char 1))))))
     ((not (eq (1- (point)) (car start+end)))
      (if (grammatical-edit-in-string-escape-p)
          (delete-char 1))
      (backward-delete-char 1)
      (if (grammatical-edit-in-string-escape-p)
          (backward-delete-char 1)))
     ((eq (point) (cdr start+end))
      (backward-delete-char 1)
      (delete-char 1)))))

(defun grammatical-edit-forward-delete-in-string ()
  (let ((start+end (grammatical-edit-string-start+end-points)))
    (cond
     ;; Some language, such as Python, `grammatical-edit-string-start+end-points' will return nil cause by `beginning-of-defun' retun nil.
     ;; This logical branch is handle this.
     ((not start+end)
      ;; First determine if it is in the string area?
      (when (grammatical-edit-in-string-p)
        (let ((syn-before (char-syntax (char-before)))
              (syn-after  (char-syntax (char-after))))
          (cond
           ;; Remove double quotes when the string is empty
           ((and (eq syn-before ?\" )
                 (eq syn-after  ?\" ))
            (backward-delete-char 1)
            (delete-char 1))
           ;; If there is still content in the string and the double quotation marks are after of the cursor,
           ;; no delete operation is performed.
           ((eq syn-after ?\" ))
           ;; If the cursor is not double quotes before and after, delete the previous character.
           (t
            (delete-char 1))))))
     ((not (eq (point) (cdr start+end)))
      (cond ((grammatical-edit-in-string-escape-p)
             (delete-char -1))
            ((eq (char-after) ?\\ )
             (delete-char +1)))
      (delete-char +1))
     ((eq (1- (point)) (car start+end))
      (delete-char -1)
      (delete-char +1)))))

(defun grammatical-edit-splice-string (argument)
  (let ((original-point (point))
        (start+end (grammatical-edit-string-start+end-points)))
    (let ((start (car start+end))
          (end (cdr start+end)))
      (let* ((escaped-string
              (cond ((not (consp argument))
                     (buffer-substring (1+ start) end))
                    ((= 4 (car argument))
                     (buffer-substring original-point end))
                    (t
                     (buffer-substring (1+ start) original-point))))
             (unescaped-string
              (grammatical-edit-unescape-string escaped-string)))
        (if (not unescaped-string)
            (error "Unspliceable string.")
          (save-excursion
            (goto-char start)
            (delete-region start (1+ end))
            (insert unescaped-string))
          (if (not (and (consp argument)
                        (= 4 (car argument))))
              (goto-char (- original-point 1))))))))

(defun grammatical-edit-point-at-sexp-start ()
  (save-excursion
    (forward-sexp)
    (backward-sexp)
    (point)))

(defun grammatical-edit-point-at-sexp-end ()
  (save-excursion
    (backward-sexp)
    (forward-sexp)
    (point)))

(defun grammatical-edit-point-at-sexp-boundary (n)
  (cond ((< n 0) (grammatical-edit-point-at-sexp-start))
        ((= n 0) (point))
        ((> n 0) (grammatical-edit-point-at-sexp-end))))

(defun grammatical-edit-kill-surrounding-sexps-for-splice (argument)
  (cond ((or (grammatical-edit-in-string-p)
             (grammatical-edit-in-comment-p))
         (error "Invalid context for splicing S-expressions."))
        ((or (not argument) (eq argument 0)) nil)
        ((or (numberp argument) (eq argument '-))
         (let* ((argument (if (eq argument '-) -1 argument))
                (saved (grammatical-edit-point-at-sexp-boundary (- argument))))
           (goto-char saved)
           (ignore-errors (backward-sexp argument))
           (grammatical-edit-hack-kill-region saved (point))))
        ((consp argument)
         (let ((v (car argument)))
           (if (= v 4)
               (let ((end (point)))
                 (ignore-errors
                   (while (not (bobp))
                     (backward-sexp)))
                 (grammatical-edit-hack-kill-region (point) end))
             (let ((beginning (point)))
               (ignore-errors
                 (while (not (eobp))
                   (forward-sexp)))
               (grammatical-edit-hack-kill-region beginning (point))))))
        (t (error "Bizarre prefix argument `%s'." argument))))

(defun grammatical-edit-unescape-string (string)
  (with-temp-buffer
    (insert string)
    (goto-char (point-min))
    (while (and (not (eobp))
                (search-forward "\\" nil t))
      (delete-char -1)
      (forward-char))
    (condition-case condition
        (progn (check-parens) (buffer-string))
      (error nil))))

(defun grammatical-edit-hack-kill-region (start end)
  (let ((this-command nil)
        (last-command nil))
    (kill-region start end)))

(defun grammatical-edit-kill-internal ()
  (cond (current-prefix-arg
         (kill-line (if (integerp current-prefix-arg)
                        current-prefix-arg
                      1)))
        ((grammatical-edit-in-string-p)
         (grammatical-edit-kill-line-in-string))
        ((grammatical-edit-in-single-quote-string-p)
         (grammatical-edit-kill-line-in-single-quote-string))
        ((or (grammatical-edit-in-comment-p)
             (save-excursion
               (grammatical-edit-skip-whitespace t (point-at-eol))
               (or (eq (char-after) ?\; )
                   (eolp))))
         (kill-line))
        (t (grammatical-edit-kill-sexps-on-line))))

(defun grammatical-edit-backward-kill-internal ()
  (cond (current-prefix-arg
         (kill-line (if (integerp current-prefix-arg)
                        current-prefix-arg
                      1)))
        ((grammatical-edit-in-string-p)
         (grammatical-edit-kill-line-backward-in-string))
        ((grammatical-edit-in-single-quote-string-p)
         (grammatical-edit-kill-line-backward-in-single-quote-string))
        ((or (grammatical-edit-in-comment-p)
             (save-excursion
               (grammatical-edit-skip-whitespace nil (point-at-bol))
               (bolp)))
         (if (bolp) (grammatical-edit-backward-delete)
           (kill-line 0)))
        (t (grammatical-edit-kill-sexps-backward-on-line))))

(defun grammatical-edit-kill-line-in-single-quote-string ()
  (let ((sexp-end (save-excursion
                    (forward-sexp)
                    (backward-char)
                    (point))))
    (kill-region (point) sexp-end)))

(defun grammatical-edit-kill-line-backward-in-single-quote-string ()
  (let ((sexp-beg (save-excursion
                    (backward-sexp)
                    (forward-char)
                    (point))))
    (kill-region sexp-beg (point))))

(defun grammatical-edit-kill-line-in-string ()
  (cond ((save-excursion
           (grammatical-edit-skip-whitespace t (point-at-eol))
           (eolp))
         (kill-line))
        (t
         (save-excursion
           (if (grammatical-edit-in-string-escape-p)
               (backward-char))
           (let ((beginning (point)))
             (while (save-excursion
                      (forward-char)
                      (grammatical-edit-in-string-p))
               (forward-char))
             (kill-region beginning (point)))
           ))))

(defun grammatical-edit-kill-line-backward-in-string ()
  (cond ((save-excursion
           (grammatical-edit-skip-whitespace nil (point-at-bol))
           (bolp))
         (kill-line))
        (t
         (save-excursion
           (if (grammatical-edit-in-string-escape-p)
               (forward-char))
           (let ((beginning (point)))
             (while (save-excursion
                      (backward-char)
                      (grammatical-edit-in-string-p))
               (backward-char))
             (kill-region (point) beginning))
           ))))

(defun grammatical-edit-skip-whitespace (trailing-p &optional limit)
  (funcall (if trailing-p 'skip-chars-forward 'skip-chars-backward)
           " \t\n"
           limit))

(defun grammatical-edit-kill-sexps-on-line ()
  (if (grammatical-edit-in-char-p)
      (backward-char 2))
  (let ((beginning (point))
        (eol (point-at-eol)))
    (let ((end-of-list-p (grammatical-edit-forward-sexps-to-kill beginning eol)))
      (if end-of-list-p (progn (up-list) (backward-char)))
      (if kill-whole-line
          (grammatical-edit-kill-sexps-on-whole-line beginning)
        (kill-region beginning
                     (if (and (not end-of-list-p)
                              (eq (point-at-eol) eol))
                         eol
                       (point)))))))

(defun grammatical-edit-kill-sexps-backward-on-line ()
  (if (grammatical-edit-in-char-p)
      (forward-char 1))
  (let ((beginning (point))
        (bol (point-at-bol)))
    (let ((beg-of-list-p (grammatical-edit-backward-sexps-to-kill beginning bol)))
      (if beg-of-list-p (progn (up-list -1) (forward-char)))
      (if kill-whole-line
          (grammatical-edit-kill-sexps-on-whole-line beginning)
        (kill-region (if (and (not beg-of-list-p)
                              (eq (point-at-bol) bol))
                         bol
                       (point))
                     beginning)))))

(defun grammatical-edit-forward-sexps-to-kill (beginning eol)
  (let ((end-of-list-p nil)
        (firstp t))
    (catch 'return
      (while t
        (if (and kill-whole-line (eobp)) (throw 'return nil))
        (save-excursion
          (unless (grammatical-edit-ignore-errors (forward-sexp))
            (if (grammatical-edit-ignore-errors (up-list))
                (progn
                  (setq end-of-list-p (eq (point-at-eol) eol))
                  (throw 'return nil))))
          (if (or (and (not firstp)
                       (not kill-whole-line)
                       (eobp))
                  (not (grammatical-edit-ignore-errors (backward-sexp)))
                  (not (eq (point-at-eol) eol)))
              (throw 'return nil)))
        (forward-sexp)
        (if (and firstp
                 (not kill-whole-line)
                 (eobp))
            (throw 'return nil))
        (setq firstp nil)))
    end-of-list-p))

(defun grammatical-edit-backward-sexps-to-kill (beginning bol)
  (let ((beg-of-list-p nil)
        (lastp t))
    (catch 'return
      (while t
        (if (and kill-whole-line (bobp)) (throw 'return nil))
        (save-excursion
          (unless (grammatical-edit-ignore-errors (backward-sexp))
            (if (grammatical-edit-ignore-errors (up-list -1))
                (progn
                  (setq beg-of-list-p (eq (point-at-bol) bol))
                  (throw 'return nil))))
          (if (or (and (not lastp)
                       (not kill-whole-line)
                       (bobp))
                  (not (grammatical-edit-ignore-errors (forward-sexp)))
                  (not (eq (point-at-bol) bol)))
              (throw 'return nil)))
        (backward-sexp)
        (if (and lastp
                 (not kill-whole-line)
                 (bobp))
            (throw 'return nil))
        (setq lastp nil)))
    beg-of-list-p))

(defun grammatical-edit-kill-sexps-on-whole-line (beginning)
  (kill-region beginning
               (or (save-excursion
                     (grammatical-edit-skip-whitespace t)
                     (and (not (eq (char-after) ?\; ))
                          (point)))
                   (point-at-eol)))
  (cond ((save-excursion (grammatical-edit-skip-whitespace nil (point-at-bol))
                         (bolp))
         (lisp-indent-line))
        ((eobp) nil)
        ((let ((syn-before (char-syntax (char-before)))
               (syn-after  (char-syntax (char-after))))
           (or (and (eq syn-before ?\) )
                    (eq syn-after  ?\( ))
               (and (eq syn-before ?\" )
                    (eq syn-after  ?\" ))
               (and (memq syn-before '(?_ ?w))
                    (memq syn-after  '(?_ ?w)))))
         (insert " "))))

(defun grammatical-edit-common-mode-kill ()
  (if (grammatical-edit-is-blank-line-p)
      (grammatical-edit-kill-blank-line-and-reindent)
    (grammatical-edit-kill-internal)))

(defun grammatical-edit-common-mode-backward-kill ()
  (if (grammatical-edit-is-blank-line-p)
      (grammatical-edit-ignore-errors
       (progn
         (grammatical-edit-kill-blank-line-and-reindent)
         (forward-line -1)
         (end-of-line)))
    (grammatical-edit-backward-kill-internal)))

(defun grammatical-edit-web-mode-kill ()
  "It's a smarter kill function for `web-mode'."
  (if (grammatical-edit-is-blank-line-p)
      (grammatical-edit-kill-blank-line-and-reindent)
    (cond
     ;; Kill all content wrap by <% ... %> when right is <%
     ((and (looking-at "<%")
           (save-excursion (search-forward-regexp "%>" nil t)))
      (kill-region (point) (search-forward-regexp "%>" nil t)))
     ;; Kill content in {{ }} if left is {{.
     ((and (looking-back "{{\\s-?")
           (save-excursion (search-forward-regexp "\\s-?}}")))
      (let ((start (save-excursion
                     (search-backward-regexp "{{\\s-?" nil t)
                     (forward-char 2)
                     (point)))
            (end (save-excursion
                   (search-forward-regexp "\\s-?}}" nil t)
                   (backward-char 2)
                   (point))))
        (kill-region start end)))
     ;; Kill content in <% ... %> if left is <% or <%=
     ((and (looking-back "<%=?\\s-?")
           (save-excursion (search-forward-regexp "%>" nil t)))
      (let ((start (point))
            (end (progn
                   (search-forward-regexp "%>" nil t)
                   (backward-char 2)
                   (point)
                   )))
        (kill-region start end)))
     ;; Kill string if current pointer in string area.
     ((grammatical-edit-in-string-p)
      (grammatical-edit-kill-internal))
     ;; Kill string in single quote.
     ((grammatical-edit-in-single-quote-string-p)
      (grammatical-edit-kill-line-in-single-quote-string))
     ;; Kill element if no attributes in tag.
     ((and
       (looking-at "\\s-?+</")
       (looking-back "<[a-z]+\\s-?>\\s-?+"))
      (web-mode-element-kill 1))
     ;; Kill whitespace in tag.
     ((looking-at "\\s-+>")
      (search-forward-regexp ">" nil t)
      (backward-char)
      (grammatical-edit-delete-whitespace-before-cursor))
     ;; Jump in content if point in start tag.
     ((and (looking-at ">")
           (looking-back "<[a-z]+"))
      (forward-char 1))
     ;; Kill tag if in end tag.
     ((and (looking-at ">")
           (looking-back "</[a-z]+"))
      (beginning-of-thing 'sexp)
      (web-mode-element-kill 1))
     ;; Kill attributes if point in attributes area.
     ((and
       (web-mode-attribute-beginning-position)
       (web-mode-attribute-end-position)
       (>= (point) (web-mode-attribute-beginning-position))
       (<= (point) (web-mode-attribute-end-position)))
      (web-mode-attribute-kill))
     ;; Kill attributes if only space between point and attributes start.
     ((and
       (looking-at "\\s-+")
       (save-excursion
         (search-forward-regexp "\\s-+" nil t)
         (equal (point) (web-mode-attribute-beginning-position))))
      (search-forward-regexp "\\s-+")
      (web-mode-attribute-kill))
     ;; Kill line if rest chars is whitespace.
     ((looking-at "\\s-?+\n")
      (kill-line))
     ;; Kill region if mark is active.
     (mark-active
      (kill-region (region-beginning) (region-end)))
     ;; Try to kill element if cursor in attribute area.
     ((grammatical-edit-in-attribute-p)
      ;; Don't kill rest string if cursor position at end tag before.
      (when (equal (point)
                   (save-excursion
                     (web-mode-tag-end)
                     (point)))
        (kill-region (point) (progn
                               (web-mode-tag-match)
                               (point)))))
     (t
      (unless (grammatical-edit-ignore-errors
               ;; Kill all sexps in current line.
               (grammatical-edit-kill-sexps-on-line))
        ;; Kill block if sexp parse failed.
        (web-mode-block-kill))))))


(defun grammatical-edit-in-attribute-p ()
  "Return non-nil if cursor in attribute area."
  (save-mark-and-excursion
    (web-mode-attribute-select)
    mark-active
    ))

(defun grammatical-edit-web-mode-backward-kill ()
  (message "Backward kill in web-mode is currently not implemented."))

(defun grammatical-edit-ruby-mode-kill ()
  "It's a smarter kill function for `ruby-mode'.

If current line is blank line, re-indent line after kill whole line.

If current line is not blank, do `grammatical-edit-kill' first, re-indent line if rest line start with ruby keywords.
"
  (if (grammatical-edit-is-blank-line-p)
      (grammatical-edit-kill-blank-line-and-reindent)
    ;; Do `grammatical-edit-kill' first.
    (grammatical-edit-kill-internal)

    ;; Re-indent current line if line start with ruby keywords.
    (when (let (in-beginning-block-p
                in-end-block-p
                current-symbol)
            (save-excursion
              (back-to-indentation)
              (ignore-errors (setq current-symbol (buffer-substring-no-properties (beginning-of-thing 'symbol) (end-of-thing 'symbol))))
              (setq in-beginning-block-p (member current-symbol '("class" "module" "else" "def" "if" "unless" "case" "while" "until" "for" "begin" "do")))
              (setq in-end-block-p (member current-symbol '("end")))

              (or in-beginning-block-p in-end-block-p)))
      (indent-for-tab-command))))

(defun grammatical-edit-ruby-mode-backward-kill ()
  "It's a smarter kill function for `ruby-mode'.

If current line is blank line, re-indent line after kill whole line.

If current line is not blank, do `grammatical-edit-backward-kill' first, re-indent line if rest line start with ruby keywords.
"
  (if (grammatical-edit-is-blank-line-p)
      (grammatical-edit-ignore-errors
       (progn
         (grammatical-edit-kill-blank-line-and-reindent)
         (forward-line -1)
         (end-of-line)))
    ;; Do `grammatical-edit-kill' first.
    (grammatical-edit-backward-kill-internal)

    ;; Re-indent current line if line start with ruby keywords.
    (when (let (in-beginning-block-p
                in-end-block-p
                current-symbol)
            (save-excursion
              (back-to-indentation)
              (ignore-errors (setq current-symbol (buffer-substring-no-properties (beginning-of-thing 'symbol) (end-of-thing 'symbol))))
              (setq in-beginning-block-p (member current-symbol '("class" "module" "else" "def" "if" "unless" "case" "while" "until" "for" "begin" "do")))
              (setq in-end-block-p (member current-symbol '("end")))

              (or in-beginning-block-p in-end-block-p)))
      (indent-for-tab-command))))

(defun grammatical-edit-kill-blank-line-and-reindent ()
  (kill-region (beginning-of-thing 'line) (end-of-thing 'line))
  (back-to-indentation))

(defun grammatical-edit-indent-parenthesis-area ()
  (let ((bound-start (save-excursion
                       (backward-up-list)
                       (point)))
        (bound-end (save-excursion
                     (up-list)
                     (point)
                     )))
    (save-excursion
      (indent-region bound-start bound-end))))

(defun grammatical-edit-equal ()
  (interactive)
  (cond
   ((derived-mode-p 'web-mode)
    (cond ((or (grammatical-edit-in-string-p)
               (grammatical-edit-in-curly-p))
           (insert "="))
          ;; When edit *.vue file, just insert double quote after equal when point in template area.
          ((string-equal (file-name-extension (buffer-file-name)) "vue")
           (if (grammatical-edit-vue-in-template-area)
               (progn
                 (insert "=\"\"")
                 (backward-char 1))
             (insert "=")))
          ((grammatical-edit-in-script-area)
           (insert "="))
          (t
           (insert "=\"\"")
           (backward-char 1))))
   (t
    (insert "="))))

(defun grammatical-edit-in-script-area ()
  (and (save-excursion
         (search-backward-regexp "<script" nil t))
       (save-excursion
         (search-forward-regexp "</script>" nil t))))

(defun grammatical-edit-vue-in-template-area ()
  (and (save-excursion
         (search-backward-regexp "<template>" nil t))
       (save-excursion
         (search-forward-regexp "</template>" nil t))))

(defun grammatical-edit-web-mode-element-wrap ()
  "Like `web-mode-element-wrap', but jump after tag for continue edit."
  (interactive)
  (let (beg end pos tag beg-sep)
    ;; Insert tag pair around select area.
    (save-excursion
      (setq tag (read-from-minibuffer "Tag name? "))
      (setq pos (point))
      (cond
       (mark-active
        (setq beg (region-beginning))
        (setq end (region-end)))
       ((get-text-property pos 'tag-type)
        (setq beg (web-mode-element-beginning-position pos)
              end (1+ (web-mode-element-end-position pos))))
       ((setq beg (web-mode-element-parent-position pos))
        (setq end (1+ (web-mode-element-end-position pos)))))
      (when (and beg end (> end 0))
        (web-mode-insert-text-at-pos (concat "</" tag ">") end)
        (web-mode-insert-text-at-pos (concat "<" tag ">") beg)))

    (when (and beg end)
      ;; Insert return after start tag if have text after start tag.
      (setq beg-sep "")
      (goto-char (+ beg (length (concat "<" tag ">"))))
      (unless (looking-at "\\s-*$")
        (setq beg-sep "\n")
        (insert "\n"))

      ;; Insert return before end tag if have text before end tag.
      (goto-char (+ end (length (concat "<" tag ">")) (length beg-sep)))
      (unless (looking-back "^\\s-*")
        (insert "\n"))

      ;; Insert return after end tag if have text after end tag.
      (goto-char beg)
      (goto-char (+ 1 (web-mode-element-end-position (point))))
      (unless (looking-at "\\s-*$")
        (insert "\n"))

      ;; Indent tag area.
      (let ((indent-beg beg)
            (indent-end (save-excursion
                          (goto-char beg)
                          (+ 1 (web-mode-element-end-position (point)))
                          )))
        (indent-region indent-beg indent-end))

      ;; Jump to start tag, ready for insert tag attributes.
      (goto-char beg)
      (back-to-indentation)
      (forward-char (+ 1 (length tag)))
      )))

(defun grammatical-edit-web-mode-element-unwrap ()
  "Like `web-mode-element-vanish', but you don't need jump parent tag to unwrap.
Just like `paredit-splice-sexp+' style."
  (interactive)
  (save-excursion
    (web-mode-element-parent)
    (web-mode-element-vanish 1)
    (back-to-indentation)
    ))

;;;;;;;;;;;;;;;;; Utils functions ;;;;;;;;;;;;;;;;;;;;;;

(defun grammatical-edit-wrap (beg end a b)
  "Insert A at position BEG, and B after END. Save previous point position.

A and B are strings."
  (save-excursion
    (goto-char beg)
    (insert a)
    (goto-char (1+ end))
    (insert b))
  )

(defun grammatical-edit-wrap-region (a b)
  "When a region is active, insert A and B around it, and jump after A.

A and B are strings."
  (when (region-active-p)
    (let ((start (region-beginning))
          (end (region-end)))
      (setq mark-active nil)
      (goto-char start)
      (insert a)
      (goto-char (1+ end))
      (insert b)
      (goto-char (+ (length a) start)))))

(defun grammatical-edit-current-parse-state ()
  (let ((point (point)))
    (beginning-of-defun)
    (when (equal point (point))
      (beginning-of-line))
    (parse-partial-sexp (point) point)))

(defun grammatical-edit-string-start+end-points (&optional state)
  (ignore-errors
    (save-excursion
      (let ((start (nth 8 (or state (grammatical-edit-current-parse-state)))))
        (goto-char start)
        (forward-sexp 1)
        (cons start (1- (point)))))))

(defun grammatical-edit-after-open-pair-p ()
  (unless (bobp)
    (save-excursion
      (let ((syn (char-syntax (char-before))))
        (or (eq syn ?\()
            (and (eq syn ?_)
                 (eq (char-before) ?\{)))
        ))))

(defun grammatical-edit-after-close-pair-p ()
  (unless (bobp)
    (save-excursion
      (let ((syn (char-syntax (char-before))))
        (or (eq syn ?\) )
            (eq syn ?\" )
            (and (eq syn ?_ )
                 (eq (char-before) ?\})))
        ))))

(defun grammatical-edit-before-open-pair-p ()
  (unless (eobp)
    (save-excursion
      (let ((syn (char-syntax (char-after))))
        (or (eq syn ?\( )
            (eq syn ?\" )
            (and (eq syn ?_)
                 (eq (char-after) ?\{)))
        ))))

(defun grammatical-edit-before-close-pair-p ()
  (unless (eobp)
    (save-excursion
      (let ((syn (char-syntax (char-after))))
        (or (eq syn ?\) )
            (and (eq syn ?_)
                 (eq (char-after) ?\})))
        ))))

(defun grammatical-edit-in-empty-pair-p ()
  (ignore-errors
    (save-excursion
      (or (and (eq (char-syntax (char-before)) ?\()
               (eq (char-after) (matching-paren (char-before))))
          (and (eq (char-syntax (char-before)) ?_)
               (eq (char-before) ?\{)
               (eq (char-syntax (char-after)) ?_)
               (eq (char-after) ?\})
               )))))

(defun grammatical-edit-in-single-quote-string-p ()
  (save-excursion
    (when (grammatical-edit-ignore-errors
           (progn
             (save-excursion (backward-sexp))
             (save-excursion (forward-sexp))))
      (let* ((current-sexp (buffer-substring-no-properties
                            (save-excursion
                              (backward-sexp)
                              (point))
                            (save-excursion
                              (forward-sexp)
                              (point))
                            ))
             (first-char (substring current-sexp 0 1))
             (last-char (substring current-sexp -1 nil)))
        (and (string-equal first-char "'")
             (string-equal last-char "'"))))))

(defun grammatical-edit-node-type-at-point ()
  (tsc-node-type (tree-sitter-node-at-point)))

(defun grammatical-edit-in-string-p ()
  (eq (grammatical-edit-node-type-at-point) 'string))

(defun grammatical-edit-in-comment-p ()
  (or (eq (grammatical-edit-node-type-at-point) 'comment)
      (and (point-at-eol)
           (save-excursion
             (backward-char 1)
             (eq (grammatical-edit-node-type-at-point) 'comment)))))

(defun grammatical-edit-in-string-escape-p ()
  (let ((oddp nil))
    (save-excursion
      (while (eq (char-before) ?\\ )
        (setq oddp (not oddp))
        (backward-char)))
    oddp))

(defun grammatical-edit-in-char-p (&optional argument)
  (let ((argument (or argument (point))))
    (and (eq (char-before argument) ?\\ )
         (not (eq (char-before (1- argument)) ?\\ )))))

(defun grammatical-edit-is-blank-line-p ()
  (save-excursion
    (beginning-of-line)
    (looking-at "[[:space:]]*$")))

(defun grammatical-edit-only-whitespaces-before-cursor-p ()
  (let ((string-before-cursor
         (buffer-substring
          (save-excursion
            (beginning-of-line)
            (point))
          (point))))
    (equal (length (string-trim string-before-cursor)) 0)))

(defun grammatical-edit-in-curly-p ()
  (ignore-errors
    (save-excursion
      (let* ((left-parent-pos
              (progn
                (backward-up-list)
                (point)))
             (right-parent-pos
              (progn
                (forward-list)
                (point)))
             (left-parent-char
              (progn
                (goto-char left-parent-pos)
                (char-after)))
             (right-parent-char
              (progn
                (goto-char right-parent-pos)
                (char-before))))
        (and (eq left-parent-char ?\{) (eq right-parent-char ?\}))))))

(defun grammatical-edit-newline (arg)
  (interactive "p")
  (cond
   ;; Just newline if in string or comment.
   ((or (grammatical-edit-in-comment-p)
        (grammatical-edit-in-string-p))
    (newline arg))
   ((derived-mode-p 'inferior-emacs-lisp-mode)
    (ielm-return))
   ;; Newline and indent region if cursor in parentheses and character is not blank after cursor.
   ((and (looking-back "(\s*\\|{\s*\\|\\[\s*")
         (looking-at-p "[[:space:]]*$"))
    (newline arg)
    (open-line 1)
    (save-excursion
      (let ((inhibit-message t)
            (start (progn (grammatical-edit-jump-left) (point)))
            (end (progn (grammatical-edit-match-paren nil) (point))))
        (indent-region start end)))
    (indent-according-to-mode))
   ;; Newline and indent.
   (t
    (newline arg)
    (indent-according-to-mode)
    )))

;; Integrate with eldoc
(with-eval-after-load 'eldoc
  (eldoc-add-command-completions
   "grammatical-edit-"))

(provide 'grammatical-edit)

;;; grammatical-edit.el ends here
