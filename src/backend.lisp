(in-package #:tui-backend-terminal)

;;; A tui-protocol backend whose "terminal" is a terminal-protocol emulator.
;;; What the program writes is fed to the emulator; what you type is encoded
;;; by the emulator (in its live modes) and queued as the program's input.
;;; The emulator's replies (cursor reports, …) are queued as input too.

(defclass terminal-tui-backend (tui:tui-backend)
  ((terminal :initarg :terminal :reader tui-backend-terminal-of)
   (input :initform '() :accessor %input)
   (lock :initform (bt2:make-lock :name "headless-input") :reader %lock)
   (ready :initform (bt2:make-condition-variable) :reader %ready)
   (closed :initform nil :accessor %closed)
   (writes :initform 0 :accessor %writes
           :documentation "Frames written so far; tests wait on it.")))

(defun %push-input (backend octets)
  (when (plusp (length octets))
    (bt2:with-lock-held ((%lock backend))
      (setf (%input backend) (append (%input backend) (list octets)))
      (bt2:condition-notify (%ready backend)))))

(defun %close-input (backend)
  (bt2:with-lock-held ((%lock backend))
    (setf (%closed backend) t)
    (bt2:condition-notify (%ready backend))))

(defmethod tui:backend-start ((b terminal-tui-backend) &key alt-screen mouse)
  (declare (ignore alt-screen mouse))
  (tp:terminal-size (tui-backend-terminal-of b)))

(defmethod tui:backend-stop ((b terminal-tui-backend)) nil)

(defmethod tui:backend-size ((b terminal-tui-backend))
  (bt2:with-lock-held ((%lock b))
    (tp:terminal-size (tui-backend-terminal-of b))))

(defmethod tui:backend-write ((b terminal-tui-backend) octets)
  (let (replies)
    (bt2:with-lock-held ((%lock b))
      (let ((term (tui-backend-terminal-of b)))
        (tp:terminal-feed term octets)
        (setf replies (tp:terminal-take-replies term))
        (incf (%writes b))))
    (%push-input b replies)))

(defmethod tui:backend-read ((b terminal-tui-backend) &key timeout)
  (bt2:with-lock-held ((%lock b))
    (loop
      (cond ((%input b)
             (return (let ((all (%input b)))
                       (setf (%input b) '())
                       (apply #'concatenate '(simple-array (unsigned-byte 8) (*)) all))))
            ((%closed b) (return nil))
            (t (unless (bt2:condition-wait (%ready b) (%lock b) :timeout (or timeout 1))
                 (unless (%input b)
                   (return (if (%closed b) nil
                               (make-array 0 :element-type '(unsigned-byte 8)))))))))))
