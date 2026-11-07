(defsystem "tui-backend-terminal"
  :version "0.1.0"
  :description "Headless tui-protocol backend on any terminal-protocol emulator: drive and inspect TUIs in tests"
  :author "egao1980"
  :license "MIT"
  :depends-on ("tui-protocol" "terminal-protocol" "bordeaux-threads")
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "backend")
               (:file "headless"))
  :in-order-to ((test-op (test-op "tui-backend-terminal/tests"))))

(defsystem "tui-backend-terminal/tests"
  :depends-on ("tui-backend-terminal" "terminal-backend-lisp" "terminal-backend-ghostty" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "headless-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
