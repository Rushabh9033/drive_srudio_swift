# Drive Studio — Mac handoff (authoritative)

**Host that authored this:** Windows (2026-08-03)  
**Product:** Drive Studio (`drive_studio`) — Home Screen drive widgets, slots, sounds  
**Overall Complete V1:** ~**96%** — Windows Flutter column **100%**; remaining ~**4%** is **Mac/device only**  
**Do not claim:** Live WidgetKit, real StoreKit transactions, TestFlight, or App Store submit-ready until verified on Mac + device

> **Start here on Mac.** Companion short list: [`TRANSFER_CHECKLIST.md`](TRANSFER_CHECKLIST.md).  
> Legacy pointer: [`BLOCKED_ON_MAC.md`](BLOCKED_ON_MAC.md) → this file.

---

## 0. Read order (zero confusion)

| Order | Doc | Why |
|------:|-----|-----|
| 1 | **This file** (`MAC_HANDOFF.md`) | Full Windows→Mac map + first session |
| 2 | [`TRANSFER_CHECKLIST.md`](TRANSFER_CHECKLIST.md) | What to copy / skip / regenerate |
| 3 | [`WINDOWS_DONE.md`](WINDOWS_DONE.md) | What Windows finished (100%) |
| 4 | [`COMPLETE_V1.md`](COMPLETE_V1.md) | Honest % matrix + App Group contract |
| 5 | [`README_IOS_NATIVE.md`](README_IOS_NATIVE.md) | WidgetKit / App Group / StoreKit narrative |
| 6 | [`IPHONE_LIVE_DATA.md`](IPHONE_LIVE_DATA.md) | What is live on iPhone vs preview |
| 7 | [`STORE_LISTING.md`](STORE_LISTING.md) | Connect metadata, PrivacyInfo, URLs |
| 8 | [`APPLE_4_3_POSITIONING.md`](APPLE_4_3_POSITIONING.md) | Review framing (not CarPlay shell) |
| 9 | [`docs/legal/README.md`](docs/legal/README.md) | Host privacy/support before Connect |
| 10 | [`REMBG_IPHONE.md`](REMBG_IPHONE.md) | On-device Remove BG; rembg = tools only |

---

## 1. Everything done on Windows (do not re-do)

### Product / Flutter

- [x] Production screens: Home, Studio, Editor, Garage, Sounds, Slots, Settings, Setup, Intro
- [x] Widget studio compositor: drag / resize / snap / undo-redo / copy-paste-duplicate / dirty exit
- [x] Four slots + drafts CRUD + clipboard Export / Import backup
- [x] Garage: fictional marques + bundled vehicle PNGs + custom user upload
- [x] Sounds: 17 bundled WAVs + synth fallback; premium gated
- [x] Premium gate: `PurchaseService` + `isPremium` (IAP path selected on iOS; debug unlock is **web/Windows only**)
- [x] User photos only (Gallery / Camera) — **no stock OEM car photo library**
- [x] Remove BG: **on-device ONNX only** (`image_background_remover`); rembg `:8787` is **tools CLI**, not in editor
- [x] Speedometers: 18 stock + compose Add widget
- [x] Live sensors (Dart): battery / charging / network / **GPS speed** via `geolocator` for **iPhone/Android**
- [x] Permission UX: in-app pre-prompt → system dialog → Settings deep-link (Photos, Camera, Location When In Use)
- [x] Deep links: `drivestudio://sounds|setup|home` via go_router; web `?dl=`; Info.plist URL scheme + `FlutterDeepLinkingEnabled`
- [x] Light haptics stubs (`DriveHaptics`)
- [x] Settings copy honest (preview live toggle; rembg card on-device only)
- [x] Legal copy routes: Settings → Privacy / Terms (`docs/legal/` + in-app)
- [x] Quality: `flutter analyze` + focused tests on Windows

### iOS / Mac **authored in-repo** (not linked / not device-proven)

