import AppKit
import SwiftUI

struct AIInspectorView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var sessions: SessionStore
    @EnvironmentObject private var ai: AIProviderManager
    @EnvironmentObject private var images: ImageAttachmentManager
    @EnvironmentObject private var conversation: ConversationStore

    @State private var input = ""
    @State private var attemptedAutoLoad = false

    var body: some View {
        VStack(spacing: 0) {
            providerHeader
                .padding(.horizontal, 12)
                .padding(.top, 12)

            Divider()
                .padding(.top, 12)

            chatHistory

            Divider()

            composer
                .padding(12)
        }
        .task {
            await preloadModelsIfNeeded()
        }
    }

    private var providerHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            ModelPickerMenu()
                .environmentObject(preferences)
                .environmentObject(ai)

            HStack(spacing: 8) {
                Text(preferences.aiProviderMode)
                    .font(.system(size: 12, weight: .medium))

                if ai.visionSupported(modelID: preferences.selectedAIModel) {
                    Label("Vision", systemImage: "eye.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                }

                Spacer()

                Button {
                    refreshModels()
                } label: {
                    if ai.isLoadingModels {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .help("Load Models")
                .disabled(ai.isLoadingModels)
            }

            if let error = ai.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
    }

    private var chatHistory: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if conversation.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(conversation.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if conversation.isStreaming {
                            StreamingIndicator()
                                .id("streaming-indicator")
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeOut(duration: 0.2), value: conversation.messages.count)
            }
            .onChange(of: conversation.messages.count) { _ in
                scrollToBottom(proxy)
            }
            .onChange(of: conversation.messages.map(\.content).joined()) { _ in
                scrollToBottom(proxy)
            }
            .onChange(of: conversation.isStreaming) { _ in
                scrollToBottom(proxy)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Ask the AI from the terminal with # or use the composer below.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            attachmentStrip

            HStack(spacing: 8) {
                TextField("Ask the AI...", text: $input)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 10)
                    .frame(minHeight: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.separator, lineWidth: 1)
                    )
                    .onSubmit(sendInspectorPrompt)

                if conversation.isStreaming {
                    Button {
                        conversation.cancel()
                    } label: {
                        Image(systemName: "square.fill")
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.borderless)
                    .help("Stop")
                } else {
                    Button {
                        sendInspectorPrompt()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("Send")
                }
            }
        }
    }

    private var attachmentStrip: some View {
        HStack(spacing: 8) {
            ForEach(images.attachments.prefix(preferences.maxImageAttachments)) { attachment in
                if let image = NSImage(data: attachment.thumbnailData) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 42, height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.separator, lineWidth: 1)
                        )
                }
            }
            Spacer(minLength: 0)
        }
        .frame(height: images.attachments.isEmpty ? 0 : 46)
        .clipped()
    }

    private func sendInspectorPrompt() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let provider = AIProviderKind(rawValue: preferences.aiProviderMode) ?? .openRouter
        let requestImages = images.attachments
        _ = conversation.addUserMessage(trimmed)
        let assistantMessageID = conversation.addAssistantMessage(model: preferences.selectedAIModel)
        let blockID = sessions.appendBlock(command: "# \(trimmed)", output: "", status: .running)
        input = ""
        images.clear()

        let task = Task { @MainActor in
            do {
                let request = AIRequest(prompt: trimmed, model: preferences.selectedAIModel, images: requestImages)
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

    private func refreshModels() {
        guard let kind = AIProviderKind(rawValue: preferences.aiProviderMode) else { return }
        Task { await ai.loadModels(kind: kind) }
    }

    private func preloadModelsIfNeeded() async {
        guard !attemptedAutoLoad else { return }
        attemptedAutoLoad = true
        if ai.models.isEmpty {
            let cached = preferences.cachedModels()
            if cached.isEmpty {
                if let kind = AIProviderKind(rawValue: preferences.aiProviderMode) {
                    await ai.loadModels(kind: kind)
                }
            } else {
                ai.models = cached
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                if conversation.isStreaming {
                    proxy.scrollTo("streaming-indicator", anchor: .bottom)
                } else if let last = conversation.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}

private struct MessageBubble: View {
    let message: AIConversationMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 36)
            }

            VStack(alignment: .leading, spacing: 8) {
                header
                content
                if let error = message.error {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
            }
            .padding(10)
            .frame(maxWidth: 320, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(message.role == .user ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
            )

            if message.role == .assistant {
                Spacer(minLength: 36)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(message.role == .user ? "You" : (message.model ?? "Assistant"))
                .font(.system(size: 11, weight: .semibold))
            Text(Self.timeFormatter.string(from: message.timestamp))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var content: some View {
        if message.role == .assistant {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(extractTextSegments(from: message.content)) { segment in
                    switch segment {
                    case .plain(_, let text):
                        if !text.isEmpty {
                            Text(text)
                                .font(.system(size: 12))
                                .textSelection(.enabled)
                        }
                    case .code(_, let language, let code):
                        CodeBlockView(language: language, code: code)
                    }
                }
            }
        } else {
            Text(message.content)
                .font(.system(size: 12))
                .textSelection(.enabled)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

private enum AttributedTextSegment: Identifiable {
    case plain(UUID, String)
    case code(UUID, String?, String)

    var id: UUID {
        switch self {
        case .plain(let id, _), .code(let id, _, _):
            id
        }
    }
}

private func extractTextSegments(from text: String) -> [AttributedTextSegment] {
    var segments: [AttributedTextSegment] = []
    var remainder = text[...]

    while let opening = remainder.range(of: "```") {
        let plain = String(remainder[..<opening.lowerBound])
        if !plain.isEmpty {
            segments.append(.plain(UUID(), plain))
        }

        let afterOpening = remainder[opening.upperBound...]
        guard let closing = afterOpening.range(of: "```") else {
            segments.append(.plain(UUID(), String(remainder[opening.lowerBound...])))
            return segments
        }

        let rawBlock = String(afterOpening[..<closing.lowerBound])
        let hasLanguageLabel = !rawBlock.hasPrefix("\n") && !rawBlock.hasPrefix("\r\n")
        let lines = rawBlock.split(separator: "\n", omittingEmptySubsequences: false)
        let language = hasLanguageLabel ? lines.first.map(String.init).flatMap { firstLine -> String? in
            firstLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : firstLine
        } : nil
        let code = language == nil
            ? rawBlock.trimmingCharacters(in: .newlines)
            : lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .newlines)
        segments.append(.code(UUID(), language, code))
        remainder = afterOpening[closing.upperBound...]
    }

    let tail = String(remainder)
    if !tail.isEmpty {
        segments.append(.plain(UUID(), tail))
    }
    return segments
}

private struct CodeBlockView: View {
    let language: String?
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let language {
                    Text(language)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.30))
        )
    }
}

private struct StreamingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Text("●")
                    .font(.system(size: 9))
                    .opacity(phase == index ? 1 : 0.35)
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.28, repeats: true) { _ in
                phase = (phase + 1) % 3
            }
        }
    }
}
