(in-package #:tui-backend-terminal/tests)

;;; A small app: a counter, a log of what it received, and the size.

(defclass app () ())
(defstruct model (count 0) (log '()) (cols 0) (rows 0))

(defmethod tui:tui-init ((p app)) (values (make-model) nil))

(defmethod tui:tui-update ((p app) m (msg tui:key-message))
  (case (tui:key-message-key msg)
    (:equal (incf (model-count m)))
    (:minus (decf (model-count m)))
    (:q (return-from tui:tui-update (values m :quit)))
    (:x (when (member :ctrl (tui:key-message-modifiers msg)) (error "boom")))
    (t (push (format nil "key ~(~A~)~@[ ~A~]" (tui:key-message-key msg) (tui:key-message-text msg))
             (model-log m))))
  (values m nil))

(defmethod tui:tui-update ((p app) m (msg tui:mouse-message))
  (when (eq (tui:mouse-message-action msg) :press)
    (push (format nil "click ~D,~D" (tui:mouse-message-x msg) (tui:mouse-message-y msg))
          (model-log m)))
  (values m nil))

(defmethod tui:tui-update ((p app) m (msg tui:paste-message))
  (push (format nil "paste ~A" (tui:paste-message-text msg)) (model-log m))
  (values m nil))

(defmethod tui:tui-update ((p app) m (msg tui:resize-message))
  (setf (model-cols m) (tui:resize-message-cols msg) (model-rows m) (tui:resize-message-rows msg))
  (values m nil))

(defmethod tui:tui-update ((p app) m msg) (declare (ignore msg)) (values m nil))

(defmethod tui:tui-view ((p app) m canvas)
  (tui:draw-box canvas 0 0 (tui:canvas-cols canvas) (tui:canvas-rows canvas) :title "app")
  (tui:draw-text canvas 2 1 (format nil "count ~D  size ~Dx~D" (model-count m)
                                    (tui:canvas-cols canvas) (tui:canvas-rows canvas)))
  (loop for line in (model-log m) for y from 2 below (1- (tui:canvas-rows canvas))
        do (tui:draw-text canvas 2 y line)))

(deftest keys-drive-the-app
  (do-emulators (name backend)
    (let ((tui (h:make-headless-tui (make-instance 'app) :cols 30 :rows 8 :terminal-backend backend)))
      (ok (h:tui-wait-for tui "count 0") name)
      (h:tui-type tui "++")
      (ok (h:tui-wait-for tui "count 2") name)
      (h:tui-press tui :arrow-up)
      (ok (h:tui-wait-for tui "key arrow-up") name)
      (h:tui-type tui "q")
      (ok (= 2 (model-count (h:tui-result tui))) name))))

(deftest resize-redraws
  (do-emulators (name backend)
    (let ((tui (h:make-headless-tui (make-instance 'app) :cols 30 :rows 6 :terminal-backend backend)))
      (ok (h:tui-wait-for tui "size 30x6") name)
      (h:tui-resize tui 40 7)
      (ok (h:tui-wait-for tui "size 40x7") name)
      (ok (= 40 (length (first (h:tui-screen tui)))) name)
      (h:tui-stop tui))))

(deftest mouse-and-paste
  (do-emulators (name backend)
    (let ((tui (h:make-headless-tui (make-instance 'app) :cols 30 :rows 8 :terminal-backend backend
                                                         :mouse t)))
      (h:tui-wait-for tui "count 0")
      (h:tui-click tui 5 3)
      (ok (h:tui-wait-for tui "click 5,3") name)
      (h:tui-paste tui "hi there")
      (ok (h:tui-wait-for tui "paste hi there") name)
      (h:tui-stop tui))))

(deftest program-errors-surface-and-restore
  (do-emulators (name backend)
    (let ((tui (h:make-headless-tui (make-instance 'app) :cols 30 :rows 6 :terminal-backend backend)))
      (h:tui-wait-for tui "count 0")
      (h:tui-press tui :x :text "x" :modifiers '(:ctrl))
      (ok (signals (h:tui-result tui) 'simple-error) name)
      ;; run-tui restored the terminal on the way out.
      (ng (tp:terminal-mode (h:headless-tui-terminal tui) :bracketed-paste) name)
      (ng (tp:terminal-mode (h:headless-tui-terminal tui) :alt-screen-save-cursor-clear) name))))

;;; The renderer, checked by both emulators (tui-protocol's own tests use only
;;; the pure-Lisp one).

(deftest renderer-matches-every-emulator
  (do-emulators (name backend)
    (tp:with-terminal (term :backend backend :cols 24 :rows 4)
      (let ((c (tui:make-canvas 24 4)))
        (tui:draw-box c 0 0 24 4 :title "both" :style (tp:make-style :foreground (tp:make-rgb 1 2 3)))
        (tui:draw-text c 2 1 "日本 wide" :style (tp:make-style :bold t :underline :curly))
        (tui:draw-text c 2 2 "link" :style (tp:make-style :hyperlink "https://x.test/"))
        (tp:terminal-feed term (tui:render-full c))
        (let ((cells (getf (tp:terminal-snapshot term) :cells)))
          (ok (loop for y below 4
                    always (loop for x below 24
                                 always (equalp (aref (aref cells y) x) (tui:canvas-cell c x y))))
              name))))))
