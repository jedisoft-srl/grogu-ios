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

```swift
import AppleAttribution

// All'avvio dell'app
AppleAttribution.configure(apiKey: "jedisoft_live_xxx")

// Eventi
AppleAttribution.track(.signup)
AppleAttribution.track(.trialStarted(plan: .init(period: .monthly, hadTrial: true, productId: "pro.monthly")))
AppleAttribution.track(.subscribed(plan: .init(period: .monthly, hadTrial: true, productId: "pro.monthly"),
                                   revenue: 9.99, currency: "EUR"))
```

## Privacy
Nessun IDFA, nessun prompt ATT. Identificatore anonimo per-installazione.
Manifest privacy incluso (`PrivacyInfo.xcprivacy`).

## Requisiti
iOS 13+ (attribuzione AdServices attiva da iOS 14.3+).
