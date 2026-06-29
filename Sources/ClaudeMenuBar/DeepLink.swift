import Foundation
import AppKit

/// Opens a chat in Claude Code.
///
/// Primary path is the dedicated Claude Code URL handler registered on the
/// `claude-cli://` scheme (bundle `com.anthropic.claude-code-url-handler`).
/// The GUI app's own `claude://` scheme does NOT handle session resume.
enum DeepLink {
    static func open(_ session: Session) {
        log("CLICK open sid=\(session.id)")
        let urlString = "claude://resume?session=\(session.id)"
        // Try the most reliable launcher first; fall back to NSWorkspace.
        if !runOpen([urlString]) {
            if let u = URL(string: urlString) {
                let ok = NSWorkspace.shared.open(u)
                log("NSWorkspace.open=\(ok) \(urlString)")
            }
        } else {
            log("ran /usr/bin/open \(urlString)")
        }
    }

    /// Fallback: `claude --resume <id>` in a new Terminal window at the chat's cwd.
    static func openInTerminal(_ session: Session) {
        log("CLICK terminal sid=\(session.id) cwd=\(session.cwd)")
        let dir = session.cwd.isEmpty ? "$HOME" : session.cwd
        let cmd = "cd \(shellQuote(dir)) && claude --resume \(session.id)"
        let script = "tell application \"Terminal\" to do script \(appleScriptQuote(cmd))\n"
            + "tell application \"Terminal\" to activate"
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        if let error { log("terminal AppleScript error: \(error)") }
    }

    // MARK: - Helpers

    @discardableResult
    private static func runOpen(_ args: [String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = args
        do { try p.run(); return true }
        catch { log("runOpen error: \(error)"); return false }
    }

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptQuote(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\")
                 .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    /// Append a line to ~/.claude/menubar/click.log (diagnostic).
    static func log(_ msg: String) {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/menubar")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("click.log")
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(msg)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(data); try? h.close()
        } else {
            try? data.write(to: url)
        }
    }
}
