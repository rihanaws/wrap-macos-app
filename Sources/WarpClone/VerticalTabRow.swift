import SwiftUI

struct VerticalTabRow: View {
    var session: TerminalSession
    var isSelected: Bool
    @State private var hovering = false
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "terminal")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                    .frame(width: 22, height: 22)
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                    .scaleEffect(1.0 + (session.unreadActivity || pulsing ? 0.18 : 0))
                    .overlay(Circle().stroke(.background, lineWidth: 1.5))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 9, weight: .medium))
                    Text(branchLabel)
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 6)
        }
        .frame(height: 52)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : (hovering ? Color.secondary.opacity(0.08) : Color.clear))
        )
        .overlay(alignment: .leading) {
            if isSelected {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering = $0 }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulsing = session.unreadActivity
            }
        }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .animation(.easeOut(duration: 0.18), value: isSelected)
    }

    private var statusColor: Color {
        session.unreadActivity ? .purple : .green
    }

    private var branchLabel: String {
        if let branch = session.gitBranch, !branch.isEmpty {
            return branch
        }
        return URL(fileURLWithPath: session.workingDirectory).lastPathComponent
    }
}
