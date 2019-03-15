;;; helm-wikipedia.el --- Wikipedia suggestions. -*- lexical-binding: t -*-

;; Copyright (C) 2012 ~ 2019 Thierry Volpiatto <thierry.volpiatto@gmail.com>

;; Package-Requires: ((helm "1.5") (cl-lib "0.5") (emacs "24.1"))
;; URL: https://github.com/emacs-helm/helm-wikipedia

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Code:

(require 'helm-net)

(declare-function json-read-from-string "json" (string))

(defcustom helm-wikipedia-suggest-url
  "https://en.wikipedia.org/w/api.php?action=opensearch&search=%s"
  "Url used for looking up Wikipedia suggestions.
This is a format string, don't forget the `%s'."
  :type 'string
  :group 'helm-net)

(defun helm-wikipedia-suggest-fetch ()
  "Fetch Wikipedia suggestions and return them as a list."
  (require 'json)
  (let ((request (format helm-wikipedia-suggest-url
                         (url-hexify-string helm-pattern))))
    (with-current-buffer (url-retrieve-synchronously request)
      (helm-wikipedia--parse-buffer))))

(defun helm-wikipedia--parse-buffer ()
  (goto-char (point-min))
  (when (re-search-forward "\n\n" nil t)
    (cl-loop with array = (json-read-from-string (buffer-substring-no-properties (point) (point-max)))
             for str across (aref array 1)
             for n from 0
             collect (cons str (aref (aref array 3) n)) into cands
             and
             do (unless (gethash str helm-wikipedia--summary-cache)
                  (puthash str (aref (aref array 2) n) helm-wikipedia--summary-cache))
             finally return (or cands
                                (append
                                 cands
                                 (list (cons (format "Search for '%s' on wikipedia"
                                                     helm-pattern)
                                             helm-pattern)))))))

(defvar helm-wikipedia--summary-cache (make-hash-table :test 'equal))
(defun helm-wikipedia-show-summary (input)
  "Show Wikipedia summary for INPUT in new buffer."
  (interactive)
  (let ((buffer (get-buffer-create "*helm wikipedia summary*"))
        (summary (helm-wikipedia--get-summary input)))
    (with-current-buffer buffer
      (visual-line-mode)
      (erase-buffer)
      (insert summary)
      (pop-to-buffer (current-buffer))
      (goto-char (point-min)))))

(defun helm-wikipedia-persistent-action (candidate)
  (unless (string= (format "Search for '%s' on wikipedia"
                           helm-pattern)
                   (helm-get-selection nil t))
    (let ((buf (get-buffer-create "*helm wikipedia summary*"))
          (result (helm-wikipedia--get-summary candidate)))
      (if result
          (progn
            (with-current-buffer buf
              (erase-buffer)
              (setq cursor-type nil)
              (insert result)
              (fill-region (point-min) (point-max))
              (goto-char (point-min)))
            (display-buffer buf))
        (message "No summary for %s" candidate)))))

(defun helm-wikipedia--get-summary (candidate)
  "Return Wikipedia summary for CANDIDATE as string."
  (gethash (helm-get-selection nil t) helm-wikipedia--summary-cache))

(defvar helm-source-wikipedia-suggest
  (helm-build-sync-source "Wikipedia Suggest"
    :candidates #'helm-wikipedia-suggest-fetch
    :action '(("Wikipedia" . (lambda (candidate)
                               (helm-browse-url candidate)))
              ("Show summary in new buffer (C-RET)" . helm-wikipedia-show-summary))
    :persistent-action #'helm-wikipedia-persistent-action
    :persistent-help "show summary"
    :volatile t
    :keymap helm-wikipedia-map
    :requires-pattern 3))

(defun helm-wikipedia-show-summary-action ()
  "Exit Helm buffer and call `helm-wikipedia-show-summary' with selected candidate."
  (interactive)
  (with-helm-alive-p
    (helm-exit-and-execute-action 'helm-wikipedia-show-summary)))
(put 'helm-wikipedia-show-summary-action 'helm-only t)

;;;###autoload
(defun helm-wikipedia-suggest ()
  "Preconfigured `helm' for Wikipedia lookup with Wikipedia suggest."
  (interactive)
  (helm :sources 'helm-source-wikipedia-suggest
        :buffer "*helm wikipedia*"))

(provide 'helm-wikipedia)

;;; helm-wikipedia.el ends here
