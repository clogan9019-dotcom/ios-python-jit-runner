import SwiftUI

struct PackagesView: View {
    let runtime: EmbeddedPythonRuntime
    @State private var packageName = "requests"
    @State private var log = ""
    @State private var packages: [PackageInfo] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Install package") {
                    TextField("Package specifier", text: $packageName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Install") { install() }
                }

                Section("Installed") {
                    Button("Refresh") { refresh() }
                    ForEach(packages) { pkg in
                        VStack(alignment: .leading) {
                            Text(pkg.name).font(.headline)
                            Text(pkg.version).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Log") {
                    Text(log.isEmpty ? "No package actions yet." : log)
                        .font(.system(.footnote, design: .monospaced))
                }
            }
            .navigationTitle("Packages")
        }
    }

    private func install() {
        Task {
            do { log = try await runtime.installPackage(packageName) }
            catch { log = "Install failed: \(error)" }
            refresh()
        }
    }

    private func refresh() {
        Task {
            do { packages = try await runtime.listPackages() }
            catch { log = "List failed: \(error)" }
        }
    }
}
