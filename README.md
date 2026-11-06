# Self-Discipline Check

A small watch-only Apple Watch app (watchOS 10+) for a daily self-discipline streak.

- **Today:** your streak in a ring that fills towards the next goal. Every day counts unless you reset it, including days you don't open the app.
- **History:** the last 28 days at a glance, plus best streak, total clean days and resets.
- **Reset:** starts again from tomorrow and keeps earlier days. Tap by mistake? Undo it until midnight.
- **Breathe 60s:** a guided one-minute pause for when an urge hits.

All data stays on the watch. There is no account, server or network code.

## Building

`xcodegen generate`, then open `RebootWatch.xcodeproj` (`ci/render_icon.sh` renders the app icon first; it needs `librsvg`). Pushes to `feature/**` run the logic tests in `Tests/` and an unsigned build.

`Upload to TestFlight` is started by hand on `main` by the repository owner. Signing material is kept in a separate private repository; the key and password are GitHub secrets and are never stored here.
