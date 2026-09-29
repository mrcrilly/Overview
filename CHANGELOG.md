# Changelog

## Unreleased

- Add GitHub Actions builds for pull requests and `main`, and publish a GitHub
  Release when a version tag is pushed, with a universal macOS DMG containing
  `Overview.app`.
- Add a reusable build and packaging script and release instructions in
  `docs/RELEASING.md`. Builds use ad-hoc signing without Apple credentials.

## 2026-09-29 — Recover capture streams after system interruption

Commit: `216834d8b1052be13f4261b56e03972385d41d21`

Original commit title: “Recover ScreenCaptureKit streams after system interruption”

### Issue

A system interruption could stop a live window preview without capture resuming
automatically. The coordinator treated ScreenCaptureKit's `systemStoppedStream`
error as fatal, stopping capture and clearing the preview. Other recoverable errors
attempted to restart through `startCapture()`, but its `isCapturing` guard could
return immediately while the old capture state was still active. A stream ending
without an error also stopped capture without attempting recovery.

### Fix

- Treat the system-stopped error (raw code `-3821`) as recoverable, using its raw
  value to avoid requiring the typed API introduced in macOS 15.
- Separate the user's intent to capture from the stream's active state, and start
  replacement streams through a dedicated helper.
- Release the interrupted engine state, then make up to three recovery attempts,
  waiting 1, 2, and 5 seconds before the respective attempts.
- Refresh available windows for each attempt. Match the source by window ID,
  then by application bundle identifier and title, then by application name and
  title, allowing recovery when the original window ID changes.
- Retain the last captured frame and public capture state during recovery so the
  preview does not switch back to the source picker while retrying.
- Recover from unexpected stream completion and other nonfatal stream errors.
- Prevent duplicate recovery tasks, cancel pending recovery when capture is
  explicitly stopped, and use capture generations to ignore stale frame tasks.
- Clear capture state and the displayed frame if all three attempts fail.
  Other fatal stream errors continue to stop capture.

### Related changes

- Include ScreenCaptureKit error codes and recovery-attempt details in diagnostics.
- Make error-log messages public in OSLog so their details are visible for
  troubleshooting; debug and informational messages retain default privacy.
- Ignore `.DS_Store` files and the `.build/` directory.

### User-visible result

Interrupted previews can resume automatically when their source window becomes
available during the retry window. The previous frame stays visible while recovery
is attempted; unavailable sources still stop after the bounded retries.
