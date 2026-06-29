import SwiftUI
import AppKit

/// The dropdown shown when the menu bar item is clicked.
struct MenuContentView: View {
    @ObservedObject var store: SessionStore
    @State private var hoveredID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            if store.sessions.isEmpty {
                Text("No active chats")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(store.sessions) { session in
                            row(session)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 360)
            }

            Divider()
            footer
        }
        .frame(width: 340)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("Claude Chats")
                .font(.headline)
            Spacer()
            Text(store.barText)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: Row

    private func row(_ session: Session) -> some View {
        Button {
            DeepLink.open(session)
        } label: {
            HStack(spacing: 9) {
                Circle()
                    .fill(color(for: session.state))
                    .frame(width: 9, height: 9)
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.projectName)
                        .font(.system(.body, weight: .medium))
                        .lineLimit(1)
                    Text(session.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Text(relative(session.lastActivity))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(hoveredID == session.id ? Color.primary.opacity(0.08) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hoveredID = $0 ? session.id : (hoveredID == session.id ? nil : hoveredID) }
        .contextMenu {
            Button("Open in Desktop App") { DeepLink.open(session) }
            Button("Open in Terminal") { DeepLink.openInTerminal(session) }
            Divider()
            Button("Hide from menu") { store.hide(session.id) }
        }
        .padding(.horizontal, 6)
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            if store.hiddenCount > 0 {
                Button("Show hidden (\(store.hiddenCount))") { store.resetHidden() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    // MARK: Helpers

    private func color(for state: SessionState) -> Color {
        switch state {
        case .running:  return .orange
        case .waiting:  return .yellow
        case .finished: return .green
        }
    }

    private func relative(_ date: Date) -> String {
        guard date.timeIntervalSince1970 > 0 else { return "" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}
