import Foundation

/// API pubblica dell'SDK. Configurare una volta all'avvio dell'app; poi chiamare `track`.
public enum AppleAttribution {
    public static let version = "0.1.1"

    private static let lock = NSLock()
    private static var client: AttributionClient?

    /// Inizializza l'SDK. Idempotente: chiamate successive sono ignorate.
    /// L'attribuzione viene catturata automaticamente.
    public static func configure(apiKey: String,
                                 endpoint: URL = URL(string: "https://collect.grogu.jedisoft.it")!,
                                 options: AppleAttributionOptions = .default) {
        lock.lock()
        guard client == nil else { lock.unlock(); return }
        let config = Configuration(apiKey: apiKey, endpoint: endpoint, options: options)
        do {
            let newClient = try AttributionClient.live(config: config)
            client = newClient
            lock.unlock()
            newClient.start()
        } catch {
            lock.unlock()
            Logger(level: options.logging).log(.error, "configure failed: \(error)")
        }
    }

    /// Registra un evento predefinito. No-op se `configure` non è stato chiamato.
    /// - Parameter externalId: identificatore utente lato app (opzionale), serializzato come `external_id`.
    public static func track(_ event: AttributionEvent, externalId: String? = nil) {
        lock.lock(); let c = client; lock.unlock()
        c?.track(event, externalId: externalId)
    }

    /// Solo per i test: azzera lo stato della facade.
    static func reset() {
        lock.lock(); client = nil; lock.unlock()
    }
}