| Artifact | Path | Status on Windows |
|----------|------|-------------------|
| WidgetKit stub (4 slots, summary + clock) | `ios/DriveStudioWidget/DriveStudioWidget.swift` | Source present; **not** an Xcode target yet |
| Widget extension Info.plist | `ios/DriveStudioWidget/Info.plist` | Ready to match when target created |
| Widget Privacy Manifest | `ios/DriveStudioWidget/PrivacyInfo.xcprivacy` | Ready; attach when extension linked |
| App Group contract | `ios/Runner/AppGroup/AppGroupContract.swift` | Source present; **not** in Runner target yet |
| App Group MethodChannel | `ios/Runner/AppGroup/AppGroupChannel.swift` | Source present; register in AppDelegate on Mac |
| Runner Privacy Manifest | `ios/Runner/PrivacyInfo.xcprivacy` | **In** pbxproj Resources |
| Usage strings + URL scheme | `ios/Runner/Info.plist` | Photos / Camera / Location / `drivestudio` |
| Min iOS | `15.0` in Info.plist / Podfile intent | Confirm on both Runner + extension |
| Flutter App Group exporter | `lib/data/store/app_group_export.dart` | Writes/mirrors JSON; channel call on iOS |
| IAP service | `lib/data/purchase/purchase_service.dart` | `in_app_purchase` on iOS |
| AppDelegate register stub | `ios/Runner/AppDelegate.swift` | **Commented** Wave-2 instructions only |
| Legal HTML | `docs/legal/privacy.html`, `support.html`, `terms.html` | Files ready; **HTTPS host pending** |
| Store + 4.3 docs | `STORE_LISTING.md`, `APPLE_4_3_POSITIONING.md` | Drafts ready |

### Locked contracts (do not rename casually)

| Contract | Value |
|----------|--------|
| App Group suite | `group.com.drivestudio.shared` |
| App Group key | `widget_state_v1` |
| MethodChannel | `drive_studio/app_group` (`syncState`, `reloadWidgets`) |
| IAP product | `drive_studio_premium` (non-consumable) |
| Suggested bundle ID | `com.drivestudio.app` (confirm in Xcode / Apple Developer) |
| URL scheme | `drivestudio` |
| Deep links | `drivestudio://sounds`, `drivestudio://setup`, `drivestudio://home` |

Schema details: `lib/data/store/app_group_export.dart` + `README_IOS_NATIVE.md`. Payload includes per-slot `summary` + `telemetry` (battery + speed when known).

### Explicitly **not** done / not claimed on Windows

- WidgetKit extension **linked** in Xcode / on Home Screen
- App Groups capability enabled on signing
- `AppGroupChannel.register` live in AppDelegate
- StoreKit sandbox purchase / Restore on device
- TestFlight build
- Live HTTPS for privacy/support URLs
- Custom CarPlay dashboard UI (**out of scope** — Apple forbids; never claim)

---

## 2. Everything remaining on Mac (Wave 2)

### A. Environment (first boot)

1. macOS + **Xcode 15+** + CocoaPods
2. Flutter **stable** (`flutter doctor` clean for iOS)
3. Apple Developer account; App ID with **App Groups**
4. Physical iPhone: Developer Mode ON; trust Mac
5. Optional: create App Store Connect app + IAP product before sandbox testing

### B. Bootstrap after copy

```bash
cd /path/to/car-play-cursor
flutter pub get
cd ios && pod install && cd ..
flutter analyze
flutter test
open ios/Runner.xcworkspace   # NOT Runner.xcodeproj alone
```

### C. Xcode — WidgetKit target (manual once)

`DriveStudioWidget` is **source-only**. `project.pbxproj` currently has **Runner** (+ RunnerTests) only — you must create the extension target:

1. **File → New → Target → Widget Extension**
   - Name: `DriveStudioWidget`
   - Configuration Intent: **No**
   - Embed in: **Runner**
