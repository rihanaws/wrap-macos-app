import XCTest
@testable import WarpCLICore

final class CLISessionStoreTests: XCTestCase {
    func testSessionEventsPersistAndReload() throws {
        let directory = try temporaryDirectory(named: "sessions")
        let store = CLISessionStore(sessionDirectory: directory)
        let session = CLISession(id: "session-1", createdAt: Date(timeIntervalSince1970: 10), events: [])

        try store.save(session)
        try store.append(.user("hello"), to: session.id)
        try store.append(.assistant("world"), to: session.id)

        let loaded = try store.load(id: session.id)
        XCTAssertEqual(loaded.id, "session-1")
        XCTAssertEqual(loaded.events.map(\.role), [.user, .assistant])
        XCTAssertEqual(loaded.events.map(\.content), ["hello", "world"])
    }

    private func temporaryDirectory(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("WarpCLITests-\(UUID().uuidString)")
            .appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
