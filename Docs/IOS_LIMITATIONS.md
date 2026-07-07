# iOS Limitations

## JIT

iOS restricts JIT compilation. This project exposes JIT status and hooks, but does not bypass platform restrictions. If JIT is unavailable, the runner falls back to normal interpreted Python.

## Packages

Pure-Python packages are the easiest to support. Native packages need iOS-compatible builds and cannot be compiled freely on-device in a normal App Store-style sandbox.

## Downloaded code

If you intend to distribute an app, review Apple policies about downloaded executable code, scripting, and interpreters. This starter is intended for learning, personal development, and legitimate development profiles.
