# ClaudeMenuBar

A native macOS menu bar app that shows your running Claude Code chats at a glance.

The menu bar shows live counts — **🟠 running · 🟡 waiting for you · 🟢 finished**.
Click the icon to see every chat; click a chat to jump straight into it in the
Claude desktop app. Right-click a chat to hide it from the list.

## Install (Homebrew)

```bash
brew install kavicka/claude-menubar/claude-menubar
claude-menubar setup
```

That's it — the 🟠🟡🟢 counts appear in your menu bar and the app starts at login.

**Requirements** (the formula builds from source, so no Gatekeeper warnings):
- Xcode Command Line Tools — `xcode-select --install`
- `jq` — `brew install jq`
- macOS 13+

### What `claude-menubar setup` does

- writes a status hook to `~/.claude/menubar/`
- **appends** that hook to `~/.claude/settings.json` (your existing hooks are kept;
  a timestamped backup is saved next to the file)
- registers a Login Item (LaunchAgent) and starts the app

Undo any time with `claude-menubar remove` (the app stays; `brew uninstall` removes it).

## CLI

```
claude-menubar setup      wire status hooks + autostart, then start
claude-menubar remove     undo hooks + autostart (keeps the app)
claude-menubar start|stop|restart|status
claude-menubar doctor     show what's installed and where
```

## How it works (all local, no network)

| Signal | Source |
|--------|--------|
| Which chats are live | `~/.claude/sessions/<pid>.json` (process registry) |
| Running vs waiting | Claude Code **hooks** write `~/.claude/menubar/status/<sid>.json` |
| Title + last activity | the transcript `~/.claude/projects/*/<sid>.jsonl` |
| Jump into a chat | `claude://resume?sessionId=…` desktop deep link |
| Hide a chat | id added to `~/.claude/menubar/hidden.json` (reversible) |

A chat is **🟠 running** while Claude is working (`UserPromptSubmit` fired, no `Stop`
yet), **🟡 waiting** the moment a turn ends (`Stop`/`Notification`) or a chat is
freshly opened (`SessionStart`), and **🟢 finished** once its process is gone.

"Hide from menu" only hides — it never stops a process or deletes a transcript.
Use **Show hidden** in the footer to bring chats back.

> Clicking a chat opens it via the `claude://resume` deep link. If that does nothing
> on your setup, use the row's right-click → **Open in Terminal** (`claude --resume`).

## Update

```bash
brew upgrade claude-menubar
claude-menubar restart
```

## Uninstall

```bash
claude-menubar remove
brew uninstall claude-menubar
```

## Build from source (without Homebrew)

```bash
git clone https://github.com/kavicka/claude-menubar
cd claude-menubar
./install.sh          # builds, installs to /Applications, runs setup
```

`./scripts/bundle-app.sh` builds just the `.app`. The binary supports
`ClaudeMenuBar --dump` to print the current scan (handy for debugging).

## Releasing a new version (maintainer)

1. Bump `CFBundleShortVersionString` in `scripts/bundle-app.sh`, commit.
2. Tag and push: `git tag v1.x.0 && git push origin v1.x.0`.
3. `gh release create v1.x.0 --generate-notes`.
4. Update the tap formula in `kavicka/homebrew-claude-menubar`:
   - point `url` at the new tag tarball
   - `sha256` = `curl -sL <tarball-url> | shasum -a 256`
   - commit + push the tap.
5. Verify: `brew update && brew upgrade claude-menubar`.

## License

MIT — see [LICENSE](LICENSE).
