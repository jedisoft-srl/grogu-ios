import Foundation

/// API pubblica dell'SDK. Configurare una volta all'avvio dell'app; poi chiamare `track`.
public enum AppleAttribution {
    public static let version = "0.2.0"

    private static let lock = NSLock()
    private static var client: AttributionClient?

    /// Identificatore anonimo per-installazione (UUID), chiave di join tra
    /// attribuzione ed eventi. È `nil` finché `configure` non è stato chiamato.
    ///
    /// Passalo come `appAccountToken` all'acquisto StoreKit 2 affinché Apple lo
    /// rieccheggi nelle transazioni e nelle App Store Server Notifications: così
    /// rinnovi e conversioni che avvengono lato Apple (app chiusa) si attribuiscono
    /// alla stessa installazione. Es.:
    /// ```swift
    /// if let id = AppleAttribution.installId, let token = UUID(uuidString: id) {
    ///     try await product.purchase(options: [.appAccountToken(token)])
    /// }
    /// ```
    public static var installId: String? {
        lock.lock(); let c = client; lock.unlock()
        return c?.installId
    }

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
