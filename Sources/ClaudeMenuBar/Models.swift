import Foundation

/// Lifecycle state of a Claude Code chat, as shown in the menu bar.
enum SessionState: String, Codable {
    case running   // 🟠 Claude is actively working
    case waiting   // 🟡 idle, waiting for the user's next step
    case error     // 🔴 last turn ended in an API error
    case finished  // 🟢 process gone / session ended

    var dotColorName: String {
        switch self {
        case .running:  return "orange"
        case .waiting:  return "yellow"
        case .error:    return "red"
        case .finished: return "green"
        }
    }

    /// Sort priority: running first, then waiting, then error, then finished.
    var order: Int {
        switch self {
        case .running:  return 0
        case .waiting:  return 1
        case .error:    return 2
        case .finished: return 3
        }
    }
}

/// A single Claude Code chat surfaced in the menu bar.
struct Session: Identifiable, Hashable {
    let id: String            // sessionId (UUID)
    var pid: Int32?           // owning process, when live
    var cwd: String           // working directory of the chat
    var state: SessionState
    var title: String         // first user prompt, truncated
    var lastActivity: Date    // transcript mtime (or start time)
    var entrypoint: String?   // e.g. "claude-desktop"

    /// Short, human label = last path component of the cwd.
    var projectName: String {
        let name = (cwd as NSString).lastPathComponent
        return name.isEmpty ? "~" : name
    }
}
