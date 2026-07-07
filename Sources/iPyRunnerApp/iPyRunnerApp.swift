import SwiftUI
import iPyRunnerCore

@main
struct iPyRunnerApp: App {
    @StateObject private var runtime = EmbeddedPythonRuntime()

    var body: some Scene {
        WindowGroup {
            ContentView(runtime: runtime)
        }
    }
}
