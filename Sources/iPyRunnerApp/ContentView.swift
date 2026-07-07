import SwiftUI

struct ContentView: View {
    @ObservedObject var runtime: EmbeddedPythonRuntime

    @State private var code = "print('Hello from iOS Python Runner')"
    @State private var console = "Tap Run to execute your script."
    @State private var selectedTab = 0
    @State private var runPane: RunPane = .editor
    @State private var isRunning = false
    @FocusState private var editorFocused: Bool

    enum RunPane: String, CaseIterable, Identifiable {
        case editor = "Editor"
        case console = "Console"
        var id: String { rawValue }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            runView
                .tabItem { Label("Run", systemImage: "play.circle.fill") }
                .tag(0)

            PackagesView(runtime: runtime)
                .tabItem { Label("Packages", systemImage: "shippingbox.fill") }
                .tag(1)

            SettingsView(runtime: runtime)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(2)
        }
        .tint(.blue)
    }

    private var runView: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.06, blue: 0.09), Color(red: 0.10, green: 0.12, blue: 0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 12) {
                    statusCard

                    Picker("Pane", selection: $runPane) {
                        ForEach(RunPane.allCases) { pane in
                            Text(pane.rawValue).tag(pane)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if runPane == .editor {
                        editorCard
                    } else {
                        consoleCard
                    }

                    bottomActions
                }
                .padding(.top, 8)
            }
            .navigationTitle("iPyRunner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        runCode()
                    } label: {
                        Label(isRunning ? "Running" : "Run", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Button("Console") {
                        editorFocused = false
                        runPane = .console
                    }
                    Spacer()
                    Button("Done") { editorFocused = false }
                }
            }
        }
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: runtime.state == .running ? "bolt.fill" : "terminal.fill")
                .foregroundStyle(runtime.state == .running ? .yellow : .green)
                .font(.title2)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("Python Runner")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("State: \(runtime.state.rawValue) • JIT: \(runtime.jitStatus.enabled ? "on" : "off")")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer()
        }
        .padding(14)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("main.py", systemImage: "doc.text.fill")
                    .foregroundStyle(.white.opacity(0.8))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Clear") { code = "" }
                    .font(.caption)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            TextEditor(text: $code)
                .font(.system(size: 15, weight: .regular, design: .monospaced))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .focused($editorFocused)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private var consoleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Console", systemImage: "chevron.left.forwardslash.chevron.right")
                    .foregroundStyle(.white.opacity(0.8))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Copy") { UIPasteboard.general.string = console }
                    .font(.caption)
                Button("Clear") { console = "" }
                    .font(.caption)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            ScrollViewReader { proxy in
                ScrollView {
                    Text(console.isEmpty ? "Console is empty." : console)
                        .id("console-bottom")
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.95))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(14)
                }
                .onChange(of: console) { _ in
                    withAnimation { proxy.scrollTo("console-bottom", anchor: .bottom) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.green.opacity(0.18), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private var bottomActions: some View {
        HStack(spacing: 10) {
            Button {
                code = """
                import sys
                print('Hello from iPyRunner')
                print('Python version:', sys.version)
                """
                runPane = .editor
            } label: {
                Label("Example", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                editorFocused = false
                runCode()
            } label: {
                Label("Run", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunning)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func runCode() {
        editorFocused = false
        isRunning = true
        console = "Running main.py..."
        runPane = .console

        Task {
            do {
                let result = try await runtime.run(code: code, filename: "main.py")
                let output = """
                exit=\(result.exitCode) time=\(String(format: "%.3f", result.duration))s

                STDOUT:
                \(result.stdout.isEmpty ? "<empty>" : result.stdout)

                STDERR:
                \(result.stderr.isEmpty ? "<empty>" : result.stderr)
                """
                await MainActor.run {
                    console = output
                    isRunning = false
                }
            } catch {
                await MainActor.run {
                    console = "Error: \(error)"
                    isRunning = false
                }
            }
        }
    }
}
