# Drive Studio — Windows done

**Date:** 2026-08-03  
**Host:** Windows (Flutter web `:5173` + analyze/tests)  
**Status:** **Windows 100%** — all Flutter / web / Windows-capable work is shipped. Remaining Complete V1 gap is Mac-only.

## Checklist (Windows-complete)

- [x] Editor layer compositor (drag / resize / multi-widget Add photo + Add widget)
- [x] User photos only (Gallery / Camera / on-device Remove BG — no stock cars)
- [x] Remove BG on-device ONNX only; rembg `:8787` tools CLI only
- [x] Speedometers (18 stock + compose Add widget; thumbs sample 64)
- [x] GPS speed path via `geolocator` (iPhone/Android); web/Windows honest **— / Unavailable**
- [x] **Permission UX** — in-app pre-prompt → system dialog → Settings deep-link for Photos, Camera, Location When In Use (`permission_handler` + `geolocator`)
- [x] **Deep links** — `drivestudio://sounds|setup|home` via go_router + Info.plist / Android intent; web `?dl=`
- [x] Draft backup — Settings → Export / Import drafts JSON via clipboard
- [x] Settings copy honest (preview live toggle; rembg card; deep-link Available now)
- [x] Light haptics stubs (`HapticFeedback` on select / add / delete)
- [x] Docs + `flutter analyze` + focused tests

## Done on Windows

| Area | Status |
|------|--------|
| Editor layer compositor | Drag / resize / multi-widget Add photo + Add widget |
| User photos only | Gallery / Camera / on-device Remove BG — no stock cars |
| Permission pre-prompts | Photos / Camera / Location before picker or GPS; Settings if denied |
| Remove BG | On-device ONNX only; rembg `:8787` is tools CLI only |
| Speedometers | 18 stock templates + compose Add widget; thumbs sample 64 |
| GPS speed | `geolocator` wired for **iPhone/Android** live path; web/Windows stay **— / Unavailable** |
| Deep links | `DriveDeepLink` + go_router redirect; FlutterDeepLinkingEnabled |
| Draft backup | Settings → Export / Import drafts JSON via clipboard |
| Haptics (light) | Selection / add / delete via `DriveHaptics` (real on iOS later) |
| Settings copy | Preview-disabled live toggle labeled honestly; rembg card simplified |
| Docs | `REMBG_IPHONE.md`, `tools/rembg_server/README.md`, `IPHONE_LIVE_DATA.md`, this file |
| Quality | `flutter analyze` + focused stock/speedometer/cutout/cars/deep-link/permission tests |

## Preview at

**http://localhost:5173** (use `localhost`, not `127.0.0.1`, if IPv6-only bind)

```powershell
flutter run -d web-server --web-port=5173 --web-hostname=localhost
```

After `pub get` / permission plugin changes: **restart** the web server (hot reload is not enough). Soft tip for Photos on web: `?dl=setup` exercises deep-link redirect.

## Mac-only left

See **`MAC_HANDOFF.md`** (full) and **`BLOCKED_ON_MAC.md`** (short pointer):

1. WidgetKit Home Screen widgets (link extension + App Group on device)
2. StoreKit 2 IAP sandbox / restore
3. Native CarPlay UI — **not claimed** (Apple disallows custom dashboard shells)
4. TestFlight device verification

Overall Complete V1 remaining gap is **Mac device proof only**. Transfer: **`TRANSFER_CHECKLIST.md`**.
