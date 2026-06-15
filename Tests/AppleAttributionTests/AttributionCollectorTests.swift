import XCTest
@testable import AppleAttribution

final class AttributionCollectorTests: XCTestCase {
    private func makeStore() throws -> EventStore {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return try EventStore(directory: dir, maxQueueSize: 100)
    }

    private func makeIdentity() -> InstallIdentity {
        let suite = "test." + UUID().uuidString
        return InstallIdentity(defaults: UserDefaults(suiteName: suite)!, uuid: { "INSTALL-1" })
    }

    func test_capturesTokenOnce() throws {
        let store = try makeStore()
        let identity = makeIdentity()
        let collector = AttributionCollector(
            provider: MockTokenProvider(result: .success("TOKEN-123")),
            identity: identity, store: store, logger: Logger(level: .none))

        collector.collectIfNeeded(device: .current(), now: { Date(timeIntervalSince1970: 0) })
        let p = store.pendingAttribution()
        XCTAssertEqual(p?.attributionToken, "TOKEN-123")
        XCTAssertNil(p?.tokenError)
        XCTAssertEqual(p?.installId, "INSTALL-1")
        XCTAssertTrue(identity.attributionCaptured)

        // seconda chiamata: no-op
        store.clearAttribution()
        collector.collectIfNeeded(device: .current(), now: { Date(timeIntervalSince1970: 0) })
        XCTAssertNil(store.pendingAttribution())
    }

    func test_recordsTokenErrorOnFailure() throws {
        let store = try makeStore()
        let collector = AttributionCollector(
            provider: MockTokenProvider(result: .failure(MockTokenProvider.ProviderError.boom)),
            identity: makeIdentity(), store: store, logger: Logger(level: .none))

        collector.collectIfNeeded(device: .current(), now: { Date(timeIntervalSince1970: 0) })
        let p = store.pendingAttribution()
        XCTAssertNil(p?.attributionToken)
        XCTAssertEqual(p?.tokenError, "failed")
    }

    func test_nilProviderRecordsUnsupported() throws {
        let store = try makeStore()
        let collector = AttributionCollector(
            provider: nil, identity: makeIdentity(), store: store, logger: Logger(level: .none))

        collector.collectIfNeeded(device: .current(), now: { Date(timeIntervalSince1970: 0) })
        XCTAssertEqual(store.pendingAttribution()?.tokenError, "unsupported")
    }
}
