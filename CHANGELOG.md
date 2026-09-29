# Changelog

## 0.3.0

- Localize the interface in English, Spanish, Italian, French, German and
  Portuguese. It follows the macOS language by default; an **Interface
  language** menu (panel and menu bar) overrides it and applies immediately.
  Dictation language remains a separate setting.
- Usage-window labels are derived from stable ids, so snapshots cached in an
  earlier language render in the current one.
- Regression suite checks every string has all translations with matching
  format specifiers.

## 0.2.1

- Show a small blinking red microphone in the compact panel's Codex wing while
  listening, safely outside the camera cutout. Preparation and transcription use
  orange indicators; idle restores the usage ring without resizing the panel.
- Respect Reduce Motion with a steady recording indicator.

## 0.2.0

- Fix stale `@Published` reads causing clipped expansion, delayed resizing and
  black space after collapse. Measure SwiftUI content and reserve the actual
  camera exclusion area.
- Respect modified Space shortcuts; preserve typing order and cancel a held
  press when focus/session changes. Retry permission checks in the GUI process.
- Add explicit voice-permission setup and sanitized GUI diagnostics.
- Allow retry after voice errors, cancel preparation on release and avoid
  automatic panel expansion during voice startup.
- Convert native microphone audio to the analyzer format, clean up partial
  startup/finalization and propagate analysis failures.
- Validate the original paste destination, preserve clipboard representations
  and keep a Copy fallback. Label synthetic insertion as an attempted paste.
- Show usage source, age, stale state and refresh errors. Harden numeric parsing
  and empty Codex bucket fallback; bound/drain/cancel usage subprocesses.
- Preserve login preference and manage fallback registration. Stop the installed
  process before replacing it and launch one updated copy.
- Add twelve portable behavioral regressions plus an XCTest wrapper. The four
  original parser/format tests remain.

Validation: release build with warnings as errors, portable regressions, parser
tests and installed-GUI layout checks. Real microphone dictation, physical
shortcut behavior and next-login launch still need user/device validation.
The final installed GUI confirmed Accessibility, microphone and speech permission
plus an active event tap. OS approval cannot be supplied by the application or
inferred from a separate terminal process.
