import Foundation

/// Cattura il token di attribuzione una sola volta per installazione e lo accoda
/// come payload pronto per l'invio. Mai lancia: gli errori diventano `tokenError`.
final class AttributionCollector {
    private let provider: AttributionTokenProviding?
    private let identity: InstallIdentity
    private let store: EventStore
    private let logger: Logger

    init(provider: AttributionTokenProviding?, identity: InstallIdentity,
         store: EventStore, logger: Logger) {
        self.provider = provider
        self.identity = identity
        self.store = store
        self.logger = logger
    }

    func collectIfNeeded(device: DeviceContext, now: () -> Date) {
        guard !identity.attributionCaptured else { return }

        var token: String?
        var tokenError: String?

        if let provider = provider {
            do {
                token = try provider.attributionToken()
            } catch {
                tokenError = "failed"
                logger.log(.error, "attribution token error: \(error)")
            }
        } else {
            tokenError = "unsupported"
        }

        let payload = AttributionPayload(
            installId: identity.installId,
            attributionToken: token,
            tokenError: tokenError,
            device: device,
            capturedAt: ISO8601.string(now()))

        store.saveAttribution(payload)
        identity.markAttributionCaptured()
        logger.log(.info, "attribution captured (token: \(token != nil))")
    }
}
