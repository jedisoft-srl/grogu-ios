# AppleAttribution (iOS SDK)

SDK Jedisoft per l'attribuzione Apple Search Ads a livello di keyword. Cattura il token
AdServices all'install e gli eventi predefiniti, li accoda in modo durevole e li invia
al backend per lo scambio del token e l'aggregazione.

## Installazione

### Swift Package Manager
In Xcode: *File ▸ Add Package Dependencies…* oppure nel `Package.swift`:
```swift
.package(url: "https://github.com/jedisoft-srl/grogu-ios.git", from: "0.3.0")
```

## Uso

### Configurazione base

Configura l'SDK una sola volta all'avvio dell'app. La chiamata è idempotente:
eventuali chiamate successive vengono ignorate.

```swift
import AppleAttribution

AppleAttribution.configure(apiKey: "jedisoft_live_xxx")
```

Esempio con SwiftUI:

```swift
import SwiftUI
import AppleAttribution

@main
struct MyApp: App {
    init() {
        AppleAttribution.configure(apiKey: "jedisoft_live_xxx")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

Esempio con `AppDelegate`:

```swift
import UIKit
import AppleAttribution

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        AppleAttribution.configure(apiKey: "jedisoft_live_xxx")
        return true
    }
}
```

### Configurazione avanzata

Puoi cambiare endpoint, logging e comportamento della coda.

```swift
import Foundation
import AppleAttribution

let options = AppleAttributionOptions(
    logging: .info,
    flushAt: 10,
    flushIntervalSeconds: 15,
    maxQueueSize: 500
)

AppleAttribution.configure(
    apiKey: "jedisoft_live_xxx",
    endpoint: URL(string: "https://collect.grogu.jedisoft.it")!,
    options: options
)
```

Livelli di log disponibili:

```swift
AppleAttributionOptions(logging: .none)
AppleAttributionOptions(logging: .error)
AppleAttributionOptions(logging: .info)
AppleAttributionOptions(logging: .debug)
```

### Eventi supportati

Puoi chiamare `track` dopo `configure`. Se `track` viene chiamato prima della
configurazione, non fa nulla e non causa crash.

#### Signup

```swift
AppleAttribution.track(.signup)
```

#### Login

```swift
AppleAttribution.track(.login)
```

#### Trial iniziato

```swift
let plan = SubscriptionPlan(
    period: .monthly,
    hadTrial: true,
    productId: "pro.monthly"
)

AppleAttribution.track(.trialStarted(plan: plan))
```

#### Abbonamento acquistato

```swift
let plan = SubscriptionPlan(
    period: .monthly,
    hadTrial: true,
    productId: "pro.monthly"
)

AppleAttribution.track(
    .subscribed(
        plan: plan,
        revenue: 9.99,
        currency: "EUR"
    )
)
```

#### Abbonamento rinnovato

```swift
let plan = SubscriptionPlan(
    period: .annual,
    hadTrial: false,
    productId: "pro.annual"
)

AppleAttribution.track(
    .renewed(
        plan: plan,
        revenue: 79.99,
        currency: "EUR"
    )
)
```

#### Acquisto singolo

Con `productId`:

```swift
AppleAttribution.track(
    .purchase(
        revenue: 4.99,
        currency: "EUR",
        productId: "credits.100"
    )
)
```

Senza `productId`:

```swift
AppleAttribution.track(
    .purchase(
        revenue: 4.99,
        currency: "EUR",
        productId: nil
    )
)
```

### Identificatore utente (`external_id`)

Ogni chiamata a `track` accetta un parametro opzionale `externalId`: il tuo
identificatore utente lato app. Viene serializzato sul wire come `external_id`
e omesso quando `nil` (default), quindi è retrocompatibile. Serve a collegare gli
eventi attribuiti a un utente nei tuoi sistemi.

```swift
AppleAttribution.track(.signup, externalId: "user_42")

AppleAttribution.track(
    .subscribed(
        plan: SubscriptionPlan(period: .monthly, hadTrial: true, productId: "pro.monthly"),
        revenue: 9.99,
        currency: "EUR"
    ),
    externalId: "user_42"
)
```

Senza `externalId` il comportamento è invariato:

```swift
AppleAttribution.track(.signup)
```

### Periodi abbonamento

`SubscriptionPlan.Period` supporta:

```swift
SubscriptionPlan(period: .weekly, hadTrial: true, productId: "pro.weekly")
SubscriptionPlan(period: .monthly, hadTrial: true, productId: "pro.monthly")
SubscriptionPlan(period: .annual, hadTrial: false, productId: "pro.annual")
```

### Esempio completo

```swift
import AppleAttribution

let monthlyPlan = SubscriptionPlan(
    period: .monthly,
    hadTrial: true,
    productId: "pro.monthly"
)

let userId = "user_42"

