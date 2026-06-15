import Foundation

/// Seam attorno ad AdServices, così la cattura del token è mockabile nei test.
protocol AttributionTokenProviding {
    func attributionToken() throws -> String
}

#if canImport(AdServices)
import AdServices

/// Implementazione reale: ottiene il token localmente (sincrono, senza rete).
@available(iOS 14.3, macOS 11.1, *)
struct AdServicesTokenProvider: AttributionTokenProviding {
    func attributionToken() throws -> String {
        try AAAttribution.attributionToken()
    }
}
#endif
