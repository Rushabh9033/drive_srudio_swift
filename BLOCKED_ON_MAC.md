# Drive Studio — Blocked on Mac

> **Full handoff:** [`MAC_HANDOFF.md`](MAC_HANDOFF.md) (Windows done, Mac remaining, PrivacyInfo/legal/WidgetKit/StoreKit, transfer + first-session checklist).  
> **Copy/clean short list:** [`TRANSFER_CHECKLIST.md`](TRANSFER_CHECKLIST.md).

Windows Wave 1.5 / Wave 2 **prep** is done in-repo. The items below **require macOS + Xcode 15+** and cannot be verified on this machine. **Mac work is not done.**

## Exact next commands (on Mac)

```bash
cd /path/to/car-play-cursor
flutter pub get
cd ios && pod install && cd ..

# Open workspace (NOT the .xcodeproj alone)
open ios/Runner.xcworkspace
```

### Xcode (manual once)

1. **File → New → Target → Widget Extension**  
   - Name: `DriveStudioWidget`  
   - Configuration Intent: **No**  
   - Embed in: **Runner**
2. Replace generated Swift with `ios/DriveStudioWidget/DriveStudioWidget.swift`  
   Match `ios/DriveStudioWidget/Info.plist`; add `PrivacyInfo.xcprivacy` to the extension
3. Add to **Runner** target:  
   - `ios/Runner/AppGroup/AppGroupContract.swift`  
   - `ios/Runner/AppGroup/AppGroupChannel.swift`
4. **Signing & Capabilities** on **Runner** + **DriveStudioWidget**:  
   - App Groups → `group.com.drivestudio.shared`
5. In `AppDelegate.swift`, after `GeneratedPluginRegistrant`, register the channel:

```swift
if let controller = window?.rootViewController as? FlutterViewController {
  AppGroupChannel.register(with: controller.binaryMessenger)
}
```

(Or use `flutterViewController` accessor for your Flutter embedding version.)

6. App Store Connect → IAP non-consumable **`drive_studio_premium`**  
   Add StoreKit Configuration file for local sandbox testing.
7. Deployment target **iOS 15.0+** on Runner + extension.

### Build & run

```bash
flutter build ios --release
# or device debug:
flutter run -d <ios-device-id>
```

### Device verification checklist

- [ ] Purchase / restore Premium via StoreKit sandbox  
- [ ] Assign drafts to slots 1–4 in Flutter  
- [ ] Home Screen → Add Widget → Drive Studio Slot N shows title + clock from JSON  
- [ ] Edit draft → widget refreshes after App Group write + `reloadAllTimelines`  
- [ ] Shortcuts automation opens / cues as documented in Setup guide  
- [ ] TestFlight internal build  
- [ ] HTTPS host for `docs/legal/` privacy + support URLs  

## Already prepared (no Mac needed to author)

| Artifact | Path |
|----------|------|
| WidgetKit stub (4 slots, summary + clock) | `ios/DriveStudioWidget/` |
| App Group contract + channel | `ios/Runner/AppGroup/` |
| Privacy manifests | `ios/Runner/PrivacyInfo.xcprivacy`, `ios/DriveStudioWidget/PrivacyInfo.xcprivacy` |
| Flutter JSON exporter + MethodChannel | `lib/data/store/app_group_export.dart` |
| PurchaseService + `in_app_purchase` | `lib/data/purchase/purchase_service.dart` |
| Store listing / privacy draft | `STORE_LISTING.md` |
| Legal HTML | `docs/legal/` |
| Native setup narrative | `README_IOS_NATIVE.md` |
| Full Mac handoff | **`MAC_HANDOFF.md`** |

## Do not claim until Mac verification

- Live Home Screen widgets on device  
- Real StoreKit transactions  
- TestFlight / App Review submission  
- Native CarPlay dashboard UI (Apple does not allow — not in scope)

## Windows status

**Windows 100%.** All Flutter / web / Windows tooling for Drive Studio is finished on the Windows host. See **`WINDOWS_DONE.md`**. GPS speed is wired in Dart for iPhone/Android with in-app Location pre-prompt; web/Windows preview stays honest Unavailable. Deep links (`drivestudio://`) are handled in go_router.
