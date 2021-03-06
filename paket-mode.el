;;; paket-mode.el --- A major mode for managing Paket configurations  -*- lexical-binding: t; -*-

;; Copyright (C) 2015

;; Author:  <M. Strik>
;; Keywords: processes, languages
;; Version: 0.2

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

;;; Commentary:

;; Provides a major mode for managing Paket configurations.

;;; Code:


(provide 'paket-mode)
;;; paket-mode.el ends here


(require 'json)
(require 'auto-complete)

(defvar paket-mode-hook nil)

(defun paket--init-default-auto-mode-alist ()
  "Initialize default `auto-mode-alist' hooks for paket related files"
  ;; paket.dependencies
  (add-to-list 'auto-mode-alist
               '("paket\\.dependencies" . paket-mode))
  ;; paket.lock
  (add-to-list 'auto-mode-alist
               '("paket\\.lock" . paket-mode))
  (add-to-list 'auto-mode-alist
               '("paket\\.references" . paket-mode)))
(paket--init-default-auto-mode-alist)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helper functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-derived-mode paket-interaction-mode special-mode "*PAKET*"
  "Special mode for Paket interaction buffers"
  ;; Setup keys to quit buffer.
  (local-set-key (kbd "q") 'kill-buffer-and-window)
  (when (fboundp 'evil-define-key)
    (evil-local-set-key 'normal "q" 'kill-buffer-and-window))
  ;; Settings
  (when (not truncate-lines)
    (toggle-truncate-lines)))

(defun paket--make-temp-buffer (callback-with-buffer)
  "Create a temp buffer and call 'callback-with-buffer' to init its contents."
  (save-excursion
    (let ((buffer (get-buffer-create "*PAKET*")))
      (with-current-buffer buffer
        (erase-buffer)
        (paket-interaction-mode)
        (display-buffer-below-selected buffer nil)
        (select-window (get-buffer-window buffer))
        (funcall callback-with-buffer buffer)))))

(defun paket--temp-buffer-text (face contents)
  "Helper for adding fontified text to a buffer."
  (let ((s (point)))
    (insert contents)
    (set-text-properties s (point) `(face ,face))))

(defun paket--find-project-root-ask ()
  "Ask the user for the project root directly, called from `paket--find-project-root'"
  (read-directory-name "Root of project: "))

(defun paket--find-project-root ()
  "Try to find the root folder of a Paket project by searching for a .sln file. If
it cannot be found, we ask the user."
  (if (not (buffer-file-name))
      (paket--find-project-root-ask)
    (or (locate-dominating-file (buffer-file-name)
                                (lambda (directory)
                                  (directory-files directory nil "\\.sln\\'")))
        (paket--find-project-root-ask))))

(defvar paket--dynamic-project-root-binding nil
  "Global symbol used for dynamically binding the root project using `with-project-root'")

(defmacro paket--with-project-root (project-root-var-name &rest body)
  "Macro for getting the root of a Paket project. This macro is meant to make sure that
when functions that require a project root call eachother, the user will only ever be asked
to enter the project root once."
  `(let* ((paket--dynamic-project-root-binding (or paket--dynamic-project-root-binding
                                                 (paket--find-project-root)))
          (,project-root-var-name (file-name-as-directory paket--dynamic-project-root-binding)))
     ,@body))

(defun paket--package-at-point ()
  "Identify the package at-point an return it as a string"
  ;; Just get thing at point for now, now extra checking is done.
  ;; Not for valid bounds nor for a valid package.
  (let ((bounds (bounds-of-thing-at-point 'word)))
    (buffer-substring-no-properties (car bounds) (cdr bounds))))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Bootstrapping
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defvar paket-bootstrapper-url
  "http://github.com/fsprojects/Paket/releases/download/1.4.13/paket.bootstrapper.exe"
  "URL for downloading the Paket bootstrapper executable.")
(defvar paket-exe-directory
  ".paket"
  "Relative directory that should house the paket files. Default is .paket")
(defvar paket-bootstrapper-exe
  "paket.bootstrapper.exe"
  "Name of the paket bootstrapper. Default is paket.bootstrapper.exe")
(defvar paket-exe
  "paket.exe"
  "Name of the paket executable. Default is paket.exe")

(defun paket--download-bootstrapper (target-location)
  (when (file-exists-p target-location)
    (when (not (y-or-n-p (format "File exists, overwrite? %s" target-location)))
      (error "Aborting, won't overwrite existing file.")))
  ;;;; Doesn't seem to work for large binary files?
  ;; (url-copy-file paket-bootstrapper-url target-location t)
  (let ((cmd (format "curl -L \"%s\" -o \"%s\"" paket-bootstrapper-url target-location)))
    (with-temp-message (format "Downloading: %s" cmd)
      (shell-command cmd))))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Executing paket
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun paket--find-paket-exe ()
  "Try to locate paket.exe"
  (paket--with-project-root project-root
                            (let* ((paket-root (concat (file-name-as-directory project-root) paket-exe-directory))
                                   (paket-exe (concat (file-name-as-directory paket-root) paket-exe)))
                              (if (file-exists-p paket-exe)
                                  paket-exe
                                (error "Could not locate paket executable (perhaps run paket-bootstrap first?): %s" paket-exe)))))

(defun paket-edit-dependencies ()
  "Open paket.dependencies for editing"
  (interactive)
  (paket--with-project-root project-root
                            (let* ((dep-file (concat (file-name-as-directory project-root) "paket.dependencies")))
                              (if (file-exists-p dep-file)
                                  (find-file dep-file)
                                (error "File does not exist, use paket-init to create it: %s" dep-file)))))

(defun paket-edit-lock ()
  "Open paket.lock for editing and perusal"
  (interactive)
  (paket--with-project-root project-root
                            (let* ((lock-file (concat (file-name-as-directory project-root) "paket.lock")))
                              (if (file-exists-p lock-file)
                                  (find-file lock-file)
                                (error "File does not exist: %s" lock-file)))))

(defun paket--run (&rest args)
  "Run a paket command for a project."
  (paket--with-project-root project-root
                            (let ((paket-exe (paket--find-paket-exe)))
                              (let ((default-directory project-root)) ; List of args, concatenate.
                                (paket--make-temp-buffer
                                 (lambda (buffer)
                                   (with-current-buffer buffer
                                     (let ((inhibit-read-only t))
                                       (insert (format "Running: %s %s\n\n" paket-exe args))
                                       (set-process-sentinel
                                        (apply 'start-process (append (list "paket" buffer paket-exe)
                                                                      args))
                                        (lambda (proc event)
                                          (message "PAKET: %s - %s" proc event)
                                          (reposition-window)))))))))))

(defun paket-run (args)
  "Run a raw paket command for a project."
  (interactive "sRun paket with args: ")
  (let ((final-args (split-string args)))
    (apply 'paket--run final-args)))

;;;###autoload
(defun paket-init ()
  "Run paket init for a project to create the paket.dependencies file."
  (interactive)
  (paket--with-project-root project-root
                            (let* ((dep-file (concat (file-name-as-directory project-root) "paket.dependencies")))
                              (when (y-or-n-p (format "Run paket init in %s?" project-root))
                                (paket--run "init"))
                              ;; Following doesn't run with async execution, need to device better method.
                              ;;(when (and (y-or-n-p (format "Open file for editing? %s" dep-file))
                                         ;;(file-exists-p dep-file))
                              ;;(find-file dep-file))
                              )))

(defun paket-add (package-name)
  "Run paket add for the given package name."
  (interactive "sPackage name: ")
  (paket--run "add" "nuget" package-name))

(defun paket-restore ()
  "Run paket restore."
  (interactive)
  (paket--run "restore"))

(defun paket-install ()
  "Run paket install."
  (interactive)
  (paket--run "install"))

(defun paket-find-refs ()
  "Run paket find-refs for the package specified at point"
  (interactive)
  (let ((package (paket--package-at-point)))
    (paket--run "find-refs" "nuget" package)))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Nuget search functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defconst +paket--nuget-search-url+
  ;;"http://www.nuget.org/api/v2/Search?$format=json&$filter=IsLatestVersion&$orderby=Id&$top=30&targetFramework=%%27%%27&includePreRelease=false&searchTerm=%%27%s%%27"
  "http://www.nuget.org/api/v2/Packages?$format=json&$filter=IsLatestVersion%%20and%%20substringof%%28%%27%s%%27,%%20Id%%29&$orderby=Id&$top=30&targetFramework=%%27%%27")

(defun paket--nuget-make-search-url (searchTerm)
  "Create URL for searching, using the given searchTerm"
  (format +paket--nuget-search-url+ searchTerm))

(defun paket--nuget-search (searchTerm)
  "Search NuGet for searchTerm and return all meta data found."
  (let* ((url (paket--nuget-make-search-url searchTerm))
        (response-buffer (url-retrieve-synchronously url))
        (response (with-current-buffer response-buffer (buffer-string))))
    (with-temp-buffer
      (insert response)
      (beginning-of-buffer)
      (search-forward-regexp "^$")
      (delete-region 1 (+ 1 (point)))
      (let ((json (json-read-from-string (buffer-string))))
        (cdr (car json))))))

(defun paket--nuget-search-titles (searchTerm)
  "Search NuGet and return list of titles found."
  (let* ((items (paket--nuget-search searchTerm))
         (key-values (cl-map 'vector (lambda (item) (cdr (assoc 'Id item))) items))
         (values (delq nil key-values)))
    values))

(defun assoc-def (lst key default)
  (let ((val (assoc key lst)))
    (if val
        (or (cdr val) default)
      default)))

(defun paket-nuget-search (searchTerm)
  (interactive "sSearch for: ")
  (let ((items (paket--nuget-search searchTerm)))
    (paket--make-temp-buffer
     (lambda (buffer)
       (loop for dict across items do
             (let ((id (assoc-def dict 'Id "NA"))
                   (title (assoc-def dict 'Title ""))
                   (description (assoc-def dict 'Description "")))
               (paket--temp-buffer-text font-lock-variable-name-face id)
               (insert "\n---------------------------------------------------------\n")
               (paket--temp-buffer-text font-lock-string-face description)
               (insert "\n\n\n")))))))

(defun paket-nuget-complete-package-at-point ()
  (interactive)
  (let* ((posEnd (point))
        (bounds (bounds-of-thing-at-point 'symbol))
        (searchItem (buffer-substring-no-properties (car bounds) (cdr bounds)))
        packageList)

    (when (not searchItem)
      (setq searchItem ""))
    (setq packageList
          ;; Convert vector to list with append.
          (append
           (paket--nuget-search-titles searchItem)
           nil))

    (setq maxMatchResult (try-completion searchItem packageList))
    (when (null maxMatchResult)
      (setq maxMatchResult ""))

    (cond ((eq maxMatchResult t))
          ((null packageList)
           (message "Can't find comletion for \"%s\"" searchItem)
           (ding))
          ((= (length packageList) 1)
           ;; (not (string= searchItem maxMatchResult))
           (delete-region (- posEnd (length searchItem)) posEnd)
           (insert maxMatchResult))
          (t (message "Making completion list...")
             (with-output-to-temp-buffer "*Completions*"
               (display-completion-list
                (all-completions maxMatchResult packageList)
                searchItem))
             (message "Making completion list... %s" "done")))))

(defconst +paket-mode--dependencies--keywords+
  (list
   ;; Comments.
   '("#.+$" . font-lock-comment-face)
   ;; URLs
   '("https?://.[^\s\n]+" . font-lock-string-face)
   ;; Property keywords.
   '("\\<\\(redirects\\|framework\\|source\\|copy_local\\|nuget\\)\\>" . font-lock-keyword-face)
   ;; Value keywords.
   '("\\<\\(net45\\|on\\|off\\|true\\|false\\)\\>" . font-lock-variable-name-face)
   ;; Package specifiers.
   '("^nuget \\([a-zA-Z][a-zA-Z0-9\\.-]+\\)" . (1 font-lock-constant-face))
   ;; Package version specifiers.
   '("^nuget .+? \\([0-9][\\.0-9]+\\(-[a-zA-Z]+\\)?\\)" . (1 font-lock-type-face))
   )
  "Keyword list for paket.dependencies files")

(defconst +paket-mode--lock--keywords+
  (list
   ;; URLs
   '("https?://.[^\s\n]+" . font-lock-string-face)
   ;; Property keywords.
   '("\\<\\(REDIRECTS\\|framework\\|FRAMEWORK\\|remote\\|specs\\|NUGET\\)\\>" . font-lock-keyword-face)
   ;; Value keywords.
   '("\\<\\(winv4\\.5\\|wpv8\\.0\\|portable-win81\\|net45\\|portable\\|wp80\\|win\\|wp81\\|wpa81\\|on\\|off\\|true\\|false\\)\\>" . font-lock-variable-name-face)
   ;; Package names
   '("^\s+\\([a-zA-Z0-9-]+\\)\\(\\.\\([a-zA-Z0-9-]\\)+\\)*" . font-lock-constant-face)
   ;; Package version specifiers.
   '("(.+)" . font-lock-type-face)
   )
  "Keyword list for paket.lock files")

(defconst +paket-mode--references-keywords+
  (list
   ;; Comments.
   '("#.+$" . font-lock-comment-face)
   ;; Package names.
   '("^\\([a-zA-Z0-9-]+\\)\\(\\.\\([a-zA-Z0-9-]\\)+\\)*" . font-lock-constant-face)
   )
  "Keyword list for paket.references files")

(defconst +paket-mode--syntax-table+
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?_ "w" st)
    ;; Help package specifiers be treated as words:
    (modify-syntax-entry ?. "w" st)
    (modify-syntax-entry ?- "w" st)
    st))

;;;###autoload
(defun paket-bootstrap ()
  "Bootstrap a project by downloading the Paket bootstrapper and running it to install paket.exe"
  (interactive)
  (paket--with-project-root project-root
                            (let* ((paket-root (concat (file-name-as-directory project-root) paket-exe-directory))
                                   (paket-bootstrapper-exe (concat (file-name-as-directory paket-root) paket-bootstrapper-exe)))
                              ;; Check for existance of paket root.
                              (when (not (file-exists-p paket-root))
                                (if (y-or-n-p (format "Directory doesn't exist, create? %s" paket-root))
                                    (make-directory paket-root)
                                  (error "Can't continue, directory doesn't exist")))
                              ;; Check for existance of bootstrapper.
                              (when (not (file-exists-p paket-bootstrapper-exe))
                                (if (y-or-n-p (format "Bootsrapper not present, download from %s?" paket-bootstrapper-url))
                                    (paket--download-bootstrapper paket-bootstrapper-exe)
                                  (error (format "Can't continue, bootstrapper not found %s" paket-bootstrapper-exe))))
                              (if (y-or-n-p (format "Ok to run bootstrapper? %s" paket-bootstrapper-exe))
                                  (paket--make-temp-buffer
                                   (lambda (buffer)
                                     (shell-command paket-bootstrapper-exe buffer buffer)))
                                (error "Did not run bootstrapper")))))

(defvar paket-mode-map
  (let ((map (make-keymap)))
    (define-key map (kbd "C-c C-r") 'paket-run)
    (define-key map (kbd "C-c C-a") 'paket-add)
    (define-key map (kbd "C-c C-o") 'paket-restore)
    (define-key map (kbd "C-c C-f") 'paket-install) ;; Mnemonic: paket fulfill, probably needs something better.
    (define-key map (kbd "C-c C-s") 'paket-nuget-search)
    (define-key map (kbd "C-c C-w") 'paket-find-refs) ;; Mnemonic: paket where
    map))

(defun paket-mode ()
  "Major mode for Paket files."
  (interactive)
  (kill-all-local-variables)
  (when (string-match "\\.dependencies$" (buffer-file-name))
    ;; Setup for paket.dependencies
    (set-syntax-table +paket-mode--syntax-table+)
    (set (make-local-variable 'font-lock-defaults)
         '(+paket-mode--dependencies--keywords+)))
  (when (string-match "\\.lock$" (buffer-file-name))
    ;; Setup for paket.lock
    (set-syntax-table +paket-mode--syntax-table+)
    (set (make-local-variable 'font-lock-defaults)
         '(+paket-mode--lock--keywords+)))
  (when (string-match "\\.references$" (buffer-file-name))
    ;; Setup for paket.references
    (set-syntax-table +paket-mode--syntax-table+)
    (set (make-local-variable 'font-lock-defaults)
         '(+paket-mode--references-keywords+)))
  (setq major-mode 'paket-mode)
  (setq mode-name "Paket")
  (use-local-map paket-mode-map)
  (run-hooks 'paket-mode-hook))

(provide 'paket-mode)
