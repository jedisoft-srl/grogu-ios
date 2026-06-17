import XCTest
@testable import AppleAttribution

final class DeviceContextTests: XCTestCase {
    func test_iso8601_roundTripsUTC() {
        let date = Date(timeIntervalSince1970: 1_733_306_400) // 2024-12-04T10:00:00Z
        XCTAssertEqual(ISO8601.string(date), "2024-12-04T10:00:00Z")
    }

    func test_current_populatesMandatoryFields() {
        let ctx = DeviceContext.current()
        XCTAssertEqual(ctx.sdkVersion, AppleAttribution.version)
        XCTAssertFalse(ctx.os.isEmpty)
        XCTAssertFalse(ctx.osVersion.isEmpty)
    }

    func test_deviceContext_isCodableRoundTrip() throws {
        let ctx = DeviceContext(bundleId: "it.jedisoft.app", appVersion: "1.4.2",
                                sdkVersion: "0.1.0", os: "iOS", osVersion: "17.5",
                                locale: "it_IT", region: "IT")
        let data = try JSONEncoder().encode(ctx)
        let decoded = try JSONDecoder().decode(DeviceContext.self, from: data)
        XCTAssertEqual(ctx, decoded)
    }
}