2. Replace generated Swift with `ios/DriveStudioWidget/DriveStudioWidget.swift`
3. Match `ios/DriveStudioWidget/Info.plist`; add `ios/DriveStudioWidget/PrivacyInfo.xcprivacy` to the extension target Resources
4. Deployment target **iOS 15.0+** on Runner **and** extension  
   (On-device Remove BG needs **iOS 16+** runtime; app min stays 15 — degrade gracefully)

### D. Xcode — App Group bridge

1. Add to **Runner** target:
   - `ios/Runner/AppGroup/AppGroupContract.swift`
   - `ios/Runner/AppGroup/AppGroupChannel.swift`
2. **Signing & Capabilities** on **Runner** + **DriveStudioWidget**:
   - App Groups → `group.com.drivestudio.shared`
3. In `AppDelegate.swift`, after `GeneratedPluginRegistrant`, **uncomment / wire**:

```swift
if let controller = window?.rootViewController as? FlutterViewController {
  AppGroupChannel.register(with: controller.binaryMessenger)
}
```

(Adjust for your Flutter embedding if `window` accessor differs — see comment in file.)

### E. StoreKit 2

1. App Store Connect → Non-Consumable **`drive_studio_premium`**
2. Add a StoreKit Configuration file for local sandbox
3. On device: purchase + Restore; confirm premium templates/sounds unlock
4. Debug Premium unlock must **never** appear on the iOS StoreKit path (web/Windows only)

### F. Device verification

```bash
flutter devices
flutter run -d <iphone-id>
# later:
flutter build ios --release
```

Checklist:

- [ ] Photos / Camera / Location pre-prompt → system dialog → denied → Settings link
- [ ] Live battery % on Home; GPS speed digits after Location grant (else **— / Unavailable**)
- [ ] Assign drafts to slots 1–4
- [ ] Home Screen → Add Widget → Drive Studio Slot N shows title + clock from App Group JSON
- [ ] Edit draft → App Group write + `reloadAllTimelines` refreshes widget
- [ ] Purchase / restore Premium (sandbox)
- [ ] Shortcuts / Setup guide cues as documented
- [ ] Deep link from Shortcuts: `drivestudio://setup` / `drivestudio://sounds`
- [ ] TestFlight internal build
- [ ] Screenshots on real device (see `STORE_LISTING.md`) — **no fake CarPlay UI**

### G. Legal / Connect before submit

1. Host `docs/legal/*.html` on **HTTPS** (`docs/legal/README.md`)
2. Point Connect Privacy / Support URLs (draft: `https://drivestudio.app/privacy` etc.)
3. Replace placeholder emails with real inboxes
4. Keep HTML aligned with `lib/core/legal/legal_copy.dart`

### H. Optional later (not blocking Wave 2 proof)

- Rich SwiftUI painting of full `spec` layers (stub uses `summary` today)
- Crash reporting (only with consent + PrivacyInfo update)

---

## 3. Permissions, PrivacyInfo, legal, WidgetKit, StoreKit, App Groups, TestFlight, guidelines

### Permissions (Info.plist — already present)

| Key | Purpose |
|-----|---------|
| `NSPhotoLibraryUsageDescription` | Custom vehicle / layer artwork |
| `NSPhotoLibraryAddUsageDescription` | Save edited previews on export |
| `NSCameraUsageDescription` | Photograph car for artwork |
| `NSLocationWhenInUseUsageDescription` | GPS speed while app open; never invent speed |
| ATT / Bluetooth / Mic | **Not** declared — V1 has no tracking/BT scan |

Flutter UX: `permission_handler` + `geolocator` pre-prompts before system dialogs. Verify on device (Windows web cannot prove OS sheets).

### PrivacyInfo.xcprivacy

