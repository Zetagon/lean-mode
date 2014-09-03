;; Copyright (c) 2014 Microsoft Corporation. All rights reserved.
;; Released under Apache 2.0 license as described in the file LICENSE.
;;
;; Author: Soonho Kong
;;

(require 'cl-lib)
(require 'dash)
(require 'dash-functional)
(require 'flycheck)
(require 'lean-util)
(require 'lean-debug)

;; Type Information
;; ----------------
(defun lean-info-type-kind (typeinfo)
  (cl-first typeinfo))
(defun lean-info-type-p (typeinfo)
  (pcase typeinfo
    (`TYPE t)
    ((pred stringp) (string-prefix-p "-- TYPE" typeinfo))
    ((pred listp) (and (lean-info-type-p (cl-first typeinfo))))))
(defun lean-info-type-pos (typeinfo)
  (cl-second typeinfo))
(defun lean-info-type-parse-header (str)
  (let ((items (split-string str "|")))
    (list (string-to-number (cl-second items))
          (string-to-number (cl-third items)))))
(defun lean-info-type-parse (seq)
  (when (lean-info-type-p seq)
    (let ((header (lean-info-type-parse-header (car seq)))
        (body (cdr seq)))
    `(TYPE ,header ,body))))
(defun lean-info-type-body (typeinfo)
  (cl-third typeinfo))
(defun lean-info-type-body-str (typeinfo)
  (string-join (lean-info-type-body typeinfo) "\n"))

;; -- Test
(cl-assert (lean-info-type-p 'TYPE))
(cl-assert (lean-info-type-p "-- TYPE|121|2"))
(cl-assert (lean-info-type-p '("-- TYPE|121|2" "not (eq zero (succ m'))" "→ decidable (eq zero (succ m'))")))
(cl-assert (equal (lean-info-type-parse-header "-- TYPE|121|2")
                  '(121 2)))
(cl-assert (equal (lean-info-type-parse '("-- TYPE|121|2" "not (eq zero (succ m'))" "→ decidable (eq zero (succ m'))"))
                  '(TYPE
                    (121 2)
                    ("not (eq zero (succ m'))"
                     "→ decidable (eq zero (succ m'))"))))
(cl-assert (equal
            (lean-info-type-pos
             (lean-info-type-parse '("-- TYPE|121|2" "not (eq zero (succ m'))" "→ decidable (eq zero (succ m'))")))
            '(121 2)))

;; Overload Information
;; --------------------

(defun lean-info-overload-type (overload)
  (cl-first overload))
(defun lean-info-overload-p (overload)
  (pcase overload
    (`OVERLOAD t)
    ((pred stringp) (string-prefix-p "-- OVERLOAD" overload))
    ((pred listp) (and (lean-info-overload-p (cl-first overload))))))
(defun lean-info-overload-pos (overload)
  (cl-second overload))
(defun lean-info-overload-names (overload)
  (cl-loop for seq in (cl-third overload)
           collect (string-join seq "\n")))
(defun lean-info-overload-parse-header (str)
  (let ((items (split-string str "|")))
    (list (string-to-number (cl-second items))
          (string-to-number (cl-third items)))))
(defun lean-info-overload-parse (seq)
  (when (lean-info-overload-p seq)
    (let ((header (lean-info-overload-parse-header (car seq)))
        (body (-split-on "--" (cdr seq))))
    `(OVERLOAD ,header ,body))))

;; -- Test
(cl-assert (lean-info-overload-p 'OVERLOAD))
(cl-assert (lean-info-overload-p "-- OVERLOAD|121|2"))
(cl-assert (lean-info-overload-p '("-- OVERLOAD|121|2" "not (eq zero (succ m'))" "→ decidable (eq zero (succ m'))")))
(cl-assert (equal (lean-info-overload-parse-header "-- OVERLOAD|121|2")
                  '(121 2)))
(cl-assert
 (equal
  (lean-info-overload-parse
   '("-- OVERLOAD|121|2"
     "not (eq zero (succ m'))"
     "→ decidable (eq zero (succ m'))"
     "--"
     "not (eq one (succ m'))"
     "→ decidable (eq zero (succ m'))"
     "--"
     "not (eq two (succ m'))"
     "→ decidable (eq zero (succ m'))"))
  '(OVERLOAD (121 2)
             (("not (eq zero (succ m'))" "→ decidable (eq zero (succ m'))")
              ("not (eq one (succ m'))" "→ decidable (eq zero (succ m'))")
              ("not (eq two (succ m'))" "→ decidable (eq zero (succ m'))")))))
(cl-assert (equal
            (lean-info-overload-pos
             (lean-info-overload-parse
              '("-- OVERLOAD|121|2"
                "not (eq zero (succ m'))"
                "→ decidable (eq zero (succ m'))"
                "--"
                "not (eq one (succ m'))"
                "→ decidable (eq zero (succ m'))"
                "--"
                "not (eq two (succ m'))"
                "→ decidable (eq zero (succ m'))")))
            '(121 2)))
(cl-assert (equal (lean-info-overload-names (lean-info-overload-parse
                                        '("-- OVERLOAD|121|2"
                                          "not (eq zero (succ m'))"
                                          "→ decidable (eq zero (succ m'))"
                                          "--"
                                          "not (eq one (succ m'))"
                                          "→ decidable (eq zero (succ m'))"
                                          "--"
                                          "not (eq two (succ m'))"
                                          "→ decidable (eq zero (succ m'))")))
                  '("not (eq zero (succ m'))\n→ decidable (eq zero (succ m'))"
                    "not (eq one (succ m'))\n→ decidable (eq zero (succ m'))"
                    "not (eq two (succ m'))\n→ decidable (eq zero (succ m'))")))

;; Synth Information
;; ----------------
(defun lean-info-synth-type (synth)
  (cl-first synth))
(defun lean-info-synth-p (synth)
  (pcase synth
    (`SYNTH t)
    ((pred stringp) (string-prefix-p "-- SYNTH" synth))
    ((pred listp) (and (lean-info-synth-p (cl-first synth))))))
(defun lean-info-synth-pos (synth)
  (cl-second synth))
(defun lean-info-synth-parse-header (str)
  (let ((items (split-string str "|")))
    (list (string-to-number (cl-second items))
          (string-to-number (cl-third items)))))
(defun lean-info-synth-parse (seq)
  (when (lean-info-synth-p seq)
    (let ((header (lean-info-synth-parse-header (car seq)))
          (body (cdr seq)))
      `(SYNTH ,header ,body))))
(defun lean-info-synth-body (synth)
  (cl-third synth))
(defun lean-info-synth-body-str (synth)
  (string-join (lean-info-synth-body synth) "\n"))

;; -- Test
(cl-assert (lean-info-synth-p 'SYNTH))
(cl-assert (lean-info-synth-p "-- SYNTH|121|2"))
(cl-assert (lean-info-synth-p '("-- SYNTH|121|2" "not (eq zero (succ m'))" "→ decidable (eq zero (succ m'))")))
(cl-assert (equal (lean-info-synth-parse-header "-- SYNTH|121|2")
                  '(121 2)))
(cl-assert (equal (lean-info-synth-parse '("-- SYNTH|121|2" "not (eq zero (succ m'))" "→ decidable (eq zero (succ m'))"))
                  '(SYNTH
                    (121 2)
                    ("not (eq zero (succ m'))"
                     "→ decidable (eq zero (succ m'))"))))
(cl-assert (equal
            (lean-info-synth-pos
             (lean-info-synth-parse '("-- SYNTH|121|2" "not (eq zero (succ m'))" "→ decidable (eq zero (succ m'))")))
            '(121 2)))

;; Coercion Information
;; ----------------
(defun lean-info-coercion-type (coercion)
  (cl-first coercion))
(defun lean-info-coercion-p (coercion)
  (pcase coercion
    (`COERCION t)
    ((pred stringp) (string-prefix-p "-- COERCION" coercion))
    ((pred listp) (and (lean-info-coercion-p (cl-first coercion))))))
(defun lean-info-coercion-pos (coercion)
  (cl-second coercion))
(defun lean-info-coercion-parse-header (str)
  (let ((items (split-string str "|")))
    (list (string-to-number (cl-second items))
          (string-to-number (cl-third items)))))
(defun lean-info-coercion-parse (seq)
  (when (lean-info-coercion-p seq)
    (let ((header (lean-info-coercion-parse-header (car seq)))
          (body (cdr seq)))
      `(COERCION ,header ,body))))
(defun lean-info-coercion-body (coercion)
  (cl-third coercion))
(defun lean-info-coercion-body-str (coercion)
  (string-join (lean-info-coercion-body coercion) "\n"))

;; -- Test
(cl-assert (lean-info-coercion-p 'COERCION))
(cl-assert (lean-info-coercion-p "-- COERCION|121|2"))
(cl-assert (lean-info-coercion-p '("-- COERCION|417|15"
                                   "of_nat")))
(cl-assert (equal (lean-info-coercion-parse-header "-- COERCION|121|2")
                  '(121 2)))
(cl-assert (equal (lean-info-coercion-parse '("-- COERCION|417|15"
                                              "of_nat"))
                  '(COERCION
                    (417 15)
                    ("of_nat" ))))
(cl-assert (equal
            (lean-info-coercion-pos
             (lean-info-coercion-parse '("-- COERCION|417|15"
                                              "of_nat")))
            '(417 15)))

;; Identifier Information
;; ----------------------
(defun lean-info-identifier-type (identifier)
  (cl-first identifier))
(defun lean-info-identifier-p (identifier)
  (pcase identifier
    (`IDENTIFIER t)
    ((pred stringp) (string-prefix-p "-- IDENTIFIER" identifier))
    ((pred listp) (and (lean-info-identifier-p (cl-first identifier))))))
(defun lean-info-identifier-pos (identifier)
  (cl-second identifier))
(defun lean-info-identifier-parse-header (str)
  (let ((items (split-string str "|")))
    (list (string-to-number (cl-second items))
          (string-to-number (cl-third items)))))
(defun lean-info-identifier-parse (seq)
  (when (lean-info-identifier-p seq)
    (let ((header (lean-info-identifier-parse-header (car seq)))
          (body (cdr seq)))
      `(IDENTIFIER ,header ,body))))
(defun lean-info-identifier-body (identifier)
  (cl-third identifier))
(defun lean-info-identifier-body-str (identifier)
  (string-join (lean-info-identifier-body identifier) "\n"))

;; -- Test
(cl-assert (lean-info-identifier-p 'IDENTIFIER))
(cl-assert (lean-info-identifier-p "-- IDENTIFIER|121|2"))
(cl-assert (lean-info-identifier-p '("-- IDENTIFIER|121|2" "foo.f")))
(cl-assert (equal (lean-info-identifier-parse-header "-- IDENTIFIER|121|2")
                  '(121 2)))
(cl-assert (equal (lean-info-identifier-parse '("-- IDENTIFIER|121|2" "foo.f"))
                  '(IDENTIFIER
                    (121 2)
                    ("foo.f"))))
(cl-assert (equal
            (lean-info-identifier-pos
             (lean-info-identifier-parse '("-- IDENTIFIER|121|2" "foo.f")))
            '(121 2)))

;; Symbol Information
;; ----------------
(defun lean-info-symbol-type (symbol)
  (cl-first symbol))
(defun lean-info-symbol-p (symbol)
  (pcase symbol
    (`SYMBOL t)
    ((pred stringp) (string-prefix-p "-- SYMBOL" symbol))
    ((pred listp) (and (lean-info-symbol-p (cl-first symbol))))))
(defun lean-info-symbol-pos (symbol)
  (cl-second symbol))
(defun lean-info-symbol-parse-header (str)
  (let ((items (split-string str "|")))
    (list (string-to-number (cl-second items))
          (string-to-number (cl-third items)))))
(defun lean-info-symbol-parse (seq)
  (when (lean-info-symbol-p seq)
    (let ((header (lean-info-symbol-parse-header (car seq)))
          (body (cdr seq)))
      `(SYMBOL ,header ,body))))
(defun lean-info-symbol-body (symbol)
  (cl-third symbol))
(defun lean-info-symbol-body-str (symbol)
  (string-join (lean-info-symbol-body symbol) "\n"))

;; -- Test
(cl-assert (lean-info-symbol-p 'SYMBOL))
(cl-assert (lean-info-symbol-p "-- SYMBOL|121|2"))
(cl-assert (lean-info-symbol-p (lean-info-symbol-parse '("-- SYMBOL|121|2" "→"))))
(cl-assert (equal (lean-info-symbol-parse-header "-- SYMBOL|121|2")
                  '(121 2)))
(cl-assert (lean-info-symbol-p '("-- SYMBOL|121|2" "→")))
(cl-assert (equal (lean-info-symbol-parse '("-- SYMBOL|121|2" "→"))
                  '(SYMBOL
                    (121 2)
                    ("→"))))
(cl-assert (equal
            (lean-info-symbol-pos
             (lean-info-symbol-parse '("-- SYMBOL|121|2" "→")))
            '(121 2)))

(defun lean-info-id-symbol-body-str (info)
  (case (lean-info-kind info)
    ('IDENTIFIER (string-join (lean-info-symbol-body info) "\n"))
    ('SYMBOL     (string-join (lean-info-identifier-body info) "\n"))))

;; Basic
;; -----
(defun lean-info-kind (info)
  (cl-first info))
(defun lean-info-nay-p (str)
  (when (string-match (rx "-- BEGININFO " (* not-newline) "NAY") str)
    t))
(defun lean-info-stale-p (str)
  (when (string-match (rx "-- BEGININFO " (* not-newline) "STALE") str)
    t))
(defun lean-info-pos (info)
  (cl-case (lean-info-kind info)
    (TYPE       (lean-info-type-pos       info))
    (OVERLOAD   (lean-info-overload-pos   info))
    (SYNTH      (lean-info-synth-pos      info))
    (COERCION   (lean-info-coercion-pos   info))
    (IDENTIFIER (lean-info-identifier-pos info))
    (SYMBOL     (lean-info-symbol-pos     info))
    ))
(defun lean-info-line-number (info)
  (cl-first (lean-info-pos info)))
(defun lean-info-column (info)
  (cl-second (lean-info-pos info)))

;; -- test
(cl-assert (equal
            (lean-info-pos
             (lean-info-type-parse '("-- TYPE|121|2" "not (eq zero (succ m'))" "→ decidable (eq zero (succ m'))")))
            '(121 2)))
(cl-assert (equal
            (lean-info-pos
             (lean-info-overload-parse
              '("-- OVERLOAD|121|2"
                "not (eq zero (succ m'))"
                "→ decidable (eq zero (succ m'))"
                "--"
                "not (eq one (succ m'))"
                "→ decidable (eq zero (succ m'))"
                "--"
                "not (eq two (succ m'))"
                "→ decidable (eq zero (succ m'))")))
            '(121 2)))

;; Info Parsing
;; ================
(defun lean-info-list-split (str)
  "Parse string into list of list of strings.

Take out \"BEGININFO\" and \"ENDINFO\" and Use \"ACK\" as a delim."
  (-split-on "-- ACK"
             (--filter (not (or (string-prefix-p "-- BEGININFO" it)
                                (string= "-- ENDINFO" it)))
                       (split-string str "\n"))))

(defun lean-info-list-parse-string (str)
  "Parse string into info-list"
  (let ((string-seq-seq (lean-info-list-split str))
        result)
    (cl-loop for string-seq in string-seq-seq
             when string-seq
             do (setq result
                      (or (lean-info-type-parse string-seq)
                          (lean-info-overload-parse string-seq)
                          (lean-info-synth-parse string-seq)
                          (lean-info-coercion-parse string-seq)
                          (lean-info-identifier-parse string-seq)
                          (lean-info-symbol-parse string-seq)))
             when result
             collect result)))

(defun lean-info-list-filter (info-list start-column)
  "Given a info-list, only return an info-item is NAY or whose start-column is matched with the argument."
  (--filter (let ((col (lean-info-column it)))
              (and col (= start-column col)))
            info-list))

(defun lean-get-partial-names (full-name)
  "Given a full-name \"a.b.c.d\", return a set of partial names (\"a.b.c.d\" \"b.c.d\" \"c.d\" \"d\")"
  (cl-labels ((helper(l1 l2 names)
                  (cond (l1 (helper
                             (-butlast l1)
                             (cons nil (-butlast l2))
                             (-zip-with (lambda (x y) (if y (concat x "." y) x))
                                        names
                                        (cons nil (-butlast l2)))))
                        (t (reverse names)))))
    (let ((items (reverse (split-string full-name "\\."))))
      (helper items items items))))

(defun lean-match-name-at-pos (file-name line-number column-number name)
  "Return t if there is name at pos in a file."
  ;; Try to use a existing buffer if there is one
  (let ((buffer (flymake-find-buffer-for-file file-name))
        str pos)
    (unless buffer
      ;; In case a user haven't opened the file before, we read the
      ;; file to the temp buffer (*lean-server-temp*) and proceed.
      (setq buffer (get-buffer-create "*lean-server-temp*"))
      (with-current-buffer buffer
        (erase-buffer)
        (insert-file-contents file-name)))
    (with-current-buffer buffer
      (save-excursion
        (goto-char (point-min))
        (forward-line (1- line-number))
        (forward-char column-number)
        (setq pos (point))
        (setq str (buffer-substring-no-properties pos
                                                  (min (+ pos (length name))
                                                       (point-max))))
        (string= name str)))))

(defun lean-match-full-name-at-pos (file-name line-number column-number full-name)
  "Return the matched name for the given full-name if any."
  (let ((partial-names (lean-get-partial-names full-name)))
    (--first (lean-match-name-at-pos file-name line-number column-number it) partial-names)))

(defun lean-info-list-find-start-column (info-list file-name column-number)
  "Find the start-column of the id/symbol in info-list at a file-name/column-number"

  ;; Extract symbol, ids
  (let* ((sorted-id-symbol-list
          (-sort (-on '< 'lean-info-column)
                 (--filter (or (lean-info-identifier-p it)
                               (lean-info-symbol-p it))
                           info-list)))
         ;; candidate = list of info
         (candidate-list
          (-last-item
           (-partition-by 'lean-info-column
                          (--filter (<= (lean-info-column it) column-number)
                                    sorted-id-symbol-list))))
         matched-name
         start-column
         full-name
         candidate)
    (setq candidate
          (-first (lambda (info)
                    (let* ((start-column (lean-info-column info))
                           (full-name (lean-info-id-symbol-body-str info))
                           (matched-name (lean-match-full-name-at-pos
                                          file-name
                                          (lean-info-line-number info)
                                          start-column
                                          full-name)))
                      (< column-number
                         (+ start-column (length matched-name)))))
                  candidate-list))
    (when candidate
      (lean-info-column candidate))))

(defun lean-info-list-parse (str &optional file-name column-number)
  "Parse input string and return info-list."
  (let ((info-list (lean-info-list-parse-string str))
        start-column)
    (cond
     ;; When file-name/column-number is specified, try to start-column of id/symbol
     ((and file-name column-number)
      (setq start-column (lean-info-list-find-start-column info-list file-name column-number))
      (if start-column
          (lean-info-list-filter info-list start-column)
        ;; If there is no symbol at column-number, return nil
        nil))
     ;; When not specified, just return info-list.
     (t info-list))))

(cl-defstruct lean-info-record type overload synth coercion identifier symbol nay stale)

(defun lean-info-record-parse (string &optional file-name column-number)
  "Parse string into info-record"
  (let* ((info-list   (lean-info-list-parse string file-name column-number))
         (types       (-filter 'lean-info-type-p       info-list))
         (overloads   (-filter 'lean-info-overload-p   info-list))
         (synths      (-filter 'lean-info-synth-p      info-list))
         (coercions   (-filter 'lean-info-coercion-p   info-list))
         (identifiers (-filter 'lean-info-identifier-p info-list))
         (symbols     (-filter 'lean-info-symbol-p     info-list)))
    (make-lean-info-record :type       types
                           :overload   overloads
                           :synth      synths
                           :coercion   coercions
                           :identifier identifiers
                           :symbol     symbols
                           :nay        (lean-info-nay-p   string)
                           :stale      (lean-info-stale-p string))))

(defun lean-info-record-to-string (info-record)
  "Given typeinfo, overload, and sym-name, compose string information."
  (let* ((type     (cl-first (lean-info-record-type       info-record)))
         (overload (cl-first (lean-info-record-overload   info-record)))
         (synth    (cl-first (lean-info-record-synth      info-record)))
         (coercion (cl-first (lean-info-record-coercion   info-record)))
         (id       (cl-first (lean-info-record-identifier info-record)))
         (sym      (cl-first (lean-info-record-symbol     info-record)))
         (stale    (lean-info-record-stale                info-record))
         name-str type-str coercion-str overload-str str)
    (setq name-str
          (cond
           (synth (lean-info-synth-body-str synth))
           ((and id sym)
            (format "[%s] %s"
                    (lean-info-id-symbol-body-str sym)
                    (lean-info-id-symbol-body-str id)))
           (id   (lean-info-id-symbol-body-str id))
           (sym  (lean-info-id-symbol-body-str sym))))
    (when coercion
      (setq coercion-str (lean-info-coercion-body-str coercion)))
    (when type
      (setq type-str (lean-info-type-body-str type)))
    (when (and name-str overload)
      (setq overload-str
            (string-join
             (--remove
              (or
               (and id  (string-prefix-p (lean-info-id-symbol-body-str id) it))
               (and sym (string-prefix-p (lean-info-id-symbol-body-str sym) it)))
              (lean-info-overload-names overload))
             ", ")))
    (when (and name-str type-str)
      (setq str (format "%s : %s"
                        (propertize name-str 'face 'font-lock-variable-name-face)
                        type-str)))
    (when (and str coercion-str)
      (setq str (format "%s (%s)"
                        (propertize coercion-str 'face 'font-lock-keyword-face)
                        str)))
    (when overload-str
      (setq str (concat str
                        (format "\n%s with %s"
                                (propertize "overloaded" 'face 'font-lock-keyword-face)
                                overload-str))))
    (when stale
      (setq str (format "[%s] %s"
                        (propertize "stale" 'face '(foreground-color . "red"))
                        str)))
    str))

(defun lean-get-info-record-at-point (cont)
  "Get info-record at the current point"
  (let ((file-name (buffer-file-name))
        (line-number (line-number-at-pos)))
    (lean-server-check-current-file file-name)
    (lean-server-send-cmd (lean-cmd-info line-number)
                          cont)))

(defun lean-get-full-name-at-point-cont (info-record)
  "Continuation of lean-get-full-name-at-point"
  (let ((id (cl-first (lean-info-record-identifier info-record))))
    (when id
      (lean-info-identifier-body-str id))))

(defun lean-get-full-name-at-point (cont)
  "Return the full-name at point (if any)"
  (lean-get-info-record-at-point
   (lambda (info-record)
     (funcall cont
              (lean-get-full-name-at-point-cont info-record)))))

(provide 'lean-info)
