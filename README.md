# ClaudeMenuBar

A native macOS menu bar app that shows your running Claude Code chats at a glance.

**🟠 running · 🟡 waiting for you · 🟢 finished**

Click the bar icon to open the panel. Click any chat to jump into it in Claude Desktop. Right-click for more options.

![menu bar preview](https://raw.githubusercontent.com/kavicka/claude-menubar/main/docs/preview.png)

---

## Install

### Option A — Homebrew (recommended)

```bash
# 1. Install (builds from source — no Gatekeeper prompts)
brew install kavicka/claude-menubar/claude-menubar

# 2. Wire up Claude Code hooks + start the app
claude-menubar setup
```

The 🟠🟡🟢 counts appear in your menu bar immediately. The app also starts automatically at login.

**Requirements:**
- macOS 13 Ventura or later
- Xcode Command Line Tools: `xcode-select --install`
- Claude Desktop app installed

### Option B — Build from source

```bash
git clone https://github.com/kavicka/claude-menubar
cd claude-menubar
./install.sh     # builds, copies to /Applications, runs setup
```

---

## Usage

### Menu bar counts

| Icon | Meaning |
|------|---------|
| 🟠 | Claude is actively working in this chat |
| 🟡 | Claude finished its turn — waiting for your input |
| 🟢 | Chat process has ended |

Example: `🟠2 🟡1 🟢3` → 2 busy, 1 waiting, 3 finished.

### Panel

Click the bar icon to open the chat list. Each row shows:
- Colored status dot
- Project name (last folder of the working directory)
- Last message preview
- Relative timestamp

**Left-click a row** → opens that chat in Claude Desktop.

**Right-click a row** to get:
- **Open in Desktop App** — jump to the chat window
- **Open in Terminal** — resume the session in a new Terminal window via `claude --resume`
- **Hide from menu** — removes the row from the list (reversible)

**Footer buttons:**
- **Show hidden (N)** — brings back hidden chats
- **Quit** — exits ClaudeMenuBar

### Hiding vs closing

"Hide from menu" only hides the row — it never kills a process or deletes a transcript. The chat keeps running. Use **Show hidden** to restore it.

---

## CLI control

```
claude-menubar setup      wire status hooks, register autostart, start app
claude-menubar remove     undo hooks and autostart (keeps the .app)
claude-menubar start      start the app
claude-menubar stop       stop the app
claude-menubar restart    restart the app
claude-menubar status     show whether the app is running
claude-menubar doctor     show installation details and paths
```

---

## Permissions

**Automation (Terminal)** — needed for "Open in Terminal". Grant it when macOS asks, or go to:

> System Settings → Privacy & Security → Automation → ClaudeMenuBar → enable Terminal

---

## Update

```bash
brew upgrade claude-menubar
claude-menubar restart
```

---

## Uninstall

```bash
claude-menubar remove        # remove hooks + autostart
brew uninstall claude-menubar
```

---

## How it works

Everything runs locally — no network calls, no account needed.

| Signal | Source |
|--------|--------|
| Which chats are live | `~/.claude/sessions/<pid>.json` + PID liveness check |
| Running vs waiting | Claude Code hooks write `~/.claude/menubar/status/<sid>.json` |
| Title + last activity | transcript at `~/.claude/projects/*/<sid>.jsonl` |
| Jump into a chat | `claude://resume?session=<id>` deep link to Claude Desktop |
| Hide a chat | session ID appended to `~/.claude/menubar/hidden.json` |

`claude-menubar setup` appends hook entries to `~/.claude/settings.json` without touching your existing hooks (a timestamped backup is saved next to the file).

---

## Release a new version (maintainer)

1. Bump version in `scripts/bundle-app.sh`, commit.
2. `git tag v1.x.0 && git push origin v1.x.0`
3. `gh release create v1.x.0 --generate-notes`
4. In `kavicka/homebrew-claude-menubar`, update `url` + `sha256`:
   ```bash
   curl -sL <tarball-url> | shasum -a 256
   ```
5. `brew update && brew upgrade claude-menubar` to verify.

---

## License

MIT — see [LICENSE](LICENSE).