| File | Tracking | API reasons |
|------|----------|-------------|
| `ios/Runner/PrivacyInfo.xcprivacy` | `false`, empty domains/types | UserDefaults **CA92.1**, File timestamp **C617.1** |
| `ios/DriveStudioWidget/PrivacyInfo.xcprivacy` | `false` | UserDefaults **CA92.1** |

Runner manifest is already in Xcode Resources. Attach widget manifest when the extension target exists.

### Legal pages

| Repo | Host before Connect |
|------|---------------------|
| `docs/legal/privacy.html` | `https://drivestudio.app/privacy` |
| `docs/legal/support.html` | `https://drivestudio.app/support` |
| `docs/legal/terms.html` | `https://drivestudio.app/terms` (optional) |

In-app Settings mirrors offline. **Hosting is still Mac/ops work** — files are ready; domain is not claimed live.

### WidgetKit

- Stub: 4 slot widgets reading App Group JSON
- **Not device-proven** until target + App Groups + channel registration

### StoreKit

- Product ID locked: `drive_studio_premium`
- Dart IAP wired; **sandbox pending Mac**

### App Groups

- Suite / key locked (table above)
- Flutter exporter hardened (summary, size trim, validate)
- Native write path needs channel registration on Mac

### TestFlight

- Blocked until signed iOS build with WidgetKit (+ preferably StoreKit) verified

### Guidelines / 4.3 status

| Topic | Status |
|-------|--------|
| Custom CarPlay UI shell | **Out of scope** — never ship / never screenshot |
| Positioning | `APPLE_4_3_POSITIONING.md` — compositor-first, fictional marques, honest widgets + Shortcuts |
| Pre-submit 4.3 risk | **LOW–MED** if metadata/screenshots stay honest |
| Listing draft | `STORE_LISTING.md` — not live |
| Submit-ready | **No** until Mac verification + HTTPS legal URLs |

---

## 4. Preview / commands — Windows vs Mac

| Task | Windows (done / preview) | Mac (device truth) |
|------|--------------------------|--------------------|
| Flutter deps | `flutter pub get` | Same |
| Analyze / test | `flutter analyze` / `flutter test` | Same first |
| UI preview | `flutter run -d web-server --web-port=5173 --web-hostname=localhost` → http://localhost:5173 | Prefer **physical iPhone** |
| Desktop | `flutter run -d windows` | `flutter run -d macos` only if you add macOS target (not required for iOS ship) |
| GPS / battery / permissions | Honest **Unavailable** / limited on web-Windows | Real OS dialogs + live sensors |
| Remove BG | Desktop ONNX where supported; web snackbar unsupported | iOS **16+** on-device ONNX |
| rembg `:8787` | Optional tools CLI only | Same — **not** product path |
| iOS pods | N/A | `cd ios && pod install` |
| Open native | N/A | `open ios/Runner.xcworkspace` |
| Device run | N/A | `flutter run -d <iphone-id>` |
| Release | N/A | `flutter build ios --release` → Archive / TestFlight |
| After `pub get` / plugins | **Restart** `flutter run` (hot reload insufficient) | Same |
| Deep link soft tip (web) | `?dl=setup` | Use `drivestudio://setup` from Shortcuts |

Windows preview command (reference only):

```powershell
cd D:\car-play-cursor
flutter pub get
flutter run -d web-server --web-port=5173 --web-hostname=localhost
```

Mac first commands:

```bash
cd /path/to/car-play-cursor
flutter pub get
cd ios && pod install && cd ..
flutter devices
flutter run -d <iphone-id>
```

---

## 5. What is already prepared for iOS/Mac in-repo

```
ios/
  DriveStudioWidget/          # WidgetKit Swift + Info.plist + PrivacyInfo (source)
  Runner/
    AppGroup/                 # Contract + MethodChannel (source; add to target on Mac)
    PrivacyInfo.xcprivacy     # In pbxproj
    Info.plist                # Usage strings + drivestudio URL scheme
    AppDelegate.swift         # Register channel (commented instructions)
  Podfile                     # CocoaPods
lib/data/store/app_group_export.dart
lib/data/purchase/purchase_service.dart
docs/legal/                   # privacy / support / terms HTML
STORE_LISTING.md
APPLE_4_3_POSITIONING.md
README_IOS_NATIVE.md
IPHONE_LIVE_DATA.md
BLOCKED_ON_MAC.md             # pointer → this handoff
```

