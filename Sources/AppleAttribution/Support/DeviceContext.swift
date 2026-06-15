import Foundation

/// Metadati device inviati col record di attribuzione e coi batch di eventi.
/// Solo Foundation → costruibile e testabile anche su host macOS.
struct DeviceContext: Codable, Equatable {
    let bundleId: String
    let appVersion: String
    let sdkVersion: String
    let os: String
    let osVersion: String
    let locale: String
    let region: String

    static func current() -> DeviceContext {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let osVersion = "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"

        #if os(iOS)
        let osName = "iOS"
        #elseif os(macOS)
        let osName = "macOS"
        #else
        let osName = "unknown"
        #endif

        let info = Bundle.main.infoDictionary
        return DeviceContext(
            bundleId: Bundle.main.bundleIdentifier ?? "",
            appVersion: info?["CFBundleShortVersionString"] as? String ?? "",
            sdkVersion: AppleAttribution.version,
            os: osName,
            osVersion: osVersion,
            locale: Locale.current.identifier,
            region: Locale.current.regionCode ?? ""
        )
    }
}
