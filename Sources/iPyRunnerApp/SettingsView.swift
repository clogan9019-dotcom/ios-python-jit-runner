import SwiftUI

struct SettingsView: View {
    @ObservedObject var runtime: EmbeddedPythonRuntime

    var body: some View {
        NavigationStack {
            Form {
                Section("Runtime") {
                    LabeledContent("State", value: runtime.state.rawValue)
                }
                Section("JIT") {
                    LabeledContent("Available", value: runtime.jitStatus.available ? "Yes" : "No")
                    LabeledContent("Enabled", value: runtime.jitStatus.enabled ? "Yes" : "No")
                    Text(runtime.jitStatus.message)
                        .foregroundStyle(.secondary)
                }
                Section("Safety") {
                    Text("JIT acceleration falls back safely when unavailable. Package installs should remain sandboxed and pure-Python unless you bundle native iOS wheels yourself.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
