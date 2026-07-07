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

private struct PythonBridgePayload: Decodable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
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
        configurePythonEnvironment()

        #if canImport(Python)
        if Py_IsInitialized() == 0 {
            Py_Initialize()
        }
        #endif

        state = .ready
    }

    public func stop() async {
        // Embedded Python should generally stay initialized for the app lifetime.
        state = .stopped
    }

    public func run(code: String, filename: String? = nil) async throws -> RunResult {
        if state == .stopped { try await start() }
        state = .running
        let startTime = Date()

        #if canImport(Python)
        let result = runEmbeddedPython(code: code, filename: filename ?? "main.py", startedAt: startTime)
        state = .ready
        return result
        #else
        let output = """
        Python.xcframework is not linked in this build.

        File: \(filename ?? "<string>")

        Code that would run:
        \(code)
        """
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

    #if canImport(Python)
    private func runEmbeddedPython(code: String, filename: String, startedAt: Date) -> RunResult {
        let encodedCode = Data(code.utf8).base64EncodedString()
        let encodedFilename = Data(filename.utf8).base64EncodedString()

        let wrapper = """
import base64, io, json, sys, traceback
__ipyrunner_stdout = io.StringIO()
__ipyrunner_stderr = io.StringIO()
__ipyrunner_exit = 0
__ipyrunner_code = base64.b64decode('\(encodedCode)').decode('utf-8')
__ipyrunner_filename = base64.b64decode('\(encodedFilename)').decode('utf-8')
__ipyrunner_globals = {'__name__': '__main__', '__file__': __ipyrunner_filename}
__ipyrunner_old_stdout, __ipyrunner_old_stderr = sys.stdout, sys.stderr
try:
    sys.stdout, sys.stderr = __ipyrunner_stdout, __ipyrunner_stderr
    exec(compile(__ipyrunner_code, __ipyrunner_filename, 'exec'), __ipyrunner_globals, __ipyrunner_globals)
except BaseException:
    __ipyrunner_exit = 1
    traceback.print_exc(file=__ipyrunner_stderr)
finally:
    sys.stdout, sys.stderr = __ipyrunner_old_stdout, __ipyrunner_old_stderr
__ipyrunner_result__ = json.dumps({
    'exitCode': __ipyrunner_exit,
    'stdout': __ipyrunner_stdout.getvalue(),
    'stderr': __ipyrunner_stderr.getvalue(),
})
"""

        let rc: Int32 = wrapper.withCString { ptr in
            PyRun_SimpleStringFlags(ptr, nil)
        }
        if rc != 0 {
            return RunResult(
                exitCode: rc,
                stdout: "",
                stderr: "Python bridge wrapper failed before user code completed.",
                duration: Date().timeIntervalSince(startedAt)
            )
        }

        guard let mainModule = PyImport_AddModule("__main__"),
              let resultObject = PyObject_GetAttrString(mainModule, "__ipyrunner_result__"),
              let resultCString = PyUnicode_AsUTF8(resultObject) else {
            return RunResult(
                exitCode: 1,
                stdout: "",
                stderr: "Python executed, but Swift could not read __ipyrunner_result__.",
                duration: Date().timeIntervalSince(startedAt)
            )
        }

        let resultJSON = String(cString: resultCString)
        Py_DecRef(resultObject)

        do {
            let payload = try JSONDecoder().decode(PythonBridgePayload.self, from: Data(resultJSON.utf8))
            return RunResult(
                exitCode: payload.exitCode,
                stdout: payload.stdout,
                stderr: payload.stderr,
                duration: Date().timeIntervalSince(startedAt)
            )
        } catch {
            return RunResult(
                exitCode: 1,
                stdout: resultJSON,
                stderr: "Failed to decode Python bridge JSON: \(error)",
                duration: Date().timeIntervalSince(startedAt)
            )
        }
    }
    #endif
}