AppleAttribution.track(.signup, externalId: userId)
AppleAttribution.track(.trialStarted(plan: monthlyPlan), externalId: userId)
AppleAttribution.track(.subscribed(plan: monthlyPlan, revenue: 9.99, currency: "EUR"), externalId: userId)
```

### Attribuzione degli eventi server-side (rinnovi, conversioni trial→pagante)

I rinnovi e la conversione trial→abbonato avvengono lato Apple **ad app chiusa**:
l'SDK non li vede. Per attribuirli, passa l'`installId` dell'SDK come
`appAccountToken` dell'acquisto StoreKit 2 — Apple lo rieccheggia nelle transazioni
e nelle App Store Server Notifications, così il backend ricollega quegli eventi alla
stessa installazione (e quindi a campagna/keyword).

```swift
import StoreKit
import AppleAttribution

func buy(_ product: Product) async throws {
    var options: Set<Product.PurchaseOption> = []
    if let id = AppleAttribution.installId, let token = UUID(uuidString: id) {
        options.insert(.appAccountToken(token))   // = installId (è già un UUID)
    }
    let result = try await product.purchase(options: options)
    // ... gestisci result
}
```

Impostalo all'acquisto iniziale (trial/subscribe): Apple lo eredita su **tutti i
rinnovi successivi**. `installId` è `nil` finché non chiami `configure`.

#### StoreKit 1 / SwiftyStoreKit (niente `appAccountToken`)

`appAccountToken` esiste **solo in StoreKit 2**. Se usi **StoreKit 1** (es.
**SwiftyStoreKit**) quel campo non c'è — e `SKPayment.applicationUsername` **non**
viene rieccheggiato nelle notifiche server-side, quindi non serve come chiave di join.

In questo caso passa l'`originalTransactionId` (chiave di join **B**): l'SDK lo invia
con l'evento d'acquisto, il backend lo mappa all'installazione e, quando arriva l'App
Store Server Notification, ricollega rinnovo/conversione alla stessa installazione (e
quindi a campagna/keyword).

```swift
import SwiftyStoreKit
import AppleAttribution

SwiftyStoreKit.purchaseProduct("pro.monthly", quantity: 1, atomically: true) { result in
    if case .success(let purchase) = result {
        // Al primo acquisto del prodotto transactionIdentifier È l'originalTransactionId.
        let txId = purchase.transaction.transactionIdentifier
        AppleAttribution.track(
            .subscribed(plan: .init(period: .monthly, hadTrial: true, productId: "pro.monthly"),
                        revenue: 9.99, currency: "EUR"),
            transaction: .init(originalTransactionId: txId, transactionId: txId))
    }
}
```

`purchase.transaction` (protocollo `PaymentTransaction`) espone solo
`transactionIdentifier`: al **primo** acquisto coincide con l'`originalTransactionId`.
Per ottenerlo in modo robusto anche su restore/rinnovi, leggilo dal receipt verificato
(`SwiftyStoreKit.verifySubscription` → `ReceiptItem.originalTransactionId`) e passalo
allo stesso modo. Imposta `transaction` almeno su `trialStarted`/`subscribed` (la
primissima transazione): tanto basta a fissare la mappa per tutti i rinnovi futuri.

Quando migrerai il client a StoreKit 2 potrai passare a `appAccountToken` (chiave A):
il backend supporta **entrambe** le chiavi, nessun cambiamento lato server necessario.

## Privacy
Nessun IDFA, nessun prompt ATT. Identificatore anonimo per-installazione.
Manifest privacy incluso (`PrivacyInfo.xcprivacy`, `NSPrivacyTracking = false`).

### `appAccountToken` e conformità (leggere prima di integrare)
Usare `installId` come `appAccountToken` (vedi sopra) **non viola le regole App Store
e non richiede prompt utente**:
- `appAccountToken` è pensato proprio per mappare la transazione a un account del *tuo*
  sistema; l'unico vincolo è che sia un **UUID senza PII** — `installId` lo è.
- **Niente ATT**: l'attribuzione usa AdServices (esente ATT by design) e l'`installId`
  è anonimo, first-party, non condiviso con terzi. Collegare i *tuoi* acquisti alla
  *tua* attribuzione non è "tracking" ai fini ATT (`NSPrivacyTracking` resta `false`).

Restano però obblighi di **trasparenza** (non di consenso), a carico dell'app che integra:
- dichiarare in **App Store Connect → App Privacy** la raccolta di Purchase History /
  Product Interaction / Identifier (l'SDK fornisce il suo manifest; le label dell'app
  finale le compili tu);
- coprire attribuzione + dati d'acquisto nella **privacy policy**;
- ⚠️ i dati sono dichiarati "non linked to identity": se la tua app raccoglie anche
  account/email e il backend può fare join, potrebbe diventare "linked" → rivaluta le label.

⚠️ **GDPR/ePrivacy (UE)** è un tema legale **separato** dalle policy Apple: un
identificatore persistente + dati d'acquisto possono essere dati personali, con base
giuridica (legittimo interesse vs **consenso**) che dipende dalla giurisdizione. Da
verificare col proprio legale.

## Requisiti
iOS 13+ (attribuzione AdServices attiva da iOS 14.3+).
