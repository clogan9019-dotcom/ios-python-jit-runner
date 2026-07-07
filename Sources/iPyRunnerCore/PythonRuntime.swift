import Foundation

public protocol PythonRuntime: AnyObject {
    var state: RuntimeState { get }
    var jitStatus: JITStatus { get }

    func start() async throws
    func stop() async
    func run(code: String, filename: String?) async throws -> RunResult
    func installPackage(_ specifier: String) async throws -> String
    func listPackages() async throws -> [PackageInfo]
}

public final class EmbeddedPythonRuntime: PythonRuntime, ObservableObject {
    @Published public private(set) var state: RuntimeState = .stopped
    @Published public private(set) var jitStatus: JITStatus

    private let packageManager: PackageManager
    private let jitController: JITController

    public init(packageManager: PackageManager = PackageManager(), jitController: JITController = JITController()) {
        self.packageManager = packageManager
        self.jitController = jitController
        self.jitStatus = jitController.detect()
    }

    public func start() async throws {
        state = .starting
        jitStatus = jitController.detect()

        // TODO: Initialize embedded Python here.
        // Expected steps:
        // 1. Locate bundled Python.xcframework resources.
        // 2. Set PYTHONHOME/PYTHONPATH to app sandbox + bundled stdlib.
        // 3. Call Py_InitializeFromConfig or your wrapper.
        // 4. Run PythonRuntime/bootstrap.py.

        state = .ready
    }

    public func stop() async {
        // TODO: Stop or reset interpreter if your embedded runtime supports it.
        state = .stopped
    }

    public func run(code: String, filename: String? = nil) async throws -> RunResult {
        if state == .stopped { try await start() }
        state = .running
        let startTime = Date()

        // TODO: Replace this mock result with a real call into Python.
        // Capture stdout/stderr using Python file-like objects or C API hooks.
        let output = "[mock iOS runtime] Would run \(filename ?? "<string>")\n\n\(code)"

        state = .ready
        return RunResult(exitCode: 0, stdout: output, stderr: "", duration: Date().timeIntervalSince(startTime))
    }

    public func installPackage(_ specifier: String) async throws -> String {
        try await packageManager.install(specifier: specifier)
    }

    public func listPackages() async throws -> [PackageInfo] {
        try await packageManager.listInstalled()
    }
}
