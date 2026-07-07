import Foundation

public final class SandboxFileSystem {
    public let root: URL

    public init(root: URL? = nil) throws {
        if let root {
            self.root = root
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.root = docs.appendingPathComponent("Projects", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
    }

    public func safeURL(for relativePath: String) throws -> URL {
        let url = root.appendingPathComponent(relativePath).standardizedFileURL
        guard url.path.hasPrefix(root.standardizedFileURL.path) else {
            throw CocoaError(.fileReadNoPermission)
        }
        return url
    }

    public func read(_ relativePath: String) throws -> String {
        try String(contentsOf: safeURL(for: relativePath), encoding: .utf8)
    }

    public func write(_ relativePath: String, content: String) throws {
        let url = try safeURL(for: relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    public func list(_ relativePath: String = "") throws -> [URL] {
        let url = try safeURL(for: relativePath)
        return try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey])
    }
}
