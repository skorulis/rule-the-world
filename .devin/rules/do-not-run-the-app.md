---
description: Do not build, run, or test the iOS app unless the user explicitly asks
trigger: always_on
---

# Do not build, run, or test the app

Building the app, launching the Simulator, and running the test suite all waste a lot of time and tokens and frequently get stuck on environment issues. The user can build and test much faster on their end.

- **Do not** run `xcodebuild` (build or test), `swift test`, `xcrun simctl`, open Xcode, boot a simulator, or attempt to launch/screenshot/drive the app unless the user **explicitly asks** for it.
- **Do not** run unit or UI tests, even "just the one file" — this applies to the test suite as much as to the app itself.
- Verify changes by reading the code carefully: check types, signatures, call sites, and existing patterns. `swiftlint` on changed files is fine if useful.
- Still write/update tests when appropriate — just don't execute them.
- When a change is done, hand it back to the user to build and test, and tell them what to look for and which tests you added or changed.
- If you believe building or testing is genuinely necessary, **ask first** and explain why instead of just doing it.
