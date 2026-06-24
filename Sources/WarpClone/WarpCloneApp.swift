import SwiftUI
import AppKit

final class WarpCloneAppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "warpclone" {
            NotificationCenter.default.post(name: .warpCloneAuthCallback, object: url)
        }
    }
}

extension Notification.Name {
    static let warpCloneAuthCallback = Notification.Name("warpCloneAuthCallback")
}

@main
struct WarpCloneApp: App {
    @NSApplicationDelegateAdaptor(WarpCloneAppDelegate.self) private var appDelegate
    @StateObject private var preferences = PreferencesStore()
    @StateObject private var sessions = SessionStore()
    @StateObject private var runtime = TerminalRuntimeStore()
    @StateObject private var ai = AIProviderManager()
    @StateObject private var git = GitService()
    @StateObject private var mcp = MCPManager()
    @StateObject private var images = ImageAttachmentManager()
    @StateObject private var conversation = ConversationStore()

    var body: some Scene {
        WindowGroup("WarpClone") {
            ContentView()
                .environmentObject(preferences)
                .environmentObject(sessions)
                .environmentObject(runtime)
                .environmentObject(ai)
                .environmentObject(git)
                .environmentObject(mcp)
                .environmentObject(images)
                .environmentObject(conversation)
                .frame(minWidth: 1000, minHeight: 700)
        }
        .defaultSize(width: 1000, height: 700)
        .commands {
            WarpCloneCommands(
                preferences: preferences,
                sessions: sessions,
                ai: ai,
                git: git,
                mcp: mcp
            )
        }

        Settings {
            SettingsView()
                .environmentObject(preferences)
                .environmentObject(ai)
                .frame(width: 750, height: 550)
        }
    }
}

struct WarpCloneCommands: Commands {
    @ObservedObject var preferences: PreferencesStore
    @ObservedObject var sessions: SessionStore
    @ObservedObject var ai: AIProviderManager
    @ObservedObject var git: GitService
    @ObservedObject var mcp: MCPManager

    var body: some Commands {
        CommandMenu("Session") {
            Button("New Session") { sessions.newSession(shellPath: preferences.ptyShellPath) }
                .keyboardShortcut("n", modifiers: .command)
            Button("Split Pane") { sessions.splitActivePane(shellPath: preferences.ptyShellPath) }
                .keyboardShortcut("d", modifiers: .command)
            Button("Close Split") { sessions.closeActivePane() }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Button("Close Session") { sessions.closeSelectedSession() }
                .keyboardShortcut("w", modifiers: .command)
        }

        CommandMenu("Blocks") {
            Button("Clear Session") { sessions.updateActiveLiveOutput("") }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            Button("Bookmark Last Block") {}
            Button("Ask AI About Last Block") { sessions.isAIMode = true }
        }

        CommandMenu("AI") {
            Button("Toggle AI Mode") { sessions.isAIMode.toggle() }
                .keyboardShortcut("#", modifiers: .command)
            Button("Load Provider Models") {
                Task { await aiPlaceholderLoad() }
            }
        }

        CommandMenu("Code Review") {
            Button("Refresh Git Review") {
                if let path = sessions.selectedSession?.workingDirectory {
                    git.refresh(repositoryPath: path)
                }
            }
            Button("Review Selected Diff") { sessions.isAIMode = true }
        }

        CommandMenu("MCP") {
            Button("Discover Servers") { mcp.discover() }
            Button("Stop All Servers") {
                for server in mcp.servers { mcp.stop(server) }
            }
        }

        CommandMenu("View") {
            Button("Command Palette") { sessions.commandPaletteVisible = true }
                .keyboardShortcut("p", modifiers: .command)
            Button("Toggle Sidebar") {
                NotificationCenter.default.post(name: .toggleWarpCloneSidebar, object: nil)
            }
            .keyboardShortcut("b", modifiers: .command)
            Button("Toggle Inspector") {
                NotificationCenter.default.post(name: .toggleWarpCloneInspector, object: nil)
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
        }
    }

    private func aiPlaceholderLoad() async {
        if let kind = AIProviderKind(rawValue: preferences.aiProviderMode) {
            await ai.loadModels(kind: kind)
        }
    }
}

extension Notification.Name {
    static let toggleWarpCloneInspector = Notification.Name("toggleWarpCloneInspector")
    static let toggleWarpCloneSidebar = Notification.Name("toggleWarpCloneSidebar")
    static let showWarpCloneCodeReview = Notification.Name("showWarpCloneCodeReview")
}
