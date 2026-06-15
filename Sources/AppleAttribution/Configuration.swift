import Foundation

public struct AppleAttributionOptions {
    /// Verbosità del logging interno.
    public var logging: LogLevel
    /// Numero di eventi in coda che innesca un flush immediato.
    public var flushAt: Int
    /// Intervallo del flush periodico in foreground (secondi).
    public var flushIntervalSeconds: TimeInterval
    /// Cap della coda: oltre questo numero si droppano gli eventi più vecchi.
    public var maxQueueSize: Int

    public init(logging: LogLevel = .none,
                flushAt: Int = 20,
                flushIntervalSeconds: TimeInterval = 30,
                maxQueueSize: Int = 1000) {
        self.logging = logging
        self.flushAt = flushAt
        self.flushIntervalSeconds = flushIntervalSeconds
        self.maxQueueSize = maxQueueSize
    }

    public static var `default`: AppleAttributionOptions { .init() }
}

/// Configurazione interna risolta a partire dai parametri di `configure(...)`.
struct Configuration {
    let apiKey: String
    let endpoint: URL
    let options: AppleAttributionOptions
}
