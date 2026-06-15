import XCTest
@testable import AppleAttribution

final class AttributionClientTests: XCTestCase {
    private func makeClient(http: MockHTTPClient, flushAt: Int) throws -> (AttributionClient, DispatchQueue) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = try EventStore(directory: dir, maxQueueSize: 100)
        let identity = InstallIdentity(defaults: UserDefaults(suiteName: "t." + UUID().uuidString)!,
                                       uuid: { "INSTALL-1" })
        var opts = AppleAttributionOptions.default
        opts.flushAt = flushAt
        let config = Configuration(apiKey: "KEY", endpoint: URL(string: "https://collect.test")!,
                                   options: opts)
        let q = DispatchQueue(label: "test.flush." + UUID().uuidString)
        let client = AttributionClient(config: config, identity: identity, device: .current(),
                                       store: store, provider: MockTokenProvider(result: .success("TOK")),
                                       http: http, now: { Date(timeIntervalSince1970: 0) },
                                       uploaderQueue: q)
        return (client, q)
    }

    func test_start_capturesAndSendsAttribution() throws {
        let http = MockHTTPClient()
        let (client, q) = try makeClient(http: http, flushAt: 20)
        client.start()
        q.sync {} // attende il flush async sulla coda iniettata
        XCTAssertTrue(http.requests.contains { $0.url?.path == "/v1/attribution" })
    }

    func test_track_flushesWhenThresholdReached() throws {
        let http = MockHTTPClient()
        let (client, q) = try makeClient(http: http, flushAt: 2)
        client.start()
        q.sync {} // drena il flush iniziale (attribuzione)
        let before = http.requests.count
        client.track(.signup)                 // 1 → sotto soglia
        client.track(.login)                  // 2 → soglia → flush eventi
        q.sync {} // attende il flush async
        let eventPosts = http.requests.filter { $0.url?.path == "/v1/events" }
        XCTAssertGreaterThanOrEqual(eventPosts.count, 1)
        XCTAssertGreaterThan(http.requests.count, before)
    }
}
