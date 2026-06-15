import XCTest
@testable import AppleAttribution

final class InstallIdentityTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let suite = "test." + UUID().uuidString
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    func test_generatesAndPersistsInstallId() {
        let d = freshDefaults()
        let a = InstallIdentity(defaults: d, uuid: { "FIXED-UUID" })
        XCTAssertEqual(a.installId, "FIXED-UUID")
        // seconda istanza sullo stesso store riusa lo stesso id
        let b = InstallIdentity(defaults: d, uuid: { "DIFFERENT" })
        XCTAssertEqual(b.installId, "FIXED-UUID")
    }

    func test_attributionCapturedFlag() {
        let d = freshDefaults()
        let id = InstallIdentity(defaults: d, uuid: { "X" })
        XCTAssertFalse(id.attributionCaptured)
        id.markAttributionCaptured()
        XCTAssertTrue(id.attributionCaptured)
        // persiste tra istanze
        XCTAssertTrue(InstallIdentity(defaults: d, uuid: { "X" }).attributionCaptured)
    }
}
