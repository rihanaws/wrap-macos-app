import XCTest
@testable import WarpCLICore

final class CLIConfigStoreTests: XCTestCase {
    func testConfigRoundTripsWithoutSecrets() throws {
        let directory = try temporaryDirectory(named: "config")
        let store = CLIConfigStore(configDirectory: directory)
        let config = CLIConfig(
            defaultProvider: .openRouter,
            defaultModel: "openai/gpt-4o",
            permissionMode: .allowRead,
            telemetryEnabled: false
        )

        try store.save(config)
        let loaded = try store.load()

        XCTAssertEqual(loaded, config)
        let raw = try String(contentsOf: store.configFileURL, encoding: .utf8)
        XCTAssertFalse(raw.localizedCaseInsensitiveContains("api_key"))
        XCTAssertFalse(raw.localizedCaseInsensitiveContains("sk-"))
    }

    private func temporaryDirectory(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("WarpCLITests-\(UUID().uuidString)")
            .appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
