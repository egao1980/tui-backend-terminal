# tui-backend-terminal

Headless [`tui-protocol`](https://github.com/egao1980/tui-protocol) backend: the "terminal" is any [`terminal-protocol`](https://github.com/egao1980/terminal-protocol) emulator (ghostty or pure Lisp). Use it to test TUIs, drive them from agents, or embed one TUI inside another program.

```lisp
(let ((tui (tui-backend-terminal:make-headless-tui (make-instance 'my-app) :cols 80 :rows 24)))
  (tui-backend-terminal:tui-wait-for tui "Ready")
  (tui-backend-terminal:tui-type tui "hello")
  (tui-backend-terminal:tui-press tui :enter)
  (tui-backend-terminal:tui-press tui :arrow-down :modifiers '(:shift))
  (tui-backend-terminal:tui-click tui 10 3)           ; for programs started with :mouse t
  (tui-backend-terminal:tui-resize tui 100 30)
  (tui-backend-terminal:tui-screen tui)               ; ⇒ ("┌─ my app ─…" …)
  (tui-backend-terminal:tui-stop tui))                ; ⇒ the final model
```

- The program runs on its own thread with `run-tui`.
- Everything it writes goes through the emulator, and the emulator's replies come back as input.
- Keys, mouse, paste and focus are encoded by the emulator in its live modes, so the program receives exactly the bytes a real terminal would send.
- `tui-wait-for` / `tui-wait-until` poll the screen. A program error is re-signalled from the waiting call.

The tests run the same app on both emulators. They also check that `tui-protocol`'s renderer reproduces a canvas cell for cell in ghostty as well as in the pure-Lisp emulator.

## License

MIT
