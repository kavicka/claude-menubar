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
        // --open <sessionId>: exercise the exact click code path headlessly.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--open"), i + 1 < args.count {
            let sid = args[i + 1]
            DeepLink.open(Session(id: sid, pid: nil, cwd: "", state: .running,
                                  title: "", lastActivity: Date(), entrypoint: nil))
            print("fired deep link for \(sid)")
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
