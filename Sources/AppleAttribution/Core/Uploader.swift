import Foundation

/// Costruisce le richieste, le invia e reagisce allo status secondo la matrice
/// del contratto. Le funzioni `outcome` e `backoffDelay` sono pure (testate a parte).
final class Uploader {
    enum Outcome: Equatable { case success, dropBatch, retry, stop }

    private let config: Configuration
    private let store: EventStore
    private let http: HTTPClient
    private let identity: InstallIdentity
    private let device: DeviceContext
    private let logger: Logger
    private let now: () -> Date
    private let queue: DispatchQueue
    private let stateLock = NSLock()
    private var _stopped = false
    private var stopped: Bool {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _stopped }
        set { stateLock.lock(); _stopped = newValue; stateLock.unlock() }
    }

    init(config: Configuration, store: EventStore, http: HTTPClient,
         identity: InstallIdentity, device: DeviceContext, logger: Logger,
         now: @escaping () -> Date = Date.init,
         queue: DispatchQueue = DispatchQueue(label: "it.jedisoft.attribution.uploader", qos: .utility)) {
        self.config = config
        self.store = store
        self.http = http
        self.identity = identity
        self.device = device
        self.logger = logger
        self.now = now
        self.queue = queue
    }

    // MARK: - Pure helpers

    static func outcome(forStatus status: Int) -> Outcome {
        switch status {
        case 200..<300: return .success
        case 400, 413:  return .dropBatch
        case 401:       return .stop
        default:        return .retry      // 429, 5xx, status sconosciuti
        }
    }

    /// Backoff esponenziale base 2s, cap 300s (5 min). Il jitter è applicato dal chiamante.
    static func backoffDelay(attempt: Int) -> TimeInterval {
        min(300, 2 * pow(2, Double(attempt)))
    }

    // MARK: - Flush

    func flush() { queue.async { guard !self.stopped else { return }; self.sendAttribution(); self.sendEvents() } }

    /// Variante sincrona per i test (il MockHTTPClient completa inline).
    func flushSync() { guard !stopped else { return }; sendAttribution(); sendEvents() }

    private func sendAttribution() {
        guard let payload = store.pendingAttribution() else { return }
        guard let request = makeRequest(path: "/v1/attribution", body: payload) else { return }
        http.post(request) { result in
            switch self.classify(result) {
            case .success:
                self.store.clearAttribution()
            case .dropBatch:
                self.store.clearAttribution()
                self.logger.log(.error, "attribution dropped (4xx)")
            case .stop:
                self.stopped = true
                self.logger.log(.error, "attribution unauthorized (401)")
            case .retry:
                break // resta per il prossimo flush
            }
        }
    }

    private func sendEvents() {
        let batch = store.peek(max: 50)
        guard !batch.isEmpty else { return }
        let envelope = EventBatch(installId: identity.installId, device: device,
                                  sentAt: ISO8601.string(now()), events: batch)
        guard let request = makeRequest(path: "/v1/events", body: envelope) else { return }
        let ids = Set(batch.map { $0.eventId })
        http.post(request) { result in
            switch self.classify(result) {
            case .success:
                self.store.remove(ids: ids)
            case .dropBatch:
                self.store.remove(ids: ids)
                self.logger.log(.error, "events dropped (4xx)")
            case .stop:
                self.stopped = true
                self.logger.log(.error, "events unauthorized (401)")
            case .retry:
                break
            }
        }
    }

    private func classify(_ result: Result<Int, Error>) -> Outcome {
        switch result {
        case .success(let status): return Self.outcome(forStatus: status)
        case .failure:             return .retry
        }
    }

    private func makeRequest<T: Encodable>(path: String, body: T) -> URLRequest? {
        guard let data = try? JSONEncoder().encode(body) else { return nil }
        var request = URLRequest(url: config.endpoint.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("AppleAttribution-iOS/\(AppleAttribution.version)",
                         forHTTPHeaderField: "User-Agent")
        return request
    }
}
