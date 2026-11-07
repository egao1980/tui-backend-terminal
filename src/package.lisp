(defpackage #:tui-backend-terminal
  (:use #:cl)
  (:local-nicknames (#:tui #:tui-protocol) (#:tp #:terminal-protocol))
  (:export #:terminal-tui-backend #:tui-backend-terminal-of
           #:headless-tui #:make-headless-tui #:headless-tui-terminal #:headless-tui-backend
           #:tui-press #:tui-type #:tui-paste #:tui-click #:tui-focus #:tui-resize
           #:tui-screen #:tui-snapshot #:tui-wait-for #:tui-wait-until #:tui-stop
           #:tui-result #:tui-running-p))
