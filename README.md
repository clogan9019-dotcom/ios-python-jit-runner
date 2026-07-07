# iOS Python JIT Runner

A starter project for an iOS Python runner app with:

- SwiftUI code editor + console UI
- Embedded Python runtime integration points
- Optional JIT acceleration checks/hooks
- Pure-Python package installation workflow
- Sandboxed file/project manager
- Desktop mock runner for testing package installs and script execution

> Important: iOS places strict limits on JIT and dynamic code execution. This project only targets legitimate development/test scenarios where the device/profile has the needed Apple-supported permissions. It does **not** include jailbreak bypasses, exploit code, or App Store policy circumvention.

## Status

This is a GitHub-ready starter template, not a finished App Store product. It gives you the structure for building an app like Pythonista/Pyto-style runners.

## What works now

The repo includes a desktop mock runner so you can test the runner concept immediately:

```bash
python Scripts/dev_runner.py run examples/hello.py
python Scripts/dev_runner.py pip install requests
python Scripts/dev_runner.py run examples/packages_demo.py
```

## iOS architecture

```text
SwiftUI App
  ├─ EditorView          code editor screen
  ├─ ConsoleView         stdout/stderr display
  ├─ PackagesView        install/list/remove packages
  ├─ FilesView           sandbox project browser
  └─ SettingsView        runtime/JIT settings

Core
  ├─ PythonRuntime       protocol + embedded runtime wrapper
  ├─ JITController       detects/configures JIT availability
  ├─ PackageManager      pure-Python package install logic
  ├─ SandboxFileSystem   safe project/file storage
  └─ RunnerModels        shared models

PythonRuntime/
  ├─ bootstrap.py        runtime bootstrap script
  └─ sitecustomize.py    package path setup
```

## Install fix: no embedded core framework

The app compiles `Sources/iPyRunnerCore` directly into the main app target instead of embedding a separate `iPyRunnerCore.framework`. This avoids iOS install errors like:

```text
PackageInspectionFailed: Failed to load Info.plist from ... iPyRunnerCore.framework
```

That error happens when an embedded framework is malformed or missing its own `Info.plist`. Since the core code does not need to be a separate dynamic framework, the clean fix is to make it part of the app binary.

## IPA maker workflow

This repo now includes a GitHub Actions IPA builder based on the style of your `controller` / `ios-location-spoofer` workflows:

```text
.github/workflows/build-ipa.yml
```

What it does:

1. Runs on `macos-14`
2. Installs `xcodegen`
3. Generates `iPyRunner.xcodeproj` from `project.yml`
4. Builds an unsigned iOS archive
5. Packages `Payload/iPyRunner.app` into `iPyRunner.ipa`
6. Does **not** run `ldid` or any signing step
7. Uploads the IPA artifact
8. Publishes/updates a `latest` prerelease on pushes to `main`

You can also run it manually from the repo's **Actions** tab.

## Local Xcode project generation

Install XcodeGen and fetch the Python iOS runtime:

```bash
brew install xcodegen
Scripts/fetch_python_ios_runtime.sh
xcodegen generate
open iPyRunner.xcodeproj
```

The Python runtime fetch script downloads the latest iOS support archive from BeeWare `Python-Apple-support` and places:

```text
Frameworks/Python.xcframework
iPyRunner/python/
```

Those generated runtime files are intentionally gitignored because they are large.

## Current runtime status: crash-safe Swift shell

The current IPA intentionally does **not** link `Python.xcframework`. This is to avoid instant launch crashes from iOS dynamic loader/framework packaging issues while the app shell is being tested on-device.

Current behavior:

- App launches as a SwiftUI shell.
- Editor, console, settings, and package screens open.
- The Run button reports what code would run.
- The package screen can contact PyPI and download pure-Python wheels into the sandbox.

Next implementation step after confirming the app opens:

1. Pull a device crash log if a Python-linked build crashes.
2. Re-enable `Python.xcframework` as an embedded framework or static linkage path.
3. Add stdout/stderr capture and real `PyRun_SimpleStringFlags` execution.

Native packages still require iOS-compatible prebuilt wheels.

## JIT notes

JIT on iOS is restricted. In practice, JIT may only be available in specific circumstances such as development/debug builds or special entitlements/profiles. The `JITController` included here is designed to:

- Detect whether JIT appears available
- Expose a clear status message to the UI
- Fall back to normal interpreted Python when JIT is unavailable

This repo intentionally avoids unsafe destructive behavior or platform bypasses.

## Python packages

The package manager is designed around **pure-Python packages**.

Native extension packages like `numpy`, `pandas`, `cryptography`, etc. generally need prebuilt iOS-compatible wheels or custom bundling. The package manager can reject unsupported wheels and keep packages inside the app sandbox.

## Building the iOS app

You still need to add/provide an iOS-compatible Python distribution, for example:

```text
Frameworks/Python.xcframework
```

Then wire it into Xcode and implement the low-level C/Python bridge in `EmbeddedPythonRuntime`.

Recommended next step:

1. Create a new iOS SwiftUI app in Xcode named `iPyRunner`.
2. Copy `Sources/iPyRunnerApp` and `Sources/iPyRunnerCore` into the app target.
3. Add your `Python.xcframework`.
4. Implement the TODOs in `EmbeddedPythonRuntime.swift`.

## Desktop development runner

The mock runner stores packages in:

```text
.local_runner/site-packages
```

Run a Python script:

```bash
python Scripts/dev_runner.py run examples/hello.py
```

Install a package:

```bash
python Scripts/dev_runner.py pip install rich
```

List installed packages:

```bash
python Scripts/dev_runner.py pip list
```

## Repo layout

```text
Sources/iPyRunnerApp/      SwiftUI app screens
Sources/iPyRunnerCore/     Core runtime/package/JIT/file abstractions
PythonRuntime/             Python bootstrap scripts
Scripts/                   Desktop helper scripts
examples/                  Example Python scripts
Docs/                      Extra documentation
Tests/                     Python tests for helper scripts
```

## Safety goals

- No permanent deletes by default
- Package installs stay in app sandbox
- JIT gracefully falls back when unavailable
- No jailbreak/exploit/bypass code
- Clear UI status for runtime and JIT availability

## License

MIT
