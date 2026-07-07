import Foundation

private struct PyPIMetadata: Decodable {
    struct Info: Decodable { let name: String; let version: String }
    struct ReleaseFile: Decodable {
        let filename: String
        let url: URL
        let packagetype: String?
        let python_version: String?
    }
    let info: Info
    let releases: [String: [ReleaseFile]]
}

public final class PackageManager {
    private let packagesDirectory: URL
    private var wheelsDirectory: URL { packagesDirectory.appendingPathComponent("_wheels", isDirectory: true) }

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
        try FileManager.default.createDirectory(at: packagesDirectory, withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: wheelsDirectory, withIntermediateDirectories: true, attributes: nil)

        let normalized = specifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "Package name is empty." }
        guard !normalized.contains("/") && !normalized.contains(" ") else {
            return "Only simple package names are supported in the on-device installer for now."
        }

        let metadataURL = URL(string: "https://pypi.org/pypi/\(normalized)/json")!
        let (data, _) = try await URLSession.shared.data(from: metadataURL)
        let metadata = try JSONDecoder().decode(PyPIMetadata.self, from: data)
        let files = metadata.releases[metadata.info.version] ?? []

        guard let wheel = files.first(where: { file in
            file.packagetype == "bdist_wheel"
            && file.filename.hasSuffix(".whl")
            && (file.filename.contains("py3-none-any") || file.filename.contains("py2.py3-none-any"))
        }) else {
            return "No pure-Python wheel found for \(metadata.info.name) \(metadata.info.version). Native wheels need prebuilt iOS support."
        }

        let destination = wheelsDirectory.appendingPathComponent(wheel.filename)
        if !FileManager.default.fileExists(atPath: destination.path) {
            let (wheelData, _) = try await URLSession.shared.data(from: wheel.url)
            try wheelData.write(to: destination, options: .atomic)
        }

        // TODO: Extract wheel into packagesDirectory. iOS doesn't provide a convenient public unzip API
        // in Foundation on every target; add a tiny ZIP extractor or a package dependency next.
        return "Downloaded pure-Python wheel: \(wheel.filename). Extraction into site-packages is the next step."
    }

    public func listInstalled() async throws -> [PackageInfo] {
        guard FileManager.default.fileExists(atPath: packagesDirectory.path) else { return [] }
        let items = try FileManager.default.contentsOfDirectory(at: packagesDirectory, includingPropertiesForKeys: nil)
        let distInfos = items
            .filter { $0.lastPathComponent.hasSuffix(".dist-info") }
            .map { url in
                let raw = url.lastPathComponent.replacingOccurrences(of: ".dist-info", with: "")
                let parts = raw.split(separator: "-", maxSplits: 1).map(String.init)
                return PackageInfo(name: parts.first ?? raw, version: parts.count > 1 ? parts[1] : "unknown", location: url.path)
            }
        let downloadedWheels: [PackageInfo]
        if FileManager.default.fileExists(atPath: wheelsDirectory.path) {
            downloadedWheels = try FileManager.default.contentsOfDirectory(at: wheelsDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "whl" }
                .map { PackageInfo(name: $0.deletingPathExtension().lastPathComponent, version: "downloaded wheel", location: $0.path) }
        } else {
            downloadedWheels = []
        }
        return distInfos + downloadedWheels
    }
}
