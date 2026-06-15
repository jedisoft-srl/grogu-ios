import Foundation

/// Set chiuso di eventi tracciabili. Aggiunte future = cambiamenti additivi versionati.
public enum AttributionEvent {
    case signup
    case login
    case trialStarted(plan: SubscriptionPlan)
    case subscribed(plan: SubscriptionPlan, revenue: Decimal, currency: String)
    case renewed(plan: SubscriptionPlan, revenue: Decimal, currency: String)
    case purchase(revenue: Decimal, currency: String, productId: String?)
}

/// Descrive il piano di abbonamento, così il backend segmenta le metriche per keyword
/// per (periodo × trial).
public struct SubscriptionPlan {
    public enum Period: String { case weekly, monthly, annual }

    public let period: Period
    public let hadTrial: Bool
    public let productId: String

    public init(period: Period, hadTrial: Bool, productId: String) {
        self.period = period
        self.hadTrial = hadTrial
        self.productId = productId
    }
}
