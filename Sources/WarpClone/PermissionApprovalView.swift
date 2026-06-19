import SwiftUI
import WarpCLICore

struct PermissionApprovalView: View {
    let title: String
    let message: String
    let command: String?
    let risk: ToolRisk
    let onAllowOnce: () -> Void
    let onDeny: () -> Void
    let onEditCommand: (() -> Void)?
    let onAlwaysAllow: (() -> Void)?

    private var canAlwaysAllow: Bool {
        risk != .destructive && risk != .network && onAlwaysAllow != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: risk == .destructive ? "exclamationmark.triangle.fill" : "hand.raised.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(risk == .destructive ? .red : .accentColor)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let command, !command.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Command")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(command)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.08))
                        )
                }
            }

            HStack {
                Button("Deny", role: .cancel, action: onDeny)

                Spacer()

                if command != nil {
                    Button("Edit Command") {
                        onEditCommand?()
                    }
                    .disabled(onEditCommand == nil)
                }

                Button("Allow Once", action: onAllowOnce)
                    .keyboardShortcut(.defaultAction)

                if canAlwaysAllow, let onAlwaysAllow {
                    Button("Always Allow", action: onAlwaysAllow)
                }
            }
        }
        .padding(22)
        .frame(width: 460)
    }
}
