(defpackage #:tui-backend-terminal/tests
  (:use #:cl #:rove)
  (:local-nicknames (#:tui #:tui-protocol) (#:tp #:terminal-protocol)
                    (#:h #:tui-backend-terminal)))
(in-package #:tui-backend-terminal/tests)

(defparameter *emulators*
  (list (cons "lisp" (lambda () (make-instance 'terminal-backend-lisp:lisp-backend)))
        (cons "ghostty" (lambda () (make-instance 'terminal-backend-ghostty:ghostty-backend)))))

(defmacro do-emulators ((name backend) &body body)
  `(loop for (,name . make) in *emulators*
         do (let ((,backend (funcall make))) ,@body)))
