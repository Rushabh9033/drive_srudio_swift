# Drive Studio — iOS native (WidgetKit + StoreKit) setup

> **Wave 1.5 status:** Flutter product + purchase abstraction + App Group JSON + WidgetKit stubs are ready on Windows/web. WidgetKit + StoreKit **device** work requires a **Mac with Xcode 15+**. Full handoff: **`MAC_HANDOFF.md`**. Short commands: `BLOCKED_ON_MAC.md`.

## Prerequisites

- macOS + Xcode 15+
- Flutter stable, iOS deployment target **15.0+**
- Apple Developer account + App ID with App Groups capability
- Bundle ID suggestion: `com.drivestudio.app` (adjust to yours)
- App Group ID (locked): `group.com.drivestudio.shared`
- IAP product (locked): `drive_studio_premium` (non-consumable)

## 1. Open the iOS project

```bash
cd ios
pod install
open Runner.xcworkspace
```

## 2. Create WidgetKit extension target

1. File → New → Target → **Widget Extension**
2. Product Name: `DriveStudioWidget`
3. Include Configuration Intent: **No**
4. Embed in application: **Runner**
5. Replace generated Swift with `ios/DriveStudioWidget/DriveStudioWidget.swift` (4 slot widgets + summary/clock)
6. Set extension Deployment Target to **iOS 15.0**
7. Ensure `Info.plist` matches `ios/DriveStudioWidget/Info.plist`

## 3. Enable App Groups (both targets)

For **Runner** and **DriveStudioWidget**:

1. Signing & Capabilities → + Capability → **App Groups**
2. Add `group.com.drivestudio.shared`
3. Add to Runner target:
   - `ios/Runner/AppGroup/AppGroupContract.swift`
   - `ios/Runner/AppGroup/AppGroupChannel.swift`

## 4. Bridge Flutter → App Group UserDefaults

Flutter already:

1. Builds validated JSON via `buildWidgetKitSharedState` / `encodeAppGroupPayload`
2. Mirrors to SharedPreferences
3. Invokes MethodChannel `drive_studio/app_group` on iOS (`syncState`, `reloadWidgets`)

Register in AppDelegate after FlutterViewController exists:

```swift
if let controller = window?.rootViewController as? FlutterViewController {
  AppGroupChannel.register(with: controller.binaryMessenger)
}
```

Channel API:

```
MethodChannel('drive_studio/app_group')
  - syncState({ json: String }) → void
  - reloadWidgets() → void
```

Suite / key: `group.com.drivestudio.shared` / `widget_state_v1`

Payload includes per-slot `summary` (`title`, `clockFormat`, `badge`, `bgFrom`/`bgTo`) plus compacted `spec`. Large data-URL images are omitted.

## 5. Render rich specs (optional V1.1)

Stub already shows title + clock + badge from `summary`. For full layers:

1. Parse `slots[i].spec.layers`
2. Draw with SwiftUI / CoreGraphics on a square canvas
3. Respect `hidden` / `opacity` / formats

## 6. StoreKit 2 (Premium)

1. App Store Connect → Non-Consumable `drive_studio_premium`
2. StoreKit Configuration file for local testing
3. Flutter: `in_app_purchase` + `IapPurchaseService` already selected on iOS
4. Gate: `AppStore.isPremium` — templates & sounds

## 7. Info.plist usage strings

See `STORE_LISTING.md` checklist. Runner already has photo library strings; min OS 15.0.

Live phone sensors (`battery_plus`, `connectivity_plus`) need **no** Bluetooth privacy keys — iPhone car-link is a manual Settings toggle. Details: `IPHONE_LIVE_DATA.md`.

## 8. Build & verify

```bash
flutter pub get
cd ios && pod install && cd ..
flutter build ios --release
```

On device: unlock Premium → assign slots → add Slot widgets → confirm refresh after edits.

## Honest product framing (App Review)

- Drive Studio designs **Home Screen widgets** and **Shortcuts sound automations**.
- It does **not** replace CarPlay with a custom OS UI.
- Setup Guide copy states this.

## Files prepared

| Path | Purpose |
|------|---------|
| `ios/DriveStudioWidget/DriveStudioWidget.swift` | 4-slot WidgetKit stub |
| `ios/DriveStudioWidget/Info.plist` | Extension plist |
| `ios/Runner/AppGroup/AppGroupContract.swift` | Shared constants |
| `ios/Runner/AppGroup/AppGroupChannel.swift` | MethodChannel → UserDefaults + reload |
| `lib/data/store/app_group_export.dart` | JSON contract + mirror + bridge |
| `lib/data/purchase/purchase_service.dart` | IAP / debug purchase |
| `STORE_LISTING.md` | Metadata + privacy draft |
| `MAC_HANDOFF.md` | Authoritative Windows→Mac handoff |
| `BLOCKED_ON_MAC.md` | Exact Mac next steps (pointer) |
| `TRANSFER_CHECKLIST.md` | What to copy / regenerate |
| `COMPLETE_V1.md` | Done vs Mac-only |
