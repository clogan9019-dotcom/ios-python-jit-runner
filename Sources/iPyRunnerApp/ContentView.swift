import SwiftUI

struct ContentView: View {
    @ObservedObject var runtime: EmbeddedPythonRuntime
    @State private var code = "print('Hello from iOS Python Runner')"
    @State private var console = ""
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            editor
                .tabItem { Label("Run", systemImage: "play.circle") }
                .tag(0)

            PackagesView(runtime: runtime)
                .tabItem { Label("Packages", systemImage: "shippingbox") }
                .tag(1)

            SettingsView(runtime: runtime)
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(2)
        }
    }

    private var editor: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $code)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)

                Divider()

                ScrollView {
                    Text(console.isEmpty ? "Console output will appear here." : console)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(minHeight: 180)
                .background(Color.black.opacity(0.05))
            }
            .navigationTitle("iPyRunner")
            .toolbar {
                Button("Run") { runCode() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func runCode() {
        Task {
            do {
                let result = try await runtime.run(code: code, filename: "main.py")
                console = "exit=\(result.exitCode) time=\(String(format: "%.3f", result.duration))s\n\nSTDOUT:\n\(result.stdout)\n\nSTDERR:\n\(result.stderr)"
            } catch {
                console = "Error: \(error)"
            }
        }
    }
}
