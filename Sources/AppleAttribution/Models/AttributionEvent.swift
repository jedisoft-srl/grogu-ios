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

/// Identificatori della transazione StoreKit, chiave di join lato server per gli
/// eventi che Apple genera ad app chiusa (rinnovi, conversioni trial→pagante) via
/// App Store Server Notifications.
///
/// Su **StoreKit 2** l'attribuzione passa per l'`appAccountToken` (= `installId`,
/// vedi `AppleAttribution.installId`) e questo è opzionale. Su **StoreKit 1 /
/// SwiftyStoreKit** l'`appAccountToken` NON esiste: passa qui l'`originalTransactionId`
/// (e se lo hai il `transactionId`) ottenuto dal callback d'acquisto / receipt, così
/// il backend mappa la transazione all'installazione (chiave di join B).
public struct PurchaseTransaction {
    /// `originalTransactionId` Apple: stabile per l'intera vita dell'abbonamento
    /// (lo stesso che ricompare nelle App Store Server Notifications). È il campo
    /// che abilita il join lato server — passalo quando puoi.
    public let originalTransactionId: String?
    /// `transactionId` della singola transazione (opzionale, diagnostico).
    public let transactionId: String?

    public init(originalTransactionId: String?, transactionId: String? = nil) {
        self.originalTransactionId = originalTransactionId
        self.transactionId = transactionId
    }
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
