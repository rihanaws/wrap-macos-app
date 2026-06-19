import Foundation

public struct CLISession: Codable, Equatable {
    public var id: String
    public var createdAt: Date
    public var updatedAt: Date
    public var events: [CLISessionEvent]

    public init(id: String = UUID().uuidString, createdAt: Date = Date(), updatedAt: Date = Date(), events: [CLISessionEvent] = []) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.events = events
    }
}

public struct CLISessionEvent: Codable, Equatable, Identifiable {
    public enum Role: String, Codable {
        case system
        case user
        case assistant
        case tool
    }

    public var id: UUID
    public var role: Role
    public var content: String
    public var createdAt: Date

    public init(id: UUID = UUID(), role: Role, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }

    public static func system(_ content: String) -> CLISessionEvent {
        CLISessionEvent(role: .system, content: content)
    }

    public static func user(_ content: String) -> CLISessionEvent {
        CLISessionEvent(role: .user, content: content)
    }

    public static func assistant(_ content: String) -> CLISessionEvent {
        CLISessionEvent(role: .assistant, content: content)
    }

    public static func tool(_ content: String) -> CLISessionEvent {
        CLISessionEvent(role: .tool, content: content)
    }
}

public final class CLISessionStore {
    public let sessionDirectory: URL

    public init(sessionDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".warp/sessions")) {
        self.sessionDirectory = sessionDirectory
    }

    public func save(_ session: CLISession) throws {
        try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder.warpCLI.encode(session)
        try data.write(to: url(for: session.id), options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    public func load(id: String) throws -> CLISession {
        let data = try Data(contentsOf: url(for: id))
        return try JSONDecoder.warpCLI.decode(CLISession.self, from: data)
    }

    public func append(_ event: CLISessionEvent, to id: String) throws {
        var session = try load(id: id)
        session.events.append(event)
        session.updatedAt = Date()
        try save(session)
    }

    public func list() throws -> [CLISession] {
        guard FileManager.default.fileExists(atPath: sessionDirectory.path) else {
            return []
        }

        return try FileManager.default.contentsOfDirectory(at: sessionDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                try? JSONDecoder.warpCLI.decode(CLISession.self, from: Data(contentsOf: url))
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func url(for id: String) -> URL {
        sessionDirectory.appendingPathComponent("\(id).json")
    }
}
