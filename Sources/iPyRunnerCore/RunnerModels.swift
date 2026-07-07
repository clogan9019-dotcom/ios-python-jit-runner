import Foundation

public enum RuntimeState: String, Codable, Sendable {
    case stopped
    case starting
    case ready
    case running
    case failed
}

public struct RunResult: Codable, Sendable {
    public var exitCode: Int32
    public var stdout: String
    public var stderr: String
    public var duration: TimeInterval

    public init(exitCode: Int32, stdout: String, stderr: String, duration: TimeInterval) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.duration = duration
    }
}

public struct PackageInfo: Identifiable, Codable, Sendable {
    public var id: String { name }
    public let name: String
    public let version: String
    public let location: String?

    public init(name: String, version: String, location: String? = nil) {
        self.name = name
        self.version = version
        self.location = location
    }
}

public struct JITStatus: Codable, Sendable {
    public let available: Bool
    public let enabled: Bool
    public let message: String

    public init(available: Bool, enabled: Bool, message: String) {
        self.available = available
        self.enabled = enabled
        self.message = message
    }
}
