import SwiftUI

/// Entry point. `--dump` runs a single headless scan and prints it (for testing);
/// otherwise the SwiftUI menu bar app launches normally.
@main
enum EntryPoint {
    static func main() {
        if CommandLine.arguments.contains("--dump") {
            MainActor.assumeIsolated {
                let store = SessionStore()
                store.refresh()
                print("barText: \(store.barText)")
                print("sessions: \(store.sessions.count)")
                for s in store.sessions {
                    print("  [\(s.state.rawValue)] \(s.projectName)  \(s.id.prefix(8))  \"\(s.title)\"")
                }
            }
            return
        }
        ClaudeMenuBarApp.main()
    }
}

struct ClaudeMenuBarApp: App {
    @StateObject private var store = SessionStore()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(store: store)
        } label: {
            Text(store.barText)
        }
        .menuBarExtraStyle(.window)
    }
}
