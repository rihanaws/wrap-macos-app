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

    /// Risk classes where reusable approval is policy-safe; destructive/network/credential/unknown
    /// must always re-prompt, so `Always Allow` is excluded for them regardless of caller wiring.
    private var canAlwaysAllow: Bool {
        switch risk {
        case .readOnly, .write:
            return onAlwaysAllow != nil
        case .destructive, .network, .credential, .unknown:
            return false
        }
    }

    private struct RiskPresentation {
        let symbol: String
        let color: Color
        let badgeText: String
        let accessibilityLabel: String
    }

    /// Risk classes whose approval must not be triggerable by a stray Return keypress —
    /// high-impact actions require an explicit click or keyboard navigation to the button.
    private var requiresExplicitConfirmation: Bool {
        switch risk {
        case .destructive, .network, .credential:
            return true
        case .readOnly, .write, .unknown:
            return false
        }
    }

    private var riskPresentation: RiskPresentation {
        switch risk {
        case .destructive:
            return RiskPresentation(symbol: "exclamationmark.triangle.fill", color: .red, badgeText: "Destructive", accessibilityLabel: "Destructive action warning")
        case .network:
            return RiskPresentation(symbol: "network", color: .orange, badgeText: "Network", accessibilityLabel: "Network action warning")
        case .credential:
            return RiskPresentation(symbol: "key.fill", color: .yellow, badgeText: "Credential", accessibilityLabel: "Credential access warning")
        case .write:
            return RiskPresentation(symbol: "pencil.and.outline", color: .blue, badgeText: "Write", accessibilityLabel: "Write action permission request")
        case .readOnly:
            return RiskPresentation(symbol: "eye", color: .secondary, badgeText: "Read-only", accessibilityLabel: "Read-only permission request")
        case .unknown:
            return RiskPresentation(symbol: "questionmark.diamond.fill", color: .purple, badgeText: "Unknown", accessibilityLabel: "Unknown risk permission request")
        }
    }

    var body: some View {
        let presentation = riskPresentation

        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 4) {
                    Image(systemName: presentation.symbol)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(presentation.color)
                    Text(presentation.badgeText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(presentation.color)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(presentation.accessibilityLabel). \(title). \(message)")

            if let command, !command.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Command")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ScrollView([.vertical, .horizontal]) {
                        Text(command)
                            .font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(10)
                            .frame(minWidth: 0, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
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

                if requiresExplicitConfirmation {
                    Button("Allow Once", action: onAllowOnce)
                } else {
                    Button("Allow Once", action: onAllowOnce)
                        .keyboardShortcut(.defaultAction)
                }

                if canAlwaysAllow, let onAlwaysAllow {
                    Button("Always Allow", action: onAlwaysAllow)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(22)
        .frame(minWidth: 420, idealWidth: 520, maxWidth: 620)
        .fixedSize(horizontal: false, vertical: true)
    }
}
