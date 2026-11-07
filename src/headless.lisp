(in-package #:tui-backend-terminal)

;;; A TUI running on its own thread against an emulator, driven like a user
;;; would drive it: keys, text, clicks, paste, resizes. Read back the screen
;;; the emulator shows.

(defstruct (headless-tui (:constructor %make-headless-tui))
  backend thread
  (result nil) (error nil) (done nil))

(defun headless-tui-terminal (tui) (tui-backend-terminal-of (headless-tui-backend tui)))

(defun make-headless-tui (program &key (cols 80) (rows 24) terminal-backend mouse
                                       (alt-screen t))
  "Start PROGRAM on a fresh COLS × ROWS emulator from TERMINAL-BACKEND
(default TERMINAL-PROTOCOL:*TERMINAL-BACKEND*). → a HEADLESS-TUI."
  (let* ((term (tp:make-terminal :cols cols :rows rows
                                 :backend (or terminal-backend tp:*terminal-backend*)))
         (backend (make-instance 'terminal-tui-backend :terminal term))
         (tui (%make-headless-tui :backend backend)))
    (setf (headless-tui-thread tui)
          (bt2:make-thread
           (lambda ()
             (handler-case
                 (setf (headless-tui-result tui)
                       (tui:run-tui program :backend backend :mouse mouse :alt-screen alt-screen))
               (error (e) (setf (headless-tui-error tui) e)))
             (setf (headless-tui-done tui) t))
           :name "headless-tui"))
    (tui-wait-until tui (lambda () (plusp (%writes backend))))
    tui))

(defun tui-running-p (tui) (not (headless-tui-done tui)))

(defun %with-terminal (tui function)
  (let ((b (headless-tui-backend tui)))
    (bt2:with-lock-held ((%lock b))
      (funcall function (tui-backend-terminal-of b)))))

(defun %send (tui octets)
  (%push-input (headless-tui-backend tui) octets)
  tui)

(defun tui-press (tui key &rest keys &key text modifiers action)
  "Press KEY (a terminal-protocol key name) as the emulator would encode it."
  (declare (ignore text modifiers action))
  (%send tui (%with-terminal tui (lambda (term) (apply #'tp:encode-key term key keys)))))

(defun tui-type (tui string)
  "Type STRING, one key per character."
  (loop for ch across string
        do (%send tui (%with-terminal
                       tui (lambda (term)
                             (multiple-value-bind (key shifted) (tui:char-key ch)
                               (tp:encode-key term key :text (string ch)
                                                       :modifiers (when shifted '(:shift))))))))
  tui)

(defun tui-paste (tui string)
  (%send tui (%with-terminal tui (lambda (term) (tp:encode-paste term string)))))

(defun tui-focus (tui focused-p)
  (%send tui (%with-terminal tui (lambda (term) (tp:encode-focus term focused-p)))))

(defun tui-click (tui x y &key (button :left) modifiers)
  "Press and release BUTTON at cell X, Y (needs a program started with :MOUSE T)."
  (%send tui (%with-terminal
              tui (lambda (term)
                    (concatenate '(vector (unsigned-byte 8))
                                 (tp:encode-mouse term button :press x y :modifiers modifiers)
                                 (tp:encode-mouse term button :release x y :modifiers modifiers))))))

(defun tui-resize (tui cols rows)
  "Resize the emulator; the program sees a RESIZE-MESSAGE on its next read."
  (%with-terminal tui (lambda (term) (tp:terminal-resize term cols rows)))
  (%send tui (make-array 0 :element-type '(unsigned-byte 8))))

(defun tui-wait-until (tui predicate &key (timeout 5))
  "Poll PREDICATE until true. → its value, or NIL on timeout. Signals the
program's error if it died."
  (let ((deadline (+ (get-internal-real-time) (* timeout internal-time-units-per-second))))
    (loop
      (let ((v (funcall predicate)))
        (when v (return v)))
      (when (headless-tui-error tui) (error (headless-tui-error tui)))
      (when (> (get-internal-real-time) deadline) (return nil))
      (sleep 0.01))))

(defun tui-screen (tui)
  "→ the emulator's viewport as one string per row."
  (%with-terminal tui (lambda (term) (getf (tp:terminal-snapshot term :cells nil) :lines))))

(defun tui-snapshot (tui)
  "→ TERMINAL-PROTOCOL:TERMINAL-SNAPSHOT of the emulator."
  (%with-terminal tui #'tp:terminal-snapshot))

(defun tui-wait-for (tui needle &key (timeout 5))
  "Wait until NEEDLE appears on screen. → T, or NIL on timeout."
  (and (tui-wait-until tui (lambda () (some (lambda (line) (search needle line)) (tui-screen tui)))
                       :timeout timeout)
       t))

(defun tui-stop (tui &key (timeout 5))
  "End input and wait for the program. → its final model (or re-signal its
error). The emulator is closed."
  (%close-input (headless-tui-backend tui))
  (tui-wait-until tui (lambda () (headless-tui-done tui)) :timeout timeout)
  (when (headless-tui-error tui) (error (headless-tui-error tui)))
  (tp:terminal-close (headless-tui-terminal tui))
  (headless-tui-result tui))

(defun tui-result (tui &key (timeout 5))
  "Wait for the program to finish on its own (e.g. after a quit key). → model."
  (tui-wait-until tui (lambda () (headless-tui-done tui)) :timeout timeout)
  (when (headless-tui-error tui) (error (headless-tui-error tui)))
  (headless-tui-result tui))
