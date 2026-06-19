import SwiftUI
import WarpCLICore

struct InspectorView: View {
    @Binding var selectedTab: InspectorTab
    @EnvironmentObject private var git: GitService
    @EnvironmentObject private var mcp: MCPManager

    var body: some View {
        VStack(spacing: 0) {
            Picker("Inspector Tab", selection: $selectedTab) {
                ForEach(Array(InspectorTab.allCases), id: \InspectorTab.id) { (tab: InspectorTab) in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch selectedTab {
                    case .ai:
                        AIInspectorView()
                    case .codeReview:
                        codeReviewPanel
                    case .mcp:
                        mcpPanel
                    }
                }
                .padding(16)
            }
            .background(.thinMaterial)
        }
        .frame(minWidth: 300, idealWidth: 360, maxWidth: 480)
    }

    private var codeReviewPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            inspectorSection("Repository") {
                HStack {
                    Label(git.currentBranch, systemImage: "arrow.branch")
                    Spacer()
                    Button("Refresh") { git.refresh(repositoryPath: FileManager.default.currentDirectoryPath) }
                }
                .font(.system(size: 13))

                if let error = git.lastError {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
            }

            inspectorSection("Changed Files") {
                if git.changedFiles.isEmpty {
                    Text("No changed files detected.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(git.changedFiles) { file in
                            Button {
                                git.loadDiff(repositoryPath: FileManager.default.currentDirectoryPath, filePath: file.path)
                            } label: {
                                HStack(spacing: 8) {
                                    Text(file.status)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Text(file.path)
                                        .font(.system(size: 12))
                                        .lineLimit(1)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            inspectorSection("Diff") {
                ScrollView(.horizontal) {
                    Text(git.selectedDiff.isEmpty ? "Select a changed file to load its diff." : git.selectedDiff)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(git.selectedDiff.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 140)
            }
        }
    }

    private var mcpPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            inspectorSection("Security Guardrails") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Restricted HOME per server", systemImage: "lock.shield")
                    Label("Inherited secrets filtered", systemImage: "key.slash")
                    Label("Audit events appended to ~/.warp/audit.log", systemImage: "doc.text.magnifyingglass")
                    Label("Rate limit: 60 calls/minute", systemImage: "speedometer")
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }

            inspectorSection("Servers") {
                HStack {
                    Text("\(mcp.servers.count) discovered")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Discover MCP Servers") { mcp.discover() }
                }

                if mcp.servers.isEmpty {
                    Text("No MCP servers discovered yet.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 10) {
                        ForEach(mcp.servers, id: \.id) { server in
                            MCPServerRow(
                                server: server,
                                log: mcp.logs[server.id],
                                onStart: { mcp.start(server) },
                                onStop: { mcp.stop(server) },
                                onRestart: { mcp.restart(server) },
                                onRemove: { mcp.remove(server) }
                            )
                        }
                    }
                }
            }
        }
    }

    private func inspectorSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.06))
        )
    }
}

private struct MCPServerRow: View {
    let server: MCPServer
    let log: String?
    let onStart: () -> Void
    let onStop: () -> Void
    let onRestart: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(server.name)
                        .font(.system(size: 13, weight: .semibold))
                    Text(server.command)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(server.status.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(statusColor.opacity(0.14)))
                    .foregroundStyle(statusColor)
            }

            HStack(spacing: 8) {
                Button("Start", action: onStart)
                    .disabled(server.status == .running)
                Button("Stop", action: onStop)
                    .disabled(server.status != .running)
                Button("Restart", action: onRestart)
                    .disabled(server.status == .discovered)
                Spacer()
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            .font(.system(size: 12))

            if let log, !log.isEmpty {
                Text(log)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.05))
        )
    }

    private var statusIcon: String {
        switch server.status {
        case .running: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .discovered: return "sparkle.magnifyingglass"
        case .stopped: return "stop.circle"
        }
    }

    private var statusColor: Color {
        switch server.status {
        case .running: return .green
        case .failed: return .red
        case .discovered: return .orange
        case .stopped: return .secondary
        }
    }
}
