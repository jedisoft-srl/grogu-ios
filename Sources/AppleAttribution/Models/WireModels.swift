import Foundation

/// Record di un singolo evento, persistito in coda e serializzato sul wire.
/// Le proprietà opzionali sono omesse dal JSON quando nil (encodeIfPresent sintetizzato).
struct EventRecord: Codable, Equatable {
    let eventId: String
    let name: String          // signup | login | trial_started | subscribed | renewed | purchase
    let occurredAt: String
    var plan: PlanWire?
    var revenue: RevenueWire?
    var productId: String?    // solo per purchase
    var externalId: String?   // identificatore utente lato app (opzionale)

    enum CodingKeys: String, CodingKey {
        case eventId, name, occurredAt, plan, revenue, productId
        case externalId = "external_id"
    }

    static func make(from event: AttributionEvent, id: String, occurredAt: String,
                     externalId: String? = nil) -> EventRecord {
        switch event {
        case .signup:
            return EventRecord(eventId: id, name: "signup", occurredAt: occurredAt,
                               externalId: externalId)
        case .login:
            return EventRecord(eventId: id, name: "login", occurredAt: occurredAt,
                               externalId: externalId)
        case .trialStarted(let plan):
            return EventRecord(eventId: id, name: "trial_started", occurredAt: occurredAt,
                               plan: PlanWire(plan), externalId: externalId)
        case .subscribed(let plan, let revenue, let currency):
            return EventRecord(eventId: id, name: "subscribed", occurredAt: occurredAt,
                               plan: PlanWire(plan), revenue: RevenueWire(revenue, currency),
                               externalId: externalId)
        case .renewed(let plan, let revenue, let currency):
            return EventRecord(eventId: id, name: "renewed", occurredAt: occurredAt,
                               plan: PlanWire(plan), revenue: RevenueWire(revenue, currency),
                               externalId: externalId)
        case .purchase(let revenue, let currency, let productId):
            return EventRecord(eventId: id, name: "purchase", occurredAt: occurredAt,
                               revenue: RevenueWire(revenue, currency), productId: productId,
                               externalId: externalId)
        }
    }

    init(eventId: String, name: String, occurredAt: String,
         plan: PlanWire? = nil, revenue: RevenueWire? = nil, productId: String? = nil,
         externalId: String? = nil) {
        self.eventId = eventId
        self.name = name
        self.occurredAt = occurredAt
        self.plan = plan
        self.revenue = revenue
        self.productId = productId
        self.externalId = externalId
    }
}

struct PlanWire: Codable, Equatable {
    let period: String
    let hadTrial: Bool
    let productId: String

    init(_ plan: SubscriptionPlan) {
        self.period = plan.period.rawValue
        self.hadTrial = plan.hadTrial
        self.productId = plan.productId
    }
}

struct RevenueWire: Codable, Equatable {
    let amount: String
    let currency: String

    init(_ amount: Decimal, _ currency: String) {
        guard !amount.isNaN else { self.amount = "0"; self.currency = currency; return }
        // Normalize to remove any floating-point noise introduced when a Double
        // literal is widened to Decimal (e.g. 4.99 → 4.990000000000001024).
        let rounded = (amount as NSDecimalNumber)
            .rounding(accordingToBehavior: NSDecimalNumberHandler(
                roundingMode: .plain,
                scale: 10,
                raiseOnExactness: false,
                raiseOnOverflow: false,
                raiseOnUnderflow: false,
                raiseOnDivideByZero: false))
        // Strip trailing zeros so "9.9900000000" → "9.99".
        var s = rounded.stringValue
        if s.contains(".") {
            s = s.replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
            s = s.replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
        }
        self.amount = s
        self.currency = currency
    }
}

/// Payload di `POST /v1/attribution`.
struct AttributionPayload: Codable, Equatable {
    let installId: String
    let attributionToken: String?
    let tokenError: String?
    let device: DeviceContext
    let capturedAt: String

    enum CodingKeys: String, CodingKey {
        case installId, attributionToken, tokenError, device, capturedAt
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(installId, forKey: .installId)
        try c.encode(attributionToken, forKey: .attributionToken) // null quando nil
        try c.encode(tokenError, forKey: .tokenError)             // null quando nil
        try c.encode(device, forKey: .device)
        try c.encode(capturedAt, forKey: .capturedAt)
    }
}

/// Envelope di `POST /v1/events`.
struct EventBatch: Encodable {
    let installId: String
    let device: DeviceContext
    let sentAt: String
    let events: [EventRecord]
}
