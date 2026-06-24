import SwiftUI

struct CompletionDropdownView: View {
    @ObservedObject var store: CompletionStore
    let onSelect: (CompletionItem) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(store.suggestions.enumerated()), id: \.element.id) { index, item in
                CompletionRow(item: item, isSelected: index == store.selectedIndex)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        store.selectedIndex = index
                        onSelect(item)
                    }
            }
        }
        .padding(6)
        .frame(width: 360, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.separator, lineWidth: 1)
        )
        .onExitCommand(perform: onDismiss)
    }
}

private struct CompletionRow: View {
    let item: CompletionItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayText)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)

                if let description = item.description {
                    Text(description)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(item.kind.rawValue)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
    }

    private var iconColor: Color {
        switch item.kind {
        case .command:
            return .accentColor
        case .git:
            return .orange
        case .path:
            return .blue
        case .history:
            return .secondary
        }
    }
}
