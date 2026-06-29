import Foundation
import AppKit

/// Opens a chat in the Claude desktop app via its registered `claude://` scheme.
enum DeepLink {
    /// Jump into a chat. Primary path is the desktop deep link; if that does
    /// nothing we fall back to launching the CLI in a Terminal window.
    static func open(_ session: Session) {
        if let url = URL(string: "claude://resume?sessionId=\(session.id)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Fallback: `claude --resume <id>` in a new Terminal window at the chat's cwd.
    static func openInTerminal(_ session: Session) {
        let dir = session.cwd.isEmpty ? "$HOME" : session.cwd
        let cmd = "cd \(shellQuote(dir)) && claude --resume \(session.id)"
        let script = "tell application \"Terminal\" to do script \(appleScriptQuote(cmd))\n"
            + "tell application \"Terminal\" to activate"
        runAppleScript(script)
    }

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptQuote(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\")
                 .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    private static func runAppleScript(_ source: String) {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
    }
}
