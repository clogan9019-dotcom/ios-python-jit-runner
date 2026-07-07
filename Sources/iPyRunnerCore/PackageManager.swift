import Foundation

public final class PackageManager {
    private let packagesDirectory: URL

    public init(packagesDirectory: URL? = nil) {
        if let packagesDirectory {
            self.packagesDirectory = packagesDirectory
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.packagesDirectory = docs.appendingPathComponent("site-packages", isDirectory: true)
        }
    }

    public func install(specifier: String) async throws -> String {
        try FileManager.default.createDirectory(at: packagesDirectory, withIntermediateDirectories: true)

        // TODO: Implement iOS package installer.
        // Recommended strategy:
        // - Resolve/download packages server-side or with a bundled pure-Python installer.
        // - Accept pure-Python wheels and sdists only.
        // - Reject unsupported native extension wheels unless prebuilt for iOS.
        // - Extract into packagesDirectory.
        return "Package install requested: \(specifier). Target: \(packagesDirectory.path)"
    }

    public func listInstalled() async throws -> [PackageInfo] {
        guard FileManager.default.fileExists(atPath: packagesDirectory.path) else { return [] }
        let items = try FileManager.default.contentsOfDirectory(at: packagesDirectory, includingPropertiesForKeys: nil)
        return items
            .filter { $0.lastPathComponent.hasSuffix(".dist-info") }
            .map { url in
                let raw = url.lastPathComponent.replacingOccurrences(of: ".dist-info", with: "")
                let parts = raw.split(separator: "-", maxSplits: 1).map(String.init)
                return PackageInfo(name: parts.first ?? raw, version: parts.count > 1 ? parts[1] : "unknown", location: url.path)
            }
    }
}
