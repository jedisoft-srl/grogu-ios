import XCTest
@testable import AppleAttribution

final class SmokeTests: XCTestCase {
    func test_version_isExposed() {
        XCTAssertEqual(AppleAttribution.version, "0.3.0")
    }

    func test_trackBeforeConfigure_isNoOp() {
        AppleAttribution.reset()
        // Nessun configure: track non deve fare nulla né crashare.
        AppleAttribution.track(.signup)
    }
}
