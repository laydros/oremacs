;;* require
(require 'dired-x)
(require 'dired-aux)
(require 'term)
;;* set
(setq dired-listing-switches "-laGh1v --group-directories-first")
(setq directory-free-space-args "-Pmh")
(setq dired-recursive-copies 'always)
(setq dired-recursive-deletes 'always)
(setq dired-omit-files "\\(?:.*\\.\\(?:aux\\|log\\|synctex\\.gz\\|run\\.xml\\|bcf\\|am\\|in\\)\\'\\)\\|^\\.\\|-blx\\.bib")
(setq dired-garbage-files-regexp
      "\\.idx\\|\\.run\\.xml$\\|\\.bbl$\\|\\.bcf$\\|.blg$\\|-blx.bib$\\|.nav$\\|.snm$\\|.out$\\|.synctex.gz$\\|\\(?:\\.\\(?:aux\\|bak\\|dvi\\|log\\|orig\\|rej\\|toc\\|pyg\\)\\)\\'")
(setq dired-dwim-target t)
(setq dired-guess-shell-alist-user
      '(("\\.pdf\\'" "evince" "okular")
        ("\\.\\(?:djvu\\|eps\\)\\'" "evince")
        ("\\.\\(?:jpg\\|jpeg\\|png\\|gif\\|xpm\\)\\'" "eog")
        ("\\.\\(?:xcf\\)\\'" "gimp")
        ("\\.csv\\'" "libreoffice")
        ("\\.tex\\'" "pdflatex" "latex")
        ("\\.\\(?:mp4\\|mkv\\|avi\\|flv\\|ogv\\)\\(?:\\.part\\)?\\'"
         "vlc")
        ("\\.\\(?:mp3\\|flac\\|wv\\)\\'" "rhythmbox")
        ("\\.html?\\'" "firefox")
        ("\\.cue?\\'" "audacious")))
;;* advice
(defadvice dired-advertised-find-file (around ora-dired-subst-directory activate)
  "Replace current buffer if file is a directory."
  (interactive)
  (let* ((orig (current-buffer))
         (filename (dired-get-filename t t))
         (bye-p (file-directory-p filename)))
    ad-do-it
    (when (and bye-p (not (string-match "[/\\\\]\\.$" filename)))
      (kill-buffer orig))))

(defadvice dired-delete-entry (before ora-force-clean-up-buffers (file) activate)
  (let ((buffer (get-file-buffer file)))
    (when buffer
      (kill-buffer buffer))))

;;* rest
(defun ora-dired-get-size ()
  (interactive)
  (let ((files (dired-get-marked-files)))
    (with-temp-buffer
      (apply 'call-process "/usr/bin/du" nil t nil "-sch" files)
      (message
       "Size of all marked files: %s"
       (progn
         (re-search-backward "\\(^[ 0-9.,]+[A-Za-z]+\\).*total$")
         (match-string 1))))))

(defvar ora-dired-filelist-cmd
  '(("vlc" "-L")))

(defun ora-dired-start-process (cmd &optional file-list)
  (interactive
   (let ((files (dired-get-marked-files
                 t current-prefix-arg)))
     (list
      (dired-read-shell-command "& on %s: "
                                current-prefix-arg files)
      files)))
  (let (list-switch)
    (start-process
     cmd nil shell-file-name
     shell-command-switch
     (format
      "nohup 1>/dev/null 2>/dev/null %s \"%s\""
      (if (and (> (length file-list) 1)
               (setq list-switch
                     (cadr (assoc cmd ora-dired-filelist-cmd))))
          (format "%s %s" cmd list-switch)
        cmd)
      (mapconcat #'expand-file-name file-list "\" \"")))))

(defun ora-dired-open-term ()
  "Open an `ansi-term' that corresponds to current directory."
  (interactive)
  (let ((current-dir (dired-current-directory)))
    (term-send-string
     (ora-terminal)
     (if (file-remote-p current-dir)
         (let ((v (tramp-dissect-file-name current-dir t)))
           (format "ssh %s@%s\n"
                   (aref v 1) (aref v 2)))
       (format "cd '%s'\n" current-dir)))))

(require 'hydra)
(defhydra hydra-marked-items (dired-mode-map "")
  "
Number of marked items: %(length (dired-get-marked-files))
"
  ("m" dired-mark "mark"))

;;* bind and hook
(define-key dired-mode-map "r" 'ora-dired-start-process)
(define-key dired-mode-map "e" 'ediff-files)
(define-key dired-mode-map (kbd "C-t") nil)
(define-key dired-mode-map "i" 'ido-find-file)
(define-key dired-mode-map "j" 'dired-next-line)
(define-key dired-mode-map "k" 'dired-previous-line)
(define-key dired-mode-map "Y" 'ora-dired-rsync)
(define-key dired-mode-map (kbd "C-j") 'dired-find-file)
(define-key dired-mode-map (kbd "%^") 'dired-flag-garbage-files)
(define-key dired-mode-map (kbd "z") 'ora-dired-get-size)
(define-key dired-mode-map "F" 'find-name-dired)
(define-key dired-mode-map (kbd "M-o") 'dired-omit-mode)
(define-key dired-mode-map (kbd "`") 'ora-dired-open-term)
(define-key dired-mode-map (kbd "'") 'eshell-this-dir)
(define-key dired-mode-map "a" (lambda () (interactive) (find-alternate-file "..")))
(define-key dired-mode-map "!" 'sudired)
(define-key dired-mode-map "h" nil)


(use-package make-it-so
    :commands make-it-so mis-mode
    :init
    (setq mis-recipes-directory
          (expand-file-name
           "git/make-it-so/recipes/" emacs-d)))

;;;###autoload
(defun ora-dired-hook ()
  (mis-mode 1))
