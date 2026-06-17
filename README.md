# AppleAttribution (iOS SDK)

SDK Jedisoft per l'attribuzione Apple Search Ads a livello di keyword. Cattura il token
AdServices all'install e gli eventi predefiniti, li accoda in modo durevole e li invia
al backend per lo scambio del token e l'aggregazione.

## Installazione

### Swift Package Manager
In Xcode: *File ▸ Add Package Dependencies…* oppure nel `Package.swift`:
```swift
.package(url: "https://github.com/jedisoft-srl/grogu-ios.git", from: "0.1.0")
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

## Privacy
Nessun IDFA, nessun prompt ATT. Identificatore anonimo per-installazione.
Manifest privacy incluso (`PrivacyInfo.xcprivacy`).

## Requisiti
iOS 13+ (attribuzione AdServices attiva da iOS 14.3+).
