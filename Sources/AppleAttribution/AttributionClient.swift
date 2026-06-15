import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Composition root: cabla le unità, cattura l'attribuzione allo start, registra
/// i trigger di flush (timer + lifecycle) e mappa gli eventi pubblici in record.
final class AttributionClient {
    private let config: Configuration
    private let store: EventStore
    private let collector: AttributionCollector
    private let uploader: Uploader
    private let device: DeviceContext
    private let logger: Logger
    private let now: () -> Date
    private var timer: DispatchSourceTimer?
    private var lifecycleObservers: [NSObjectProtocol] = []
    private let backgroundQueue = DispatchQueue(label: "eu.jedisoft.attribution.background")

    init(config: Configuration,
         identity: InstallIdentity,
         device: DeviceContext,
         store: EventStore,
         provider: AttributionTokenProviding?,
         http: HTTPClient,
         now: @escaping () -> Date = Date.init,
         uploaderQueue: DispatchQueue = DispatchQueue(label: "eu.jedisoft.attribution.uploader", qos: .utility)) {
        self.config = config
        self.store = store
        self.device = device
        self.now = now
        let logger = Logger(level: config.options.logging)
        self.logger = logger
        self.collector = AttributionCollector(provider: provider, identity: identity,
                                              store: store, logger: logger)
        self.uploader = Uploader(config: config, store: store, http: http, identity: identity,
                                 device: device, logger: logger, now: now, queue: uploaderQueue)
    }

    /// Factory di produzione: risolve store/identity/provider/http reali.
    static func live(config: Configuration) throws -> AttributionClient {
        let dir = try liveStorageDirectory()
        return AttributionClient(
            config: config,
            identity: InstallIdentity(),
            device: .current(),
            store: try EventStore(directory: dir, maxQueueSize: config.options.maxQueueSize),
            provider: liveProvider(),
            http: URLSessionHTTPClient())
    }

    func start() {
        collector.collectIfNeeded(device: device, now: now)
        uploader.flush()
        scheduleTimer()
        observeLifecycle()
    }

    func track(_ event: AttributionEvent) {
        let record = EventRecord.make(from: event, id: UUID().uuidString,
                                      occurredAt: ISO8601.string(now()))
        store.append(record)
        if store.count >= config.options.flushAt {
            uploader.flush()
        }
    }

    // MARK: - Triggers

    private func scheduleTimer() {
        let t = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        let interval = config.options.flushIntervalSeconds
        t.schedule(deadline: .now() + interval, repeating: interval)
        t.setEventHandler { [weak self] in self?.uploader.flush() }
        t.resume()
        timer = t
    }

    deinit {
        timer?.cancel()
        #if canImport(UIKit)
        lifecycleObservers.forEach { NotificationCenter.default.removeObserver($0) }
        #endif
    }

    private func observeLifecycle() {
        #if canImport(UIKit)
        let nc = NotificationCenter.default
        lifecycleObservers.append(nc.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                       object: nil, queue: nil) { [weak self] _ in self?.flushInBackground() })
        lifecycleObservers.append(nc.addObserver(forName: UIApplication.willEnterForegroundNotification,
                       object: nil, queue: nil) { [weak self] _ in self?.uploader.flush() })
        #endif
    }

    private func flushInBackground() {
        #if canImport(UIKit)
        let app = UIApplication.shared
        var taskId: UIBackgroundTaskIdentifier = .invalid
        let endOnce: () -> Void = { [backgroundQueue] in
            backgroundQueue.async {
                if taskId != .invalid { app.endBackgroundTask(taskId); taskId = .invalid }
            }
        }
        taskId = app.beginBackgroundTask(withName: "AppleAttributionFlush") { endOnce() }
        uploader.flush()
        backgroundQueue.asyncAfter(deadline: .now() + 3) { endOnce() }
        #else
        uploader.flush()
        #endif
    }

    // MARK: - Live helpers

    private static func liveStorageDirectory() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("AppleAttribution", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func liveProvider() -> AttributionTokenProviding? {
        #if canImport(AdServices)
        if #available(iOS 14.3, macOS 11.1, *) { return AdServicesTokenProvider() }
        #endif
        return nil
    }
}
