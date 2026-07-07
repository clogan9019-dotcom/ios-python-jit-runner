import Foundation

#if canImport(Darwin)
import Darwin
#endif

public final class JITController {
    public init() {}

    public func detect() -> JITStatus {
        #if targetEnvironment(simulator)
        return JITStatus(available: true, enabled: true, message: "Simulator allows normal host execution; JIT-style acceleration is available for development.")
        #elseif os(iOS)
        // iOS device JIT availability depends on entitlements/profile/debug conditions.
        // We deliberately do not attempt bypasses. A real runtime can try MAP_JIT or runtime checks here.
        let envEnabled = ProcessInfo.processInfo.environment["IPYRUNNER_ENABLE_JIT"] == "1"
        if envEnabled {
            return JITStatus(available: true, enabled: true, message: "JIT requested. Actual availability depends on device entitlements/profile.")
        }
        return JITStatus(available: false, enabled: false, message: "JIT is not enabled. Falling back to interpreted Python.")
        #else
        return JITStatus(available: true, enabled: true, message: "Non-iOS platform; JIT restrictions are not the same as iOS.")
        #endif
    }
}
