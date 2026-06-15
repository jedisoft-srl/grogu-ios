import XCTest
@testable import AppleAttribution

final class UploaderTests: XCTestCase {
    private func env() throws -> (EventStore, InstallIdentity, MockHTTPClient, Uploader) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = try EventStore(directory: dir, maxQueueSize: 100)
        let identity = InstallIdentity(defaults: UserDefaults(suiteName: "t." + UUID().uuidString)!,
                                       uuid: { "INSTALL-1" })
        let http = MockHTTPClient()
        let config = Configuration(apiKey: "KEY", endpoint: URL(string: "https://collect.test")!,
                                   options: .default)
        let uploader = Uploader(config: config, store: store, http: http, identity: identity,
                                device: .current(), logger: Logger(level: .none),
                                now: { Date(timeIntervalSince1970: 0) })
        return (store, identity, http, uploader)
    }

    // --- funzioni pure ---

    func test_classify_statusMapping() {
        XCTAssertEqual(Uploader.outcome(forStatus: 202), .success)
        XCTAssertEqual(Uploader.outcome(forStatus: 400), .dropBatch)
        XCTAssertEqual(Uploader.outcome(forStatus: 401), .stop)
        XCTAssertEqual(Uploader.outcome(forStatus: 429), .retry)
        XCTAssertEqual(Uploader.outcome(forStatus: 503), .retry)
    }

    func test_backoffDelay_growsAndCaps() {
        XCTAssertEqual(Uploader.backoffDelay(attempt: 0), 2, accuracy: 0.001)
        XCTAssertEqual(Uploader.backoffDelay(attempt: 1), 4, accuracy: 0.001)
        XCTAssertEqual(Uploader.backoffDelay(attempt: 8), 300, accuracy: 0.001) // cap 5 min
    }

    // --- side effects via mock ---

    func test_events_removedOnSuccess() throws {
        let (store, _, http, uploader) = try env()
        store.append(EventRecord(eventId: "E1", name: "signup", occurredAt: "2026-06-04T10:00:00Z"))
        http.stubbed = .success(202)
        uploader.flushSync()
        XCTAssertEqual(store.count, 0)
        XCTAssertEqual((http.lastBodyJSON?["installId"]) as? String, "INSTALL-1")
        XCTAssertEqual(http.requests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer KEY")
    }

    func test_events_retainedOnRetry() throws {
        let (store, _, http, uploader) = try env()
        store.append(EventRecord(eventId: "E1", name: "signup", occurredAt: "2026-06-04T10:00:00Z"))
        http.stubbed = .success(503)
        uploader.flushSync()
        XCTAssertEqual(store.count, 1) // resta in coda per il prossimo flush
    }

    func test_events_droppedOn400() throws {
        let (store, _, http, uploader) = try env()
        store.append(EventRecord(eventId: "E1", name: "signup", occurredAt: "2026-06-04T10:00:00Z"))
        http.stubbed = .success(400)
        uploader.flushSync()
        XCTAssertEqual(store.count, 0) // scartato, non ritrasmesso
    }

    func test_attribution_sentAndClearedOnSuccess() throws {
        let (store, _, http, uploader) = try env()
        store.saveAttribution(AttributionPayload(installId: "INSTALL-1", attributionToken: "T",
            tokenError: nil, device: .current(), capturedAt: "2026-06-04T10:00:00Z"))
        http.stubbed = .success(202)
        uploader.flushSync()
        XCTAssertNil(store.pendingAttribution())
        XCTAssertTrue(http.requests.contains { $0.url?.path == "/v1/attribution" })
    }

    func test_stop_haltsSubsequentFlushes() throws {
        let (store, _, http, uploader) = try env()
        store.append(EventRecord(eventId: "E1", name: "signup", occurredAt: "2026-06-04T10:00:00Z"))
        http.stubbed = .success(401)
        uploader.flushSync()                       // 401 → stop; eventi restano
        let after401 = http.requests.count
        XCTAssertEqual(store.count, 1)
        store.append(EventRecord(eventId: "E2", name: "login", occurredAt: "2026-06-04T10:00:00Z"))
        http.stubbed = .success(202)               // anche se ora il server è ok…
        uploader.flushSync()                       // …deve essere no-op: stop è sticky
        XCTAssertEqual(http.requests.count, after401)
        XCTAssertEqual(store.count, 2)
    }

    func test_drainsMoreThan50AcrossFlushes() throws {
        // Need a larger queue than the default 100 to hold all 120 events without eviction.
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = try EventStore(directory: dir, maxQueueSize: 200)
        let http = MockHTTPClient()
        let config = Configuration(apiKey: "KEY", endpoint: URL(string: "https://collect.test")!,
                                   options: .default)
        let identity = InstallIdentity(defaults: UserDefaults(suiteName: "t." + UUID().uuidString)!,
                                       uuid: { "INSTALL-1" })
        let uploader = Uploader(config: config, store: store, http: http, identity: identity,
                                device: .current(), logger: Logger(level: .none),
                                now: { Date(timeIntervalSince1970: 0) })
        for i in 0..<120 {
            store.append(EventRecord(eventId: "E\(i)", name: "signup", occurredAt: "2026-06-04T10:00:00Z"))
        }
        http.stubbed = .success(202)
        uploader.flushSync(); XCTAssertEqual(store.count, 70)
        uploader.flushSync(); XCTAssertEqual(store.count, 20)
        uploader.flushSync(); XCTAssertEqual(store.count, 0)
        var sentIds: [String] = []
        for req in http.requests where req.url?.path == "/v1/events" {
            let obj = try JSONSerialization.jsonObject(with: req.httpBody!) as! [String: Any]
            let events = obj["events"] as! [[String: Any]]
            sentIds.append(contentsOf: events.map { $0["eventId"] as! String })
        }
        XCTAssertEqual(sentIds, (0..<120).map { "E\($0)" })
    }
}
