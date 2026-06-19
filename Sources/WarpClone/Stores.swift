import Foundation
import SwiftUI
import Combine

@MainActor
final class PreferencesStore: ObservableObject {
    @AppStorage("warpclone_theme") var theme = "dark" { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_fontSize") var fontSize = 13.0 { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_fontName") var fontName = "SF Mono" { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_inputPosition") var inputPosition = "pinned_to_bottom" { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_blockSpacing") var blockSpacing = "normal" { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_windowOpacity") var windowOpacity = 1.0 { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_blurRadius") var blurRadius = 0.0 { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_enableAI") var enableAI = true { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_aiProviderMode") var aiProviderMode = AIProviderKind.openRouter.rawValue { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_selectedAIModel") var selectedAIModel = "openai/gpt-4o" { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_verticalTabsEnabled") var verticalTabsEnabled = true { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_restoreSession") var restoreSession = true { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_vimModeEnabled") var vimModeEnabled = false { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_syntaxHighlighting") var syntaxHighlighting = true { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_ligaturesEnabled") var ligaturesEnabled = false { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_cursorStyle") var cursorStyle = "block" { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_cursorBlink") var cursorBlink = "never" { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_enableMCP") var enableMCP = true { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_mcpAutoDiscover") var mcpAutoDiscover = true { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_agentModeDefault") var agentModeDefault = "assist" { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_showDiffReview") var showDiffReview = true { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_maxImageAttachments") var maxImageAttachments = 5 { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_ptyShellPath") var ptyShellPath = "/bin/zsh" { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_debugMode") var debugMode = false { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_telemetryDisabled") var telemetryDisabled = false { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_autoDetectModel") var autoDetectModel = true { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_voiceInputEnabled") var voiceInputEnabled = false { willSet { objectWillChange.send() } }
    @AppStorage("warpclone_cachedOpenRouterModels") var cachedOpenRouterModels = "[]" { willSet { objectWillChange.send() } }

    func cachedModels() -> [AIModel] {
        guard let data = cachedOpenRouterModels.data(using: .utf8),
              let models = try? JSONDecoder().decode([AIModel].self, from: data)
        else { return [] }
        return models
    }

    func cache(models: [AIModel]) {
        guard let data = try? JSONEncoder().encode(models),
              let json = String(data: data, encoding: .utf8)
        else { return }
        cachedOpenRouterModels = json
    }
}

@MainActor
final class SessionStore: ObservableObject {
    @Published var sessions: [TerminalSession]
    @Published var selectedSessionID: UUID?
    @Published var activePaneID: UUID?
    @Published var isAIMode = false
    @Published var commandPaletteVisible = false
    @Published var imageAttachments: [ImageAttachment] = []

    init() {
        let cwd = FileManager.default.currentDirectoryPath
        let session = TerminalSession(name: "WarpClone", workingDirectory: cwd)
        self.sessions = [session]
        self.selectedSessionID = session.id
        self.activePaneID = session.activePaneID
    }

    var selectedSession: TerminalSession? {
        sessions.first { $0.id == selectedSessionID }
    }

    var selectedSessionBinding: Binding<TerminalSession>? {
        guard let id = selectedSessionID,
              let index = sessions.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.sessions[index] },
            set: { self.sessions[index] = $0 }
        )
    }

    var activePane: TerminalPane? {
        guard let session = selectedSession,
              let paneID = activePaneID else { return nil }
        return session.panes.first { $0.id == paneID }
    }

    func newSession(shellPath: String) {
        let session = TerminalSession(
            name: "Session \(sessions.count + 1)",
            workingDirectory: FileManager.default.currentDirectoryPath
        )
        var adjusted = session
        adjusted.panes[0].shellPath = shellPath
        sessions.append(adjusted)
        selectedSessionID = adjusted.id
        activePaneID = adjusted.activePaneID
    }

    func closeSelectedSession() {
        guard let selectedSessionID else { return }
        sessions.removeAll { $0.id == selectedSessionID }
        self.selectedSessionID = sessions.first?.id
        activePaneID = sessions.first?.activePaneID
    }

    func splitActivePane(shellPath: String) {
        guard let sessionIndex = selectedIndex else { return }
        let newPane = TerminalPane(
            title: "Split \(sessions[sessionIndex].panes.count + 1)",
            workingDirectory: sessions[sessionIndex].workingDirectory,
            shellPath: shellPath
        )
        sessions[sessionIndex].panes.append(newPane)
        sessions[sessionIndex].splitGroup.paneIDs.append(newPane.id)
        sessions[sessionIndex].activePaneID = newPane.id
        activePaneID = newPane.id
    }

    func closeActivePane() {
        guard let sessionIndex = selectedIndex,
              let activePaneID,
              sessions[sessionIndex].panes.count > 1 else { return }
        sessions[sessionIndex].panes.removeAll { $0.id == activePaneID }
        sessions[sessionIndex].splitGroup.paneIDs.removeAll { $0 == activePaneID }
        let next = sessions[sessionIndex].panes[0].id
        sessions[sessionIndex].activePaneID = next
        self.activePaneID = next
    }

    func focusPane(_ id: UUID) {
        activePaneID = id
        guard let sessionIndex = selectedIndex else { return }
        sessions[sessionIndex].activePaneID = id
    }

    func appendBlock(command: String, output: String, status: BlockStatus) {
        guard let sessionIndex = selectedIndex,
              let paneIndex = sessions[sessionIndex].panes.firstIndex(where: { $0.id == activePaneID }) else { return }
        sessions[sessionIndex].panes[paneIndex].blocks.append(
            TerminalBlock(
                command: command,
                rawOutput: output,
                status: status,
                startedAt: Date().addingTimeInterval(-1),
                endedAt: Date()
            )
        )
    }

    func updateActiveLiveOutput(_ output: String) {
        guard let sessionIndex = selectedIndex,
              let paneIndex = sessions[sessionIndex].panes.firstIndex(where: { $0.id == activePaneID }) else { return }
        sessions[sessionIndex].panes[paneIndex].liveOutput = output
    }

    private var selectedIndex: Int? {
        guard let selectedSessionID else { return nil }
        return sessions.firstIndex { $0.id == selectedSessionID }
    }
}
