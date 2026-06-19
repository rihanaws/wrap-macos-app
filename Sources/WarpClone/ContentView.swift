import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var sessions: SessionStore
    @EnvironmentObject private var ai: AIProviderManager
    @EnvironmentObject private var git: GitService
    @EnvironmentObject private var mcp: MCPManager

    @SceneStorage("warpclone_selectedSessionID") private var selectedSessionStorage = ""
    @SceneStorage("warpclone_showInspector") private var showInspector = true
    @SceneStorage("warpclone_inspectorTab") private var inspectorTab = InspectorTab.ai.rawValue
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var commandPalette = false

    var body: some View {
        root
            .onAppear {
                if let id = UUID(uuidString: selectedSessionStorage) {
                    sessions.selectedSessionID = id
                }
                mcp.discover()
            }
            .onChange(of: sessions.selectedSessionID) { newValue in
                selectedSessionStorage = newValue?.uuidString ?? ""
            }
            .onChange(of: sessions.commandPaletteVisible) { visible in
                commandPalette = visible
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleWarpCloneInspector)) { _ in
                showInspector.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleWarpCloneSidebar)) { _ in
                withAnimation(.snappy(duration: 0.18)) {
                    switch columnVisibility {
                    case .detailOnly:
                        columnVisibility = .all
                    default:
                        columnVisibility = .detailOnly
                    }
                }
            }
            .sheet(isPresented: Binding(get: {
                commandPalette || sessions.commandPaletteVisible
            }, set: { newValue in
                commandPalette = newValue
                sessions.commandPaletteVisible = newValue
            })) {
                CommandPaletteView()
                    .environmentObject(sessions)
                    .environmentObject(git)
                    .environmentObject(mcp)
                    .frame(width: 640, height: 480)
            }
    }

    private var root: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            TerminalDetailView(showInspector: $showInspector)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    sessions.newSession(shellPath: preferences.ptyShellPath)
                } label: {
                    Label("New Session", systemImage: "plus")
                }
                Button {
                    sessions.splitActivePane(shellPath: preferences.ptyShellPath)
                } label: {
                    Label("Split Pane", systemImage: "rectangle.split.2x1")
                }
                Button {
                    sessions.commandPaletteVisible = true
                } label: {
                    Label("Command Palette", systemImage: "command")
                }
                Button {
                    showInspector.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.right")
                }
            }
        }
        .warpInspector(isPresented: $showInspector) {
            InspectorView(selectedTab: Binding(
                get: { InspectorTab(rawValue: inspectorTab) ?? .ai },
                set: { inspectorTab = $0.rawValue }
            ))
            .environmentObject(preferences)
            .environmentObject(sessions)
            .environmentObject(ai)
            .environmentObject(git)
            .environmentObject(mcp)
        }
    }
}

private extension View {
    @ViewBuilder
    func warpInspector<InspectorContent: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> InspectorContent
    ) -> some View {
        if #available(macOS 14, *) {
            self.inspector(isPresented: isPresented) {
                content()
                    .inspectorColumnWidth(min: 300, ideal: 360, max: 480)
            }
        } else {
            HStack(spacing: 0) {
                self
                if isPresented.wrappedValue {
                    Divider()
                    content()
                        .frame(minWidth: 300, idealWidth: 360, maxWidth: 480)
                }
            }
        }
    }
}
