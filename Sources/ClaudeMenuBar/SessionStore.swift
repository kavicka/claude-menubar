import Foundation
import Darwin

/// Scans local Claude Code state and publishes the current list of chats.
///
/// Data sources (all on disk, no network):
///  - `~/.claude/sessions/<pid>.json`        live process registry
///  - `~/.claude/menubar/status/<sid>.json`  hook-written status (running/waiting)
///  - `~/.claude/projects/*/<sid>.jsonl`      transcript (title + last activity)
@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [Session] = []
    @Published private(set) var hiddenCount: Int = 0
    @Published private(set) var barText: String = "○"

    private let fm = FileManager.default
    private var hidden: Set<String> = []
    private var titleCache: [String: String] = [:]      // sid -> title (stable once found)
    private var pathCache: [String: URL] = [:]          // sid -> transcript url
    private var timer: Timer?

    // Keep finished chats around for this long before pruning their status file.
    private let finishedTTL: TimeInterval = 12 * 3600
    // Cap on how many finished chats to show.
    private let maxFinishedShown = 15

    // MARK: Paths

    private var claudeDir: URL {
        fm.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    }
    private var sessionsDir: URL { claudeDir.appendingPathComponent("sessions") }
    private var statusDir: URL   { claudeDir.appendingPathComponent("menubar/status") }
    private var projectsDir: URL { claudeDir.appendingPathComponent("projects") }
    private var hiddenFile: URL  { claudeDir.appendingPathComponent("menubar/hidden.json") }

    // MARK: Lifecycle

    init() {
        try? fm.createDirectory(at: statusDir, withIntermediateDirectories: true)
        loadHidden()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    // MARK: Hidden set

    private func loadHidden() {
        guard let data = try? Data(contentsOf: hiddenFile),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [String] else { return }
        hidden = Set(arr)
    }

    private func saveHidden() {
        let data = try? JSONSerialization.data(withJSONObject: Array(hidden), options: [.prettyPrinted])
        try? data?.write(to: hiddenFile, options: [.atomic])
    }

    func hide(_ id: String) {
        hidden.insert(id)
        saveHidden()
        refresh()
    }

    func resetHidden() {
        hidden.removeAll()
        saveHidden()
        refresh()
    }

    // MARK: Refresh

    func refresh() {
        var map: [String: Session] = [:]

        // 1) Hook-written status files give running/waiting/finished + cwd.
        for file in jsonFiles(in: statusDir) {
            guard let o = readJSON(file) else { continue }
            guard let sid = o["sessionId"] as? String else { continue }
            let stateStr = o["state"] as? String ?? "running"
            let state = SessionState(rawValue: stateStr) ?? .running
            let cwd = o["cwd"] as? String ?? ""
            let ts = (o["ts"] as? Double) ?? (o["ts"] as? Int).map(Double.init) ?? 0
            map[sid] = Session(id: sid, pid: nil, cwd: cwd, state: state,
                               title: "", lastActivity: Date(timeIntervalSince1970: ts),
                               entrypoint: nil)
        }

        // 2) Live process registry: keyed by pid, links to sessionId.
        var liveSids = Set<String>()
        for file in jsonFiles(in: sessionsDir) {
            guard let o = readJSON(file) else { continue }
            guard let sid = o["sessionId"] as? String else { continue }
            let pid = Int32((o["pid"] as? Int) ?? 0)
            let cwd = o["cwd"] as? String ?? ""
            let entry = o["entrypoint"] as? String
            let started = (o["startedAt"] as? Double).map { $0 / 1000 } ?? 0
            if pidAlive(pid) { liveSids.insert(sid) }

            var s = map[sid] ?? Session(id: sid, pid: pid, cwd: cwd, state: .running,
                                        title: "", lastActivity: Date(timeIntervalSince1970: started),
                                        entrypoint: entry)
            s.pid = pid
            if s.cwd.isEmpty { s.cwd = cwd }
            s.entrypoint = entry ?? s.entrypoint
            map[sid] = s
        }

        // 3) Resolve final state by liveness. A chat is "finished" the moment no
        //    live process owns it; while live, trust the hook (waiting vs running).
        for (id, var s) in map {
            if liveSids.contains(id) {
                s.state = (s.state == .waiting) ? .waiting : .running
            } else {
                s.state = .finished
            }
            // Enrich with transcript title + last-activity time.
            if let url = transcriptURL(for: id) {
                if let mtime = mtime(of: url) { s.lastActivity = mtime }
                s.title = title(for: id, url: url)
            } else if s.state == .finished {
                // Dead session with no transcript on disk: nothing to reopen.
                // These are internal helper sessions (hooks fire for them too);
                // drop the row and its stale status file.
                try? fm.removeItem(at: statusDir.appendingPathComponent("\(id).json"))
                map.removeValue(forKey: id)
                continue
            }
            if s.title.isEmpty { s.title = s.projectName }
            map[id] = s
        }

        // 4) Prune stale finished chats (old + dead): drop and delete status file.
        let now = Date()
        for (id, s) in map where s.state == .finished {
            if now.timeIntervalSince(s.lastActivity) > finishedTTL {
                try? fm.removeItem(at: statusDir.appendingPathComponent("\(id).json"))
                map.removeValue(forKey: id)
            }
        }

        // 5) Apply hidden filter, cap finished, sort.
        hiddenCount = map.keys.filter { hidden.contains($0) }.count
        var list = map.values.filter { !hidden.contains($0.id) }

        let finished = list.filter { $0.state == .finished }
            .sorted { $0.lastActivity > $1.lastActivity }
            .prefix(maxFinishedShown)
        let active = list.filter { $0.state != .finished }
        list = active + finished

        list.sort { a, b in
            if a.state.order != b.state.order { return a.state.order < b.state.order }
            return a.lastActivity > b.lastActivity
        }

        sessions = list
        barText = computeBarText(list)
    }

    // MARK: Helpers

    private func computeBarText(_ s: [Session]) -> String {
        let r = s.filter { $0.state == .running }.count
        let w = s.filter { $0.state == .waiting }.count
        let f = s.filter { $0.state == .finished }.count
        var parts: [String] = []
        if r > 0 { parts.append("🟠\(r)") }
        if w > 0 { parts.append("🟡\(w)") }
        if f > 0 { parts.append("🟢\(f)") }
        return parts.isEmpty ? "○" : parts.joined(separator: " ")
    }

    private func pidAlive(_ pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        if kill(pid, 0) == 0 { return true }
        return errno == EPERM
    }

    private func jsonFiles(in dir: URL) -> [URL] {
        (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "json" } ?? []
    }

    private func readJSON(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private func mtime(of url: URL) -> Date? {
        (try? fm.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    /// Find `projects/*/<sid>.jsonl` (filename is the sessionId).
    private func transcriptURL(for id: String) -> URL? {
        if let u = pathCache[id], fm.fileExists(atPath: u.path) { return u }
        guard let dirs = try? fm.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil) else { return nil }
        for d in dirs {
            let u = d.appendingPathComponent("\(id).jsonl")
            if fm.fileExists(atPath: u.path) { pathCache[id] = u; return u }
        }
        return nil
    }

    /// First user prompt of a chat (stable once found, so cached).
    private func title(for id: String, url: URL) -> String {
        if let t = titleCache[id] { return t }
        guard let text = extractFirstUserText(url) else { return "" }
        titleCache[id] = text
        return text
    }

    /// Read a bounded prefix of the transcript and pull the first user message text.
    private func extractFirstUserText(_ url: URL, maxBytes: Int = 262_144) -> String? {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? fh.close() }
        let data = (try? fh.read(upToCount: maxBytes)) ?? Data()
        guard let blob = String(data: data, encoding: .utf8) else { return nil }
        for line in blob.split(separator: "\n") {
            guard let d = line.data(using: .utf8),
                  let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
                  (o["type"] as? String) == "user",
                  let msg = o["message"] as? [String: Any] else { continue }
            if let s = msg["content"] as? String, let c = clean(s) { return c }
            if let arr = msg["content"] as? [[String: Any]] {
                for part in arr where (part["type"] as? String) == "text" {
                    if let s = part["text"] as? String, let c = clean(s) { return c }
                }
            }
        }
        return nil
    }

    /// Pick the first meaningful line of a prompt, skipping injected tags and
    /// slash-command wrappers. Returns nil when nothing readable remains (the
    /// caller then falls back to the project name).
    private func clean(_ raw: String) -> String? {
        for line in raw.split(separator: "\n", omittingEmptySubsequences: true) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.isEmpty || t.hasPrefix("<") || t.hasPrefix("#") { continue }
            let collapsed = t.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
            return String(collapsed.prefix(64))
        }
        return nil
    }
}
