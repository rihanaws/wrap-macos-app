import SwiftUI

struct InspectorView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var sessions: SessionStore
    @EnvironmentObject private var ai: AIProviderManager
    @EnvironmentObject private var git: GitService
    @EnvironmentObject private var mcp: MCPManager

    @Binding var selectedTab: InspectorTab

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            tabSelector

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch selectedTab {
                    case .ai:
                        AIInspectorView()
                            .environmentObject(preferences)
                            .environmentObject(ai)
                    case .codeReview:
                        codeReviewTab
                    case .mcp:
                        mcpTab
                    }
                }
                .padding(.bottom, 18)
            }
        }
        .padding(.vertical, 16)
        .background(.thinMaterial)
        .frame(minWidth: 300, idealWidth: 360, maxWidth: 480, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeOut(duration: 0.15), value: selectedTab)
    }

    private var tabSelector: some View {
        HStack(spacing: 4) {
            ForEach(InspectorTab.allCases) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? Color.accentColor.opacity(0.22) : Color.clear)
                        )
                        .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.secondary.opacity(0.08)))
        .overlay(Capsule().strokeBorder(Color.separator, lineWidth: 1))
        .padding(.horizontal, 12)
    }

    private var codeReviewTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            inspectorSection("Repository") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Branch: \(git.currentBranch)")
                    Button("Refresh") {
                        if let path = sessions.selectedSession?.workingDirectory {
                            git.refresh(repositoryPath: path)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    if let error = git.lastError {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }

            inspectorSection("Changed Files") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(git.changedFiles) { file in
                        Button {
                            if let path = sessions.selectedSession?.workingDirectory {
                                git.loadDiff(repositoryPath: path, filePath: file.path, staged: file.staged)
                            }
                        } label: {
                            HStack {
                                Text(file.status)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Text(file.path)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            inspectorSection("Diff") {
                Text(git.selectedDiff.isEmpty ? "Select a file to load its diff." : git.selectedDiff)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var mcpTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            inspectorSection("Servers") {
                VStack(alignment: .leading, spacing: 10) {
                    Button("Discover MCP Servers") { mcp.discover() }
                        .buttonStyle(.borderedProminent)
                    ForEach(mcp.servers) { server in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(server.name)
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Text(server.status.rawValue)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(server.status == .failed ? .red : .secondary)
                            }
                            Text(server.command)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            HStack {
                                Button("Start") { mcp.start(server) }
                                Button("Stop") { mcp.stop(server) }
                                Button("Restart") { mcp.restart(server) }
                                Button("Remove", role: .destructive) { mcp.remove(server) }
                            }
                            .buttonStyle(.bordered)
                            if let log = mcp.logs[server.id] {
                                Text(log)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.05)))
                    }
                }
            }
        }
    }

    private func inspectorSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.top, 20)
            content()
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.06))
                )
        }
        .padding(.horizontal, 12)
    }
}
