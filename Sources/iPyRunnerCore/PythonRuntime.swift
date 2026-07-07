import Foundation
import Combine

#if canImport(Python)
import Python
#endif

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

        #if canImport(Python)
        configurePythonEnvironment()
        if Py_IsInitialized() == 0 {
            Py_Initialize()
        }
        #endif

        state = .ready
    }

    public func stop() async {
        // Embedded Python often should not be finalized/restarted repeatedly inside an app.
        // Leave the interpreter alive once initialized.
        state = .stopped
    }

    public func run(code: String, filename: String? = nil) async throws -> RunResult {
        if state == .stopped { try await start() }
        state = .running
        let startTime = Date()

        #if canImport(Python)
        let rc: Int32 = code.withCString { ptr in
            PyRun_SimpleStringFlags(ptr, nil)
        }
        state = .ready
        return RunResult(
            exitCode: rc,
            stdout: rc == 0 ? "Executed \(filename ?? "<string>") with embedded Python.\nNote: stdout capture bridge is TODO; check device console for print output." : "",
            stderr: rc == 0 ? "" : "Python returned non-zero status \(rc). Full exception capture bridge is TODO.",
            duration: Date().timeIntervalSince(startTime)
        )
        #else
        let output = "[mock runtime: Python.xcframework not linked] Would run \(filename ?? "<string>")\n\n\(code)"
        state = .ready
        return RunResult(exitCode: 0, stdout: output, stderr: "", duration: Date().timeIntervalSince(startTime))
        #endif
    }

    public func installPackage(_ specifier: String) async throws -> String {
        try await packageManager.install(specifier: specifier)
    }

    public func listPackages() async throws -> [PackageInfo] {
        try await packageManager.listInstalled()
    }

    private func configurePythonEnvironment() {
        guard let resourcePath = Bundle.main.resourcePath else { return }
        let pythonHome = URL(fileURLWithPath: resourcePath).appendingPathComponent("python").path
        let runtimePath = URL(fileURLWithPath: resourcePath).appendingPathComponent("PythonRuntime").path
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let sitePackages = docs?.appendingPathComponent("site-packages", isDirectory: true).path ?? ""

        setenv("PYTHONHOME", pythonHome, 1)
        setenv("IPYRUNNER_SITE_PACKAGES", sitePackages, 1)
        setenv("PYTHONPATH", [runtimePath, sitePackages].filter { !$0.isEmpty }.joined(separator: ":"), 1)
    }
}
