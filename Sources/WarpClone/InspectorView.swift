import SwiftUI
import WarpCLICore
import AppKit

private struct ReviewComment: Identifiable {
    let id = UUID()
    let lineNumber: Int?
    let text: String
}

struct InspectorView: View {
    @Binding var selectedTab: InspectorTab
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var ai: AIProviderManager
    @EnvironmentObject private var git: GitService
    @EnvironmentObject private var sessions: SessionStore
    @EnvironmentObject private var mcp: MCPManager
    @State private var pendingMCPApproval: MCPServer?
    @State private var selectedReviewFilePath: String?
    @State private var showDiscardConfirmation = false
    @State private var codeReviewAlert: String?
    @State private var reviewComments: [ReviewComment] = []
    @State private var commentText = ""
    @State private var isSubmittingReview = false

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
        .sheet(item: $pendingMCPApproval) { server in
            PermissionApprovalView(
                title: "Approve MCP Server?",
                message: "\(server.name) wants to run \(server.command). Approved descriptor hashes persist until removed from settings or app data.",
                command: ([server.command] + server.arguments).joined(separator: " "),
                risk: .unknown,
                onAllowOnce: {
                    mcp.approve(server)
                    mcp.start(server)
                    pendingMCPApproval = nil
                },
                onDeny: {
                    mcp.deny(server)
                    pendingMCPApproval = nil
                },
                onEditCommand: nil,
                onAlwaysAllow: {
                    mcp.approve(server)
                    mcp.start(server)
                    pendingMCPApproval = nil
                }
            )
        }
    }

    private var codeReviewPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            inspectorSection("Repository") {
                HStack(spacing: 8) {
                    Label(git.currentBranch, systemImage: "arrow.branch")
                        .lineLimit(1)
                    Spacer()
                    if git.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Button {
                        refreshGit()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh")
                }
                .font(.system(size: 13))

                if let error = git.lastError {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
            }

            HStack(spacing: 0) {
                fileSidebar
                    .frame(width: 180)
                Divider()
                diffContent
            }
            .frame(minHeight: 340)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.separator.opacity(0.5), lineWidth: 1)
            )

            bottomCodeReviewBar
        }
        .onAppear {
            refreshGit()
        }
        .confirmationDialog(
            "Discard all changes?",
            isPresented: $showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard All", role: .destructive) {
                discardAllChanges()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This runs git checkout -- . in \(currentDirectory).")
        }
        .alert(
            "Code Review",
            isPresented: Binding(
                get: { codeReviewAlert != nil },
                set: { if !$0 { codeReviewAlert = nil } }
            )
        ) {
            Button("OK") { codeReviewAlert = nil }
        } message: {
            Text(codeReviewAlert ?? "")
        }
    }

    private var fileSidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(git.changedFiles.count) Files")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if git.changedFiles.contains(where: { !$0.staged }) {
                    Button("Stage All") {
                        stageAllChanges()
                    }
                    .font(.system(size: 11))
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)

            if git.changedFiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 20))
                    Text("No changes")
                        .font(.system(size: 12))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(git.changedFiles) { file in
                            Button {
                                selectedReviewFilePath = file.path
                                git.loadDiff(repositoryPath: currentDirectory, filePath: file.path, staged: file.staged)
                            } label: {
                                fileRow(file)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 8)
                }
            }
        }
        .background(Color.secondary.opacity(0.035))
    }

    private func fileRow(_ file: GitChangedFile) -> some View {
        let isSelected = selectedReviewFilePath == file.path

        return HStack(spacing: 7) {
            Image(systemName: statusIcon(for: file.status))
                .foregroundStyle(statusColor(for: file.status))
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.path)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if file.staged {
                    Text("staged")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
        )
        .overlay(alignment: .leading) {
            if isSelected {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 2)
            }
        }
    }

    private var diffContent: some View {
        VStack(spacing: 0) {
            if git.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if git.selectedDiff.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 24))
                    Text("Select a file to view its diff")
                        .font(.system(size: 12))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView([.vertical, .horizontal]) {
                    DiffView(diffText: git.selectedDiff)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bottomCodeReviewBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            commentBox

            HStack(spacing: 8) {
                Button {
                    submitReviewToAI()
                } label: {
                    if isSubmittingReview {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Submit Review to AI")
                    }
                }
                .disabled(git.selectedDiff.isEmpty || reviewComments.isEmpty || isSubmittingReview)

                Button("Open in Editor") {
                    openSelectedFile()
                }
                .disabled(selectedReviewFilePath == nil)

                Spacer()

                Button("Stage All") {
                    stageAllChanges()
                }
                .disabled(git.changedFiles.isEmpty)

                Button("Discard All", role: .destructive) {
                    showDiscardConfirmation = true
                }
                .disabled(git.changedFiles.isEmpty)
            }
        }
        .font(.system(size: 12))
    }

    private var commentBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Review Comments")
                .font(.system(size: 12, weight: .semibold))

            if !reviewComments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(reviewComments) { comment in
                        HStack(spacing: 8) {
                            Text(comment.text)
                                .font(.system(size: 11))
                                .lineLimit(2)
                            Spacer()
                            Button {
                                removeComment(comment.id)
                            } label: {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(6)
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Add a comment...", text: $commentText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .onSubmit(addComment)

                Button("Add") {
                    addComment()
                }
                .font(.system(size: 11, weight: .medium))
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(7)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
    }

    private var currentDirectory: String {
        sessions.selectedSession?.workingDirectory ?? FileManager.default.currentDirectoryPath
    }

    private func refreshGit() {
        git.refresh(repositoryPath: currentDirectory)
        if let selectedReviewFilePath,
           git.changedFiles.contains(where: { $0.path == selectedReviewFilePath }) {
            git.loadDiff(repositoryPath: currentDirectory, filePath: selectedReviewFilePath)
        } else {
            selectedReviewFilePath = git.changedFiles.first?.path
            if let file = git.changedFiles.first {
                git.loadDiff(repositoryPath: currentDirectory, filePath: file.path, staged: file.staged)
            }
        }
    }

    private func stageAllChanges() {
        do {
            try git.runGit(["add", "-A"], cwd: currentDirectory)
            refreshGit()
        } catch {
            codeReviewAlert = error.localizedDescription
        }
    }

    private func discardAllChanges() {
        do {
            try git.runGit(["checkout", "--", "."], cwd: currentDirectory)
            selectedReviewFilePath = nil
            git.selectedDiff = ""
            refreshGit()
        } catch {
            codeReviewAlert = error.localizedDescription
        }
    }

    private func openSelectedFile() {
        guard let selectedReviewFilePath else { return }
        let url = URL(fileURLWithPath: currentDirectory).appendingPathComponent(selectedReviewFilePath)
        NSWorkspace.shared.open(url)
    }

    private func addComment() {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        reviewComments.append(ReviewComment(lineNumber: nil, text: trimmed))
        commentText = ""
    }

    private func removeComment(_ id: UUID) {
        reviewComments.removeAll { $0.id == id }
    }

    private func submitReviewToAI() {
        guard !reviewComments.isEmpty, !git.selectedDiff.isEmpty else { return }
        let commentsText = reviewComments
            .map { comment in
                if let lineNumber = comment.lineNumber {
                    return "- Line \(lineNumber): \(comment.text)"
                }
                return "- \(comment.text)"
            }
            .joined(separator: "\n")
        let prompt = """
        I have the following git diff for review:

        \(git.selectedDiff)

        Review comments:
        \(commentsText)

        Please address these comments and provide an updated unified git diff. Return the diff first.
        """
        let blockID = sessions.appendBlock(command: "# Review: AI fixing code", output: "", status: .running)
        let provider = AIProviderKind(rawValue: preferences.aiProviderMode) ?? .openRouter
        isSubmittingReview = true

        Task { @MainActor in
            var response = ""
            do {
                let request = AIRequest(prompt: prompt, model: preferences.selectedAIModel, images: [])
                let stream = try await ai.complete(kind: provider, request: request)
                for try await chunk in stream {
                    response += chunk.text
                    if let blockID {
                        sessions.updateBlock(id: blockID, output: response)
                    }
                }
                if response.contains("diff --git") || response.contains("@@") {
                    git.selectedDiff = response
                }
                reviewComments.removeAll()
                if let blockID {
                    sessions.updateBlock(id: blockID, output: response, status: .succeeded)
                }
            } catch {
                if let blockID {
                    sessions.updateBlock(id: blockID, output: error.localizedDescription, status: .failed)
                }
                codeReviewAlert = error.localizedDescription
            }
            isSubmittingReview = false
        }
    }

    private func statusIcon(for status: String) -> String {
        switch status {
        case "M": return "circle.fill"
        case "A": return "plus.circle.fill"
        case "D": return "minus.circle.fill"
        case "R": return "arrow.right.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "M": return .yellow
        case "A": return .green
        case "D": return .red
        case "R": return .blue
        default: return .secondary
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
                                onStart: {
                                    if server.isApproved {
                                        mcp.start(server)
                                    } else {
                                        pendingMCPApproval = server
                                    }
                                },
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