**Not prepared as linked Xcode targets:** Widget extension, App Group capability, channel registration, StoreKit config file, TestFlight.

---

## 6. Transfer: what to copy vs skip

### Copy / keep (required)

- `lib/`, `ios/`, `android/` (if keeping), `assets/`, `test/`
- `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`
- `docs/` (especially `docs/legal/`)
- Root docs: this file, `COMPLETE_V1.md`, `WINDOWS_DONE.md`, `STORE_LISTING.md`, etc.
- `tool/` (asset generator), `tools/rembg_server/` **source** (`main.py`, `requirements.txt`, README, Dockerfile) — **not** `.venv`
- `.gitignore`, `.metadata`, `README.md`

### Do **not** copy (regenerable / bloat)

| Path | Approx size (pre-clean) | Regenerate |
|------|-------------------------|------------|
| `tools/rembg_server/.venv/` | ~465 MB | `python -m venv .venv` + `pip install -r requirements.txt` |
| `build/` | ~325 MB | `flutter build` / `flutter run` |
| `.dart_tool/` | ~46 MB | `flutter pub get` |
| `tmp_ref_frames/` | ~14 MB | Local demo frames — not product |
| `tools/rembg_server/demo_out/` | ~2 MB | rembg demo output |
| `**/__pycache__/` | small | Python |
| `*.log` (e.g. `flutter-web-5173*.log`) | tiny | — |
| `windows/flutter/ephemeral/` | regenerable | `flutter pub get` / run on Windows |
| `ios/Pods/`, `ios/Flutter/ephemeral/` | regenerable | `pod install` / Flutter |

### Prefer zip/rsync/git without caches

If transferring via folder copy, run cleanup first (see §7) or exclude the rows above. Prefer **git clone** on Mac so ignored paths never ship.

---

## 7. Cleanup performed on Windows before handoff

Intent: remove regenerable artifacts only; **never** delete `ios/`, `lib/`, `docs/`, assets, pubspec, legal pages, or rembg **source**.

**Performed on this Windows tree (2026-08-03):**

| Removed | ~Size freed |
|---------|-------------|
| `tools/rembg_server/.venv/` | ~465 MB |
| `build/` | ~325 MB |
| `.dart_tool/` | ~46 MB |
| `tmp_ref_frames/` | ~14 MB |
| `tools/rembg_server/demo_out/` + `__pycache__/` | ~2 MB |
| `windows/flutter/ephemeral/` | regenerable |
| `flutter-web-5173*.log`, `.flutter-plugins-dependencies` | tiny |

**Result:** repo ~**904 MB → ~53 MB** (mostly `assets/`). Sources kept.

See [`TRANSFER_CHECKLIST.md`](TRANSFER_CHECKLIST.md) for the post-clean verify list.

After Mac arrival:

```bash
flutter pub get
cd ios && pod install && cd ..
```

Optional rembg tools (not required for app):

