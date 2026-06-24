import SwiftUI

struct TerminalDetailView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var sessions: SessionStore
    @EnvironmentObject private var runtime: TerminalRuntimeStore
    @EnvironmentObject private var ai: AIProviderManager
    @EnvironmentObject private var images: ImageAttachmentManager
    @EnvironmentObject private var conversation: ConversationStore
    @EnvironmentObject private var git: GitService

    @Binding var showInspector: Bool
    @State private var input = ""

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let binding = sessions.selectedSessionBinding {
                    SplitPaneContainer(session: binding)
                        .environmentObject(preferences)
                        .environmentObject(sessions)
                        .environmentObject(runtime)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "terminal")
                            .font(.largeTitle)
                        Text("No Session")
                            .font(.headline)
                        Text("Create a session to start.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: ThemeRegistry.theme(id: preferences.theme).background))

            if git.hasUncommittedChanges {
                gitDiffChip
            }

            Divider()

            InputEditorView(
                text: $input,
                isAIMode: $sessions.isAIMode,
                onSubmit: submitInput,
                onPickImage: {
                    images.pickImages(
                        maxCount: preferences.maxImageAttachments,
                        visionSupported: ai.visionSupported(modelID: preferences.selectedAIModel)
                    )
                },
                onPasteImage: {
                    images.addFromPasteboard(visionSupported: ai.visionSupported(modelID: preferences.selectedAIModel))
                }
            )
            .environmentObject(preferences)
            .environmentObject(ai)
            .environmentObject(images)
        }
        .background(Color(hex: ThemeRegistry.theme(id: preferences.theme).background).opacity(preferences.windowOpacity))
        .onAppear {
            git.refresh(repositoryPath: currentDirectory)
        }
    }

    private var gitDiffChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text.magnifyingglass")
                .foregroundStyle(.secondary)
            Text("\(git.changedFiles.count) files")
                .font(.system(size: 11, weight: .medium))
            HStack(spacing: 2) {
                Text("+\(git.totalAdditions)")
                    .foregroundStyle(.green)
                Text("-\(git.totalDeletions)")
                    .foregroundStyle(.red)
            }
            .font(.system(size: 11, weight: .medium))
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.separator, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            showInspector = true
            NotificationCenter.default.post(name: .showWarpCloneCodeReview, object: nil)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private var currentDirectory: String {
        sessions.selectedSession?.workingDirectory ?? FileManager.default.currentDirectoryPath
    }

    private func submitInput() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let isHashPrompt = trimmed == "#" || trimmed.hasPrefix("# ")
        if !sessions.isAIMode && !isHashPrompt {
            runtime.send(trimmed, to: sessions.activePaneID)
            sessions.appendBlock(command: trimmed, output: "", status: .running)
            input = ""
            return
        }

        let provider = AIProviderKind(rawValue: preferences.aiProviderMode) ?? .openRouter
        let userPrompt = isHashPrompt ? trimmed.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines) : trimmed
        guard !userPrompt.isEmpty else { return }
        let requestImages = images.attachments
        _ = conversation.addUserMessage(userPrompt)
        let assistantMessageID = conversation.addAssistantMessage(model: preferences.selectedAIModel)
        let blockID = sessions.appendBlock(command: "# \(userPrompt)", output: "", status: .running)
        input = ""
        images.clear()

        let task = Task { @MainActor in
            do {
                let request = AIRequest(
                    prompt: userPrompt,
                    model: preferences.selectedAIModel,
                    images: requestImages
                )
                let stream = try await ai.complete(kind: provider, request: request)
                for try await chunk in stream {
                    try Task.checkCancellation()
                    conversation.appendToMessage(id: assistantMessageID, text: chunk.text)
                    if let blockID {
                        sessions.updateBlock(id: blockID, output: conversation.content(for: assistantMessageID))
                    }
                    if chunk.isFinal {
                        break
                    }
                }
                conversation.finishStreaming(id: assistantMessageID)
                if let blockID {
                    sessions.updateBlock(id: blockID, output: conversation.content(for: assistantMessageID), status: .succeeded)
                }
            } catch is CancellationError {
                conversation.finishStreaming(id: assistantMessageID)
                if let blockID {
                    sessions.updateBlock(id: blockID, output: conversation.content(for: assistantMessageID), status: .succeeded)
                }
            } catch {
                conversation.setError(id: assistantMessageID, error: error.localizedDescription)
                if let blockID {
                    sessions.updateBlock(id: blockID, output: error.localizedDescription, status: .failed)
                }
            }
        }
        conversation.setActiveTask(task)
    }
}

private struct SplitPaneContainer: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var sessions: SessionStore
    @EnvironmentObject private var runtime: TerminalRuntimeStore

    @Binding var session: TerminalSession

    var body: some View {
        if session.panes.count == 1 {
            TerminalPaneView(pane: $session.panes[0])
                .environmentObject(preferences)
                .environmentObject(sessions)
                .environmentObject(runtime)
        } else if session.splitGroup.axis == .horizontal {
            HSplitView { panes }
        } else {
            VSplitView { panes }
        }
    }

    private var panes: some View {
        ForEach($session.panes) { $pane in
            TerminalPaneView(pane: $pane)
                .environmentObject(preferences)
                .environmentObject(sessions)
                .environmentObject(runtime)
                .frame(minWidth: 320, minHeight: 220)
        }
    }
}

private struct TerminalPaneView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var sessions: SessionStore
    @EnvironmentObject private var runtime: TerminalRuntimeStore

    @Binding var pane: TerminalPane

    var body: some View {
        VStack(spacing: 10) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: preferences.blockSpacing == "compact" ? 6 : 12) {
                    ForEach(pane.blocks) { block in
                        TerminalBlockView(block: block)
                    }
                    if !pane.liveOutput.isEmpty {
                        TerminalTextView(text: pane.liveOutput, fontName: preferences.fontName, fontSize: preferences.fontSize)
                            .frame(minHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(16)
                .animation(.easeOut(duration: 0.2), value: pane.blocks.count)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.separator.opacity(sessions.activePaneID == pane.id ? 0.85 : 0.35), lineWidth: 1)
        )
        .padding(8)
        .contentShape(Rectangle())
        .onTapGesture {
            sessions.focusPane(pane.id)
        }
        .onAppear {
            runtime.ensureStarted(pane: pane) { text in
                pane.liveOutput += text
            } onExit: { code in
                pane.blocks.append(TerminalBlock(command: "shell exited", rawOutput: "exit \(code)", status: code == 0 ? .succeeded : .failed, endedAt: Date()))
            }
        }
    }
}
