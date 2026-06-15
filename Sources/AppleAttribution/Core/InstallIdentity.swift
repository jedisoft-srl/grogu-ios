import Foundation

/// Identificatore anonimo per-installazione (UUID), chiave di join tra attribuzione ed eventi.
/// Persistito in UserDefaults (non Keychain) → la reinstallazione genera un nuovo install.
final class InstallIdentity {
    private static let installIdKey = "AppleAttribution.installId"
    private static let capturedKey = "AppleAttribution.attributionCaptured"

    private let defaults: UserDefaults
    let installId: String

    init(defaults: UserDefaults = .standard, uuid: () -> String = { UUID().uuidString }) {
        self.defaults = defaults
        if let existing = defaults.string(forKey: Self.installIdKey) {
            self.installId = existing
        } else {
            let id = uuid()
            defaults.set(id, forKey: Self.installIdKey)
            self.installId = id
        }
    }

    var attributionCaptured: Bool { defaults.bool(forKey: Self.capturedKey) }

    func markAttributionCaptured() { defaults.set(true, forKey: Self.capturedKey) }
}