```bash
cd tools/rembg_server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

---

## 8. Checklist — first Mac session (do in order)

### Hour 0 — land the tree

- [ ] Confirm folder has `lib/`, `ios/`, `assets/`, `pubspec.yaml`, `docs/legal/`, **no** huge `.venv` / `build`
- [ ] `flutter doctor` (Xcode + CocoaPods OK)
- [ ] `flutter pub get`
- [ ] `cd ios && pod install && cd ..`
- [ ] `flutter analyze` && `flutter test`
- [ ] Skim this file §1–§2 (do not rebuild Flutter product)

### Hour 1 — Xcode wire-up

- [ ] `open ios/Runner.xcworkspace`
- [ ] Create **DriveStudioWidget** extension; replace with stub sources
- [ ] Add App Group Swift files to Runner
- [ ] Enable App Groups on Runner + extension (`group.com.drivestudio.shared`)
- [ ] Register `AppGroupChannel` in AppDelegate
- [ ] Confirm Team / bundle ID / iOS 15.0+
- [ ] Confirm Runner `PrivacyInfo.xcprivacy` still in Resources; add widget PrivacyInfo

### Hour 2 — device proof (Flutter)

- [ ] `flutter run` on physical iPhone
- [ ] Prove permissions + battery + GPS honesty
- [ ] Assign slots; confirm App Group JSON path (mirror + channel)
- [ ] Add Home Screen widgets; confirm Slot 1–4 UI
- [ ] Edit → widget refresh

### Hour 3 — IAP + flight path

- [ ] Create/connect `drive_studio_premium` + StoreKit config
- [ ] Sandbox purchase + Restore
- [ ] Archive → TestFlight internal
- [ ] Plan HTTPS host for `docs/legal/`
- [ ] Capture honest screenshots (no CarPlay shell)

### Stop conditions (do not submit)

- [ ] Widgets not on Home Screen → **HOLD**
- [ ] IAP untested → **HOLD**
- [ ] Privacy/Support URLs not HTTPS → **HOLD**
- [ ] Any CarPlay-replacement screenshot/copy → **NO-GO** (fix metadata)

---

## 9. Common pitfalls (avoid missed issues)

1. Opening **`Runner.xcodeproj`** instead of **`Runner.xcworkspace`** after pods  
2. Creating a Widget Extension but **not** replacing with `ios/DriveStudioWidget/` sources  
3. Enabling App Groups on Runner only (extension must match suite)  
4. Forgetting `AppGroupChannel.register` — Flutter writes mirror prefs but widgets never see suite  
5. Testing Premium with debug unlock habits from Windows — use **StoreKit sandbox** on iOS  
6. Claiming GPS/widgets “done” from Windows web preview  
7. Shipping or documenting rembg server as part of the App Store binary  
8. Min OS confusion: app **15+**; Remove BG practical **16+**  
9. Submitting Connect without hosted privacy/support HTML  
10. Keyword/screenshot regression into “CarPlay dashboard” clone territory  

---

## 10. Progress honesty (do not inflate)

| Slice | Status |
|-------|--------|
| Flutter product (Windows) | **100%** |
| Live sensors + permission UX (Dart) | Authored; **device dialogs pending Mac** |
| IAP abstraction | Authored; **sandbox pending** |
| WidgetKit / App Group native | ~70% authored, **0% device-proven** |
| Store listing / legal files | Draft / files ready; host + submit pending |
| **Mac work** | **Not done** |
| **App Store submit-ready** | **No** |

---

## 11. Doc index

| File | Role |
|------|------|
| `MAC_HANDOFF.md` | **This file** — full Mac transfer + Wave 2 |
| `TRANSFER_CHECKLIST.md` | Short copy/clean checklist |
| `BLOCKED_ON_MAC.md` | Short pointer + command crib |
| `WINDOWS_DONE.md` | Windows 100% checklist |
| `COMPLETE_V1.md` | Overall % + contracts |
| `README_IOS_NATIVE.md` | Native setup narrative |
| `IPHONE_LIVE_DATA.md` | Live vs preview sensors |
| `STORE_LISTING.md` | Connect + PrivacyInfo checklist |
| `APPLE_4_3_POSITIONING.md` | Review differentiation |
| `docs/legal/` | Privacy / support / terms |
| `REMBG_IPHONE.md` | On-device cutout honesty |
| `ASSETS.md` | Media pipeline |

---

*End of handoff. Mac work begins at §8. Nothing in this document means WidgetKit, StoreKit, or TestFlight is complete.*
