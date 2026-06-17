import Foundation

/// Coda durevole file-backed. Le mutazioni in-memory sono protette da una coda seriale
/// veloce (`lock`); le scritture su disco avvengono in asincrono su una coda I/O dedicata
/// (`ioQueue`), così l'API pubblica non blocca mai il thread chiamante sulla rete/disco.
/// Sopravvivono a riavvii dell'app finché il backend non le acka. Best-effort: in caso di
/// kill tra mutazione e scrittura si perde al più l'ultima modifica.
final class EventStore {
    private let eventsURL: URL
    private let attributionURL: URL
    private let maxQueueSize: Int
    private let lock = DispatchQueue(label: "it.jedisoft.attribution.store", qos: .utility)
    private let ioQueue = DispatchQueue(label: "it.jedisoft.attribution.store.io", qos: .utility)

    private var events: [EventRecord]
    private var attribution: AttributionPayload?

    init(directory: URL, maxQueueSize: Int) throws {
        self.eventsURL = directory.appendingPathComponent("events.json")
        self.attributionURL = directory.appendingPathComponent("attribution.json")
        self.maxQueueSize = max(1, maxQueueSize)
        // Safe: l'oggetto non è ancora condiviso, nessun lock necessario in init.
        self.events = Self.load([EventRecord].self, from: eventsURL) ?? []
        self.attribution = Self.load(AttributionPayload.self, from: attributionURL)
    }

    var count: Int { lock.sync { events.count } }

    func append(_ record: EventRecord) {
        lock.sync {
            events.append(record)
            if events.count > maxQueueSize {
                events.removeFirst(events.count - maxQueueSize)
            }
            let snapshot = events
            ioQueue.async { Self.save(snapshot, to: self.eventsURL) }
        }
    }

    func peek(max: Int) -> [EventRecord] {
        lock.sync { Array(events.prefix(max)) }
    }

    func remove(ids: Set<String>) {
        lock.sync {
            events.removeAll { ids.contains($0.eventId) }
            let snapshot = events
            ioQueue.async { Self.save(snapshot, to: self.eventsURL) }
        }
    }

    func saveAttribution(_ payload: AttributionPayload) {
        lock.sync {
            attribution = payload
            ioQueue.async { Self.save(payload, to: self.attributionURL) }
        }
    }

    func pendingAttribution() -> AttributionPayload? { lock.sync { attribution } }

    func clearAttribution() {
        lock.sync {
            attribution = nil
            ioQueue.async { try? FileManager.default.removeItem(at: self.attributionURL) }
        }
    }

    /// Solo per i test: attende il completamento delle scritture su disco in coda.
    func flushPendingWritesForTesting() { ioQueue.sync {} }

    // MARK: - Persistence

    private static func save<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
