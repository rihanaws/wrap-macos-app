import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var sessions: SessionStore

    var body: some View {
        List(selection: $sessions.selectedSessionID) {
            Section("Sessions") {
                ForEach(sessions.sessions) { session in
                    VerticalTabRow(session: session, isSelected: sessions.selectedSessionID == session.id)
                        .tag(Optional(session.id))
                        .contextMenu {
                            Button("Rename") {}
                            Button("Duplicate") {}
                            Button("Split Right") { sessions.splitActivePane(shellPath: "/bin/zsh") }
                            Button("Split Down") { sessions.splitActivePane(shellPath: "/bin/zsh") }
                            Button("Clear Notifications") {}
                            Button("Copy Path") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(session.workingDirectory, forType: .string)
                            }
                            Divider()
                            Button("Close") { sessions.closeSelectedSession() }
                        }
                        .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
        .navigationTitle("WarpClone")
    }
}
