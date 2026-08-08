# Drive Studio — transfer checklist (Windows → Mac)

Full detail: **[`MAC_HANDOFF.md`](MAC_HANDOFF.md)**. Short blocker crib: [`BLOCKED_ON_MAC.md`](BLOCKED_ON_MAC.md).

## Prefer

1. **Git clone / pull on Mac** (ignored caches never copy), **or**
2. Zip/rsync **after** cleanup below

## Must include

- [ ] `lib/`, `ios/`, `assets/`, `test/`, `docs/`
- [ ] `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`
- [ ] Root handoff docs (`MAC_HANDOFF.md`, `COMPLETE_V1.md`, `STORE_LISTING.md`, …)
- [ ] `tool/`, `tools/rembg_server/` **source** (`*.py`, `requirements.txt`, README, Dockerfile)
- [ ] `.gitignore`

## Must exclude / delete before copy

- [ ] `tools/rembg_server/.venv/` (~465 MB) — recreate on Mac if needed
- [ ] `build/`
- [ ] `.dart_tool/`
- [ ] `tools/rembg_server/demo_out/`
- [ ] `tools/rembg_server/__pycache__/` (and any other `__pycache__`)
- [ ] `tmp_ref_frames/`
- [ ] `*.log` (e.g. `flutter-web-5173.log`)
- [ ] `ios/Pods/`, `ios/.symlinks/`, `ios/Flutter/ephemeral/` if present
- [ ] `windows/flutter/ephemeral/` (Windows-only regenerable)

## Do not delete

- [ ] `ios/` stubs (WidgetKit, AppGroup, PrivacyInfo, Info.plist)
- [ ] `lib/`, `docs/legal/`, `assets/`, `pubspec.*`

## On Mac immediately

```bash
flutter pub get
cd ios && pod install && cd ..
flutter analyze
open ios/Runner.xcworkspace
```

Then follow **§8 First Mac session** in `MAC_HANDOFF.md`.

## Size note

Pre-clean tree was ~**904 MB**; after removing venv + `build` + `.dart_tool` + tmp/demo caches, tree is ~**53 MB** (mostly `assets/`).
