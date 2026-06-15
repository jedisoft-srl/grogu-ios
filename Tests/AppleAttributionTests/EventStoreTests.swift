import XCTest
@testable import AppleAttribution

final class EventStoreTests: XCTestCase {
    private func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func record(_ id: String) -> EventRecord {
        EventRecord(eventId: id, name: "signup", occurredAt: "2026-06-04T10:00:00Z")
    }

    func test_appendPeekRemove() throws {
        let store = try EventStore(directory: tempDir(), maxQueueSize: 100)
        store.append(record("A"))
        store.append(record("B"))
        XCTAssertEqual(store.count, 2)
        XCTAssertEqual(store.peek(max: 10).map(\.eventId), ["A", "B"])
        store.remove(ids: ["A"])
        XCTAssertEqual(store.peek(max: 10).map(\.eventId), ["B"])
    }

    func test_persistsAcrossInstances() throws {
        let dir = tempDir()
        let s1 = try EventStore(directory: dir, maxQueueSize: 100)
        s1.append(record("A"))
        s1.flushPendingWritesForTesting()
        let s2 = try EventStore(directory: dir, maxQueueSize: 100)
        XCTAssertEqual(s2.peek(max: 10).map(\.eventId), ["A"])
    }

    func test_capDropsOldest() throws {
        let store = try EventStore(directory: tempDir(), maxQueueSize: 2)
        store.append(record("A"))
        store.append(record("B"))
        store.append(record("C")) // supera il cap → droppa il più vecchio
        XCTAssertEqual(store.peek(max: 10).map(\.eventId), ["B", "C"])
    }

    func test_attributionSavePeekClear() throws {
        let dir = tempDir()
        let store = try EventStore(directory: dir, maxQueueSize: 100)
        XCTAssertNil(store.pendingAttribution())
        let payload = AttributionPayload(installId: "I1", attributionToken: "T", tokenError: nil,
            device: DeviceContext.current(), capturedAt: "2026-06-04T10:00:00Z")
        store.saveAttribution(payload)
        XCTAssertEqual(store.pendingAttribution()?.installId, "I1")
        store.flushPendingWritesForTesting()
        // persiste su nuova istanza
        XCTAssertEqual(try EventStore(directory: dir, maxQueueSize: 100).pendingAttribution()?.installId, "I1")
        store.clearAttribution()
        XCTAssertNil(store.pendingAttribution())
    }

    func test_corruptJsonRecoversToEmpty() throws {
        let dir = tempDir()
        try Data("{ not valid json".utf8).write(to: dir.appendingPathComponent("events.json"))
        let store = try EventStore(directory: dir, maxQueueSize: 100)
        XCTAssertEqual(store.count, 0) // load best-effort → coda vuota, nessun crash
    }
}
