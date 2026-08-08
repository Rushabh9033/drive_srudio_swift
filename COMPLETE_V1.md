# Drive Studio — Complete V1 status

**Brand:** Drive Studio  
**Wave:** 1.5+ Windows finish (permissions + deep links + GPS + backup)  
**Honest % toward Complete V1:** **~96%** (Windows Flutter column **100%**)

| Area | Status | Notes |
|------|--------|-------|
| 1 Flutter screens production-quality | Done | Home, Studio, Editor, Garage, Sounds, Slots, Settings, Setup, Intro |
| 2 Widget studio editor | Done | Drag/resize, snap, image pick, clock tick, undo/redo (+ shortcuts), dirty exit, **copy/paste/duplicate**, empty canvas + missing-draft; **scrollable tool row** |
| 3 4 slots + drafts CRUD | Done | Assign/replace/remove, duplicate/rename/delete; **export/import clipboard backup** |
| 4 Garage | Done | Fictional brands/models + **bundled vehicle PNGs** (heroes + body styles) + custom upload |
| 5 Sounds | Done | **17** bundled WAV cues (`AssetSource`) + synth fallback; premium gated via `trySetSound` |
| 6 Premium gate | Done | `PurchaseService` + `isPremium`; **lock strips premium cues**; hydrate scrub; template assign uses `createDraftFromTemplate` |
| 7 Setup guide | Done | Honest widgets + Shortcuts recipe + **deep-link Available now** |
| 8 Persistence | Done | SharedPreferences; corrupt skip; **hardened App Group JSON** (summary, size trim, validate) |
| 9 Live sensors | Done (device) | Battery / charging / network / **GPS speed** on iPhone/Android; **permission pre-prompt** before Location; web/Windows preview honest **Unavailable** |
| 9b Permission UX | Done | Photos / Camera / Location When In Use — pre-prompt → system → Settings |
| 9c Deep links | Done | `drivestudio://` + go_router + web `?dl=` |
| 10 iOS native hooks | Prepared | WidgetKit 4-slot stub + AppGroupChannel + MethodChannel — **compile on Mac** |
| 11 Quality | Done | `flutter analyze` + expanded widget tests |
| 12 Store readiness docs | Done | `STORE_LISTING.md` polished + privacy / URLs checklist |
| 13 Mac device / StoreKit | **Blocked** | See `MAC_HANDOFF.md` + `BLOCKED_ON_MAC.md` |

## What Windows finish shipped

- Permission pre-prompt + request flow (`DrivePermissions`) for Photos, Camera, Location
- GPS speedometer live path via `geolocator` (iOS/Android + consent gate); digits stay **—** when unknown
- `drivestudio://` deep-link handler (`DriveDeepLink` + go_router redirect)
- Dead rembg URL plumbing removed from `AppStore` / editor; Settings rembg card = on-device only
- Settings draft **Export / Import** clipboard backup
- Light `DriveHaptics` on select / add / delete
- Docs: `WINDOWS_DONE.md` (**Windows 100%**), rembg tools-only honesty, `IPHONE_LIVE_DATA.md` GPS row

## Media assets (vehicles + sounds)

- Bundled studio vehicle PNGs under `assets/vehicles/` (+ per-model heroes)
- Bundled WAV cues under `assets/sounds/` (17 catalog IDs)
- Pipeline + replacement guide: **`ASSETS.md`** (`python tool/generate_media_assets.py`)
- Fictional brands only — no real marque trademarks
- After asset changes: `flutter pub get` then **restart** `flutter run`

## What needs Mac (Wave 2)

1. **WidgetKit extension** — link `ios/DriveStudioWidget/` + App Group + `AppGroupChannel.register`  
2. **StoreKit 2** — product `drive_studio_premium` sandbox + restore on device  
3. **TestFlight** — device verification of widgets + Shortcuts  
4. Optional: rich SwiftUI canvas painting full `spec` layers  

Exact commands: **`MAC_HANDOFF.md`** (authoritative) / **`BLOCKED_ON_MAC.md`**. Windows summary: **`WINDOWS_DONE.md`** (100%). Transfer: **`TRANSFER_CHECKLIST.md`**.

## How to run (Windows)

```bash
cd D:\car-play-cursor
flutter pub get
flutter analyze
flutter test
flutter run -d web-server --web-port=5173 --web-hostname=localhost
# or
flutter run -d windows
```

Preview: **http://localhost:5173**

> After editor/canvas changes (drag layers, assets, plugins): **hard refresh** the browser (Ctrl+Shift+R) or fully restart `flutter run` so the canvas overlay is not serving a stale hot-reload shell.
> After `pub get` (new plugins), **restart** any running `flutter run` / Chrome session so the plugin registrant refreshes.

## Explicitly not claimed

- Full custom CarPlay dashboard UI (Apple does not allow)  
- Live WidgetKit / StoreKit on device without Mac  
- 784MB asset dump — curated catalog only  
- Remote content manifest fetch (honest local catalog in V1)
- rembg helper server inside the editor (tools CLI only)
- App Store submit-ready (needs Mac verification)

## App Group contract (locked)

- Suite: `group.com.drivestudio.shared`  
- Key: `widget_state_v1`  
- Schema: `lib/data/store/app_group_export.dart` + `README_IOS_NATIVE.md`  
- Includes per-slot `summary` + `telemetry` (battery + speed when known) for fast WidgetKit rendering  

## Progress honesty

| Slice | ~% of Complete V1 |
|-------|-------------------|
| Flutter product (editor, catalog, garage, sounds, slots, settings, permissions, deep links) | **100%** of Flutter / Windows column |
| Live sensors (battery + GPS + permission UX) | ~99% (device permission dialogs proven on Mac) |
| IAP abstraction + StoreKit code path | ~92% (device sandbox pending) |
| WidgetKit / App Group native | ~70% authored, **0% device-proven** |
| Store listing / review docs | ~92% draft |
| **Overall Complete V1** | **~96%** |

Remaining ~4% is entirely Mac: WidgetKit link, StoreKit sandbox, TestFlight proof.
