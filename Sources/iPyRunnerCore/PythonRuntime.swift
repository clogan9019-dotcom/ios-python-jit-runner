import Foundation
import Combine

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
        let env = pythonEnvironment()

        if PythonBridge.isAvailable() {
            PythonBridge.start(pythonHome: env.pythonHome, pythonPath: env.pythonPath)
            state = .ready
        } else {
            state = .failed
            throw RuntimeError("PythonBridge is not available in this build.")
        }
    }

    public func stop() async {
        // Embedded Python should generally stay initialized for the app lifetime.
        state = .stopped
    }

    public func run(code: String, filename: String? = nil) async throws -> RunResult {
        if state == .stopped { try await start() }
        state = .running
        let startTime = Date()

        let result = PythonBridge.runCode(code, filename: filename ?? "main.py")
        let exitCode = (result["exitCode"] as? NSNumber)?.int32Value ?? 1
        let stdout = result["stdout"] as? String ?? ""
        let stderr = result["stderr"] as? String ?? "Python bridge returned an invalid response."

        state = .ready
        return RunResult(
            exitCode: exitCode,
            stdout: stdout,
            stderr: stderr,
            duration: Date().timeIntervalSince(startTime)
        )
    }

    public func installPackage(_ specifier: String) async throws -> String {
        try await packageManager.install(specifier: specifier)
    }

    public func listPackages() async throws -> [PackageInfo] {
        try await packageManager.listInstalled()
    }

    private func pythonEnvironment() -> (pythonHome: String, pythonPath: String) {
        guard let resourcePath = Bundle.main.resourcePath else { return ("", "") }
        let pythonHome = URL(fileURLWithPath: resourcePath).appendingPathComponent("python").path
        let runtimePath = URL(fileURLWithPath: resourcePath).appendingPathComponent("PythonRuntime").path
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let sitePackages = docs?.appendingPathComponent("site-packages", isDirectory: true).path ?? ""
        setenv("IPYRUNNER_SITE_PACKAGES", sitePackages, 1)
        return (pythonHome, [runtimePath, sitePackages].filter { !$0.isEmpty }.joined(separator: ":"))
    }
}

public struct RuntimeError: Error, LocalizedError {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}
