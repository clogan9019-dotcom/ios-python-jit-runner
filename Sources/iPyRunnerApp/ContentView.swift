import SwiftUI
import UIKit

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
        GeometryReader { geo in
            let isSmallHeight = geo.size.height < 720
            let horizontalPadding: CGFloat = geo.size.width < 390 ? 10 : 14
            let cardRadius: CGFloat = geo.size.width < 390 ? 14 : 18
            let verticalSpacing: CGFloat = isSmallHeight ? 8 : 12

            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.045, green: 0.052, blue: 0.075), Color(red: 0.09, green: 0.11, blue: 0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: verticalSpacing) {
                    topBar(isSmallHeight: isSmallHeight)

                    if !editorFocused {
                        statusStrip(isSmallHeight: isSmallHeight, radius: cardRadius)
                    }

                    Picker("Pane", selection: $runPane) {
                        ForEach(RunPane.allCases) { pane in
                            Text(pane.rawValue).tag(pane)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, horizontalPadding)

                    Group {
                        if runPane == .editor {
                            editorCard(radius: cardRadius, compact: isSmallHeight || editorFocused)
                        } else {
                            consoleCard(radius: cardRadius, compact: isSmallHeight)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, horizontalPadding)

                    if !editorFocused {
                        bottomActions
                            .padding(.horizontal, horizontalPadding)
                            .padding(.bottom, 6)
                    }
                }
                .padding(.top, 6)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Console") {
                        editorFocused = false
                        runPane = .console
                    }
                    Spacer()
                    Button("Run") {
                        editorFocused = false
                        runCode()
                    }
                    Spacer()
                    Button("Done") { editorFocused = false }
                }
            }
        }
    }

    private func topBar(isSmallHeight: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("iPyRunner")
                    .font(.system(size: isSmallHeight ? 22 : 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("iOS Python runner")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            Button {
                runCode()
            } label: {
                HStack(spacing: 6) {
                    if isRunning {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text(isRunning ? "Running" : "Run")
                }
                .font(.system(size: isSmallHeight ? 15 : 17, weight: .semibold))
                .padding(.horizontal, isSmallHeight ? 12 : 16)
                .padding(.vertical, isSmallHeight ? 9 : 11)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunning)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, isSmallHeight ? 6 : 8)
        .background(.black.opacity(0.18))
    }

    private func statusStrip(isSmallHeight: Bool, radius: CGFloat) -> some View {
        HStack(spacing: 10) {
            Image(systemName: runtime.state == .running ? "bolt.fill" : "terminal.fill")
                .foregroundStyle(runtime.state == .running ? .yellow : .green)

            Text("State: \(runtime.state.rawValue)")
                .foregroundStyle(.white.opacity(0.82))

            Spacer(minLength: 4)

            Text("JIT: \(runtime.jitStatus.enabled ? "on" : "off")")
                .foregroundStyle(.white.opacity(0.58))
        }
        .font(.system(size: isSmallHeight ? 12 : 13, weight: .semibold, design: .rounded))
        .padding(.horizontal, 12)
        .padding(.vertical, isSmallHeight ? 8 : 10)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 14)
    }

    private func editorCard(radius: CGFloat, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label("main.py", systemImage: "doc.text.fill")
                    .foregroundStyle(.white.opacity(0.82))
                    .font(.system(size: compact ? 12 : 13, weight: .semibold))

                Spacer()

                Button("Example") {
                    setExample()
                }
                .font(.caption)

                Button("Clear") { code = "" }
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.top, compact ? 8 : 12)

            TextEditor(text: $code)
                .font(.system(size: compact ? 14 : 15, weight: .regular, design: .monospaced))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .focused($editorFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
        .background(Color.black.opacity(0.44), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func consoleCard(radius: CGFloat, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label("Console", systemImage: "chevron.left.forwardslash.chevron.right")
                    .foregroundStyle(.white.opacity(0.82))
                    .font(.system(size: compact ? 12 : 13, weight: .semibold))

                Spacer()

                Button("Copy") { UIPasteboard.general.string = console }
                    .font(.caption)
                Button("Clear") { console = "" }
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.top, compact ? 8 : 12)

            ScrollViewReader { proxy in
                ScrollView {
                    Text(console.isEmpty ? "Console is empty." : console)
                        .id("console-bottom")
                        .font(.system(size: compact ? 12 : 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.95))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(12)
                }
                .onChange(of: console) { _ in
                    withAnimation { proxy.scrollTo("console-bottom", anchor: .bottom) }
                }
            }
        }
        .background(Color.black.opacity(0.64), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(.green.opacity(0.18), lineWidth: 1)
        )
    }

    private var bottomActions: some View {
        HStack(spacing: 10) {
            Button {
                setExample()
                runPane = .editor
            } label: {
                Label("Example", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                runPane = .console
            } label: {
                Label("Console", systemImage: "terminal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                runCode()
            } label: {
                Label("Run", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunning)
        }
        .font(.system(size: 13, weight: .semibold))
    }

    private func setExample() {
        code = """
        import sys
        print('Hello from iPyRunner')
        print('Python version:', sys.version)
        """
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
