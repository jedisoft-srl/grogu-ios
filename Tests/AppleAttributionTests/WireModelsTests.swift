import XCTest
@testable import AppleAttribution

final class WireModelsTests: XCTestCase {
    private func json(_ record: EventRecord) throws -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return String(data: try enc.encode(record), encoding: .utf8)!
    }

    func test_signup_mapsToMinimalRecord() throws {
        let r = EventRecord.make(from: .signup, id: "E1", occurredAt: "2026-06-04T10:00:00Z")
        XCTAssertEqual(try json(r),
            #"{"eventId":"E1","name":"signup","occurredAt":"2026-06-04T10:00:00Z"}"#)
    }

    func test_subscribed_carriesPlanAndRevenue() throws {
        let plan = SubscriptionPlan(period: .monthly, hadTrial: true, productId: "pro.monthly")
        let r = EventRecord.make(from: .subscribed(plan: plan, revenue: 9.99, currency: "EUR"),
                                 id: "E2", occurredAt: "2026-06-04T10:00:00Z")
        XCTAssertEqual(try json(r),
            #"{"eventId":"E2","name":"subscribed","occurredAt":"2026-06-04T10:00:00Z","plan":{"hadTrial":true,"period":"monthly","productId":"pro.monthly"},"revenue":{"amount":"9.99","currency":"EUR"}}"#)
    }

    func test_trialStarted_hasPlanNoRevenue() throws {
        let plan = SubscriptionPlan(period: .weekly, hadTrial: true, productId: "pro.weekly")
        let r = EventRecord.make(from: .trialStarted(plan: plan), id: "E3", occurredAt: "2026-06-04T10:00:00Z")
        XCTAssertEqual(try json(r),
            #"{"eventId":"E3","name":"trial_started","occurredAt":"2026-06-04T10:00:00Z","plan":{"hadTrial":true,"period":"weekly","productId":"pro.weekly"}}"#)
    }

    func test_purchase_carriesRevenueAndOptionalProductId() throws {
        let r = EventRecord.make(from: .purchase(revenue: 4.99, currency: "USD", productId: "coins_100"),
                                 id: "E4", occurredAt: "2026-06-04T10:00:00Z")
        XCTAssertEqual(try json(r),
            #"{"eventId":"E4","name":"purchase","occurredAt":"2026-06-04T10:00:00Z","productId":"coins_100","revenue":{"amount":"4.99","currency":"USD"}}"#)
    }

    func test_purchase_withoutProductId_omitsKey() throws {
        let r = EventRecord.make(from: .purchase(revenue: 1.00, currency: "EUR", productId: nil),
                                 id: "E5", occurredAt: "2026-06-04T10:00:00Z")
        XCTAssertEqual(try json(r),
            #"{"eventId":"E5","name":"purchase","occurredAt":"2026-06-04T10:00:00Z","revenue":{"amount":"1","currency":"EUR"}}"#)
    }

    func test_renewed_carriesPlanAndRevenue() throws {
        let plan = SubscriptionPlan(period: .annual, hadTrial: false, productId: "pro.annual")
        let r = EventRecord.make(from: .renewed(plan: plan, revenue: 49.99, currency: "EUR"),
                                 id: "E6", occurredAt: "2026-06-04T10:00:00Z")
        XCTAssertEqual(try json(r),
            #"{"eventId":"E6","name":"renewed","occurredAt":"2026-06-04T10:00:00Z","plan":{"hadTrial":false,"period":"annual","productId":"pro.annual"},"revenue":{"amount":"49.99","currency":"EUR"}}"#)
    }

    func test_attributionPayload_emitsNullTokenFieldsWhenAbsent() throws {
        let device = DeviceContext(bundleId: "it.jedisoft.app", appVersion: "1.0", sdkVersion: "0.1.0",
                                   os: "iOS", osVersion: "17.5", locale: "it_IT", region: "IT")
        let p = AttributionPayload(installId: "I1", attributionToken: nil, tokenError: nil,
                                   device: device, capturedAt: "2026-06-04T10:00:00Z")
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
        let json = String(data: try enc.encode(p), encoding: .utf8)!
        XCTAssertTrue(json.contains("\"attributionToken\":null"), json)
        XCTAssertTrue(json.contains("\"tokenError\":null"), json)
    }

    func test_attributionPayload_roundTripsWithToken() throws {
        let device = DeviceContext(bundleId: "b", appVersion: "1", sdkVersion: "0.1.0",
                                   os: "iOS", osVersion: "17", locale: "it", region: "IT")
        let p = AttributionPayload(installId: "I1", attributionToken: "TOK", tokenError: nil,
                                   device: device, capturedAt: "2026-06-04T10:00:00Z")
        let data = try JSONEncoder().encode(p)
        XCTAssertEqual(try JSONDecoder().decode(AttributionPayload.self, from: data), p)
    }
}
