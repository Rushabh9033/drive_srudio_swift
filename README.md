# Drive Studio

Design Home Screen drive widgets, four dashboard slots, vehicle identity, and connection sounds.

**Category:** niche widget studio (competitive with My Car Widget Maker–class apps)  
**Differentiation:** fictional brands (Aurelio, Velora, Northstar, Kinetic), unique UI, no clone assets  
**Honesty:** not a custom CarPlay OS UI — Home Screen widgets + Shortcuts automation path

## Run (Windows / Chrome)

```bash
cd D:\car-play-cursor
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --web-port=5173
# or
flutter run -d windows
```

Preview URL after Chrome launch: **http://localhost:5173**

After canvas/editor updates, **hard-refresh** the tab (Ctrl+Shift+R) or restart `flutter run` so layer drag isn’t stuck on a stale shell.

> Restart `flutter run` after `pub get` when plugins change (e.g. `in_app_purchase`).

## Wave status

- **Wave 1.5 (this repo on Windows):** Flutter product complete — editor, slots, garage, sounds, premium gate, App Group JSON, persistence, store listing draft. See `COMPLETE_V1.md` (~93%).
- **Wave 2 (Mac only):** WidgetKit + StoreKit device proof. Exact steps: `BLOCKED_ON_MAC.md` + `README_IOS_NATIVE.md`.

iOS minimum: **15.0**

## Stack

- Flutter / Dart 3.9 · go_router · provider · shared_preferences
- image_picker · path_provider · image (client resize) · audioplayers · in_app_purchase
- google_fonts (Manrope + DM Mono) · dark Electric Blue design system

## Key docs

| File | Purpose |
|------|---------|
| `IPHONE_LIVE_DATA.md` | Physical iPhone as live source — run + what works today |
| `COMPLETE_V1.md` | Done vs Mac-only + honest % |
| `BLOCKED_ON_MAC.md` | Exact Xcode / TestFlight commands |
| `README_IOS_NATIVE.md` | WidgetKit + App Group + StoreKit narrative |
| `STORE_LISTING.md` | App Store metadata draft |
| `DOCUMENTATION.md` | Design system / product contract |