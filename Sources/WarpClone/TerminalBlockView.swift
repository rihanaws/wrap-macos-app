import SwiftUI

struct TerminalBlockView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    var block: TerminalBlock
    @State private var hovering = false
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            header
            TerminalTextView(text: "$ \(block.command)\n\(block.rawOutput)", fontName: preferences.fontName, fontSize: preferences.fontSize)
                .frame(minHeight: 120)
                .padding(.horizontal, 2)
            footer
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: theme.blockBackground))
                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(statusColor)
                .frame(width: 3)
                .padding(.vertical, 0)
        }
        .overlay(alignment: .topTrailing) {
            floatingToolbar
                .opacity(hovering ? 1 : 0)
                .offset(y: hovering ? 0 : -4)
                .animation(.easeOut(duration: 0.14), value: hovering)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onHover { hovering = $0 }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3).delay(0.05)) {
                appeared = true
            }
        }
        .animation(.easeOut(duration: 0.2), value: block.id)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: block.status.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(statusColor)

            Text(block.command)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .foregroundStyle(Color(hex: theme.foreground))

            Spacer()

            Text(block.startedAt, style: .time)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Text(String(format: "%.1fs", block.duration))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.secondary.opacity(0.12)))
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.06))
    }

    private var footer: some View {
        HStack(spacing: 24) {
            BlockToolbarButton(icon: "doc.on.doc", label: "Copy", action: copyBlock)
            BlockToolbarButton(icon: "square.and.arrow.up", label: "Share", action: shareBlock)
            BlockToolbarButton(icon: block.isBookmarked ? "bookmark.fill" : "bookmark", label: "Bookmark", action: {})
            BlockToolbarButton(icon: "trash", label: "Delete", action: {})
            BlockToolbarButton(icon: "sparkles", label: "Ask AI", action: {})
            Spacer()
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .padding(.vertical, 9)
        .background(Color.black.opacity(0.04))
    }

    private var floatingToolbar: some View {
        HStack(spacing: 6) {
            Button(action: copyBlock) {
                Image(systemName: "doc.on.doc")
            }
            Button(action: {}) {
                Image(systemName: "sparkles")
            }
        }
        .font(.system(size: 12, weight: .semibold))
        .buttonStyle(.borderless)
        .padding(8)
        .background(.thinMaterial)
        .clipShape(Capsule())
        .padding(8)
    }

    private var theme: TerminalTheme {
        ThemeRegistry.theme(id: preferences.theme)
    }

    private var statusColor: Color {
        switch block.status {
        case .running:
            Color(hex: theme.warning)
        case .succeeded:
            Color(hex: theme.success)
        case .failed:
            Color(hex: theme.failure)
        case .cancelled:
            .secondary
        }
    }

    private func copyBlock() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("$ \(block.command)\n\(block.rawOutput)", forType: .string)
    }

    private func shareBlock() {
        let payload = "$ \(block.command)\n\(block.rawOutput)"
        guard let view = NSApp.keyWindow?.contentView else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(payload, forType: .string)
            return
        }
        NSSharingServicePicker(items: [payload]).show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }
}

private struct BlockToolbarButton: View {
    var icon: String
    var label: String
    var action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(hovered ? Color.primary : Color.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.1), value: hovered)
    }
}
