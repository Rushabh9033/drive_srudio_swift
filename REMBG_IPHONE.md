# Background removal — on-device only (editor)

## Product path (editor)

| Path | Where it runs | Notes |
|------|---------------|-------|
| **Remove BG** | Flutter + `image_background_remover` (ONNX) on **iOS 16+ / Android / desktop** | Offline, no Python, privacy |
| **Web** | On-device ONNX unavailable | Snackbar explains unsupported — **no rembg HTTP fallback** |

The editor **never** calls the optional rembg helper server and **never** shows “helper server is not reachable”.

## Where to tap

1. **Studio → Create / Edit widget** (editor)
2. Top chrome **Remove BG** / **Add photo** → Gallery or Camera
3. After pick → optional **Remove BG**
4. Select an image layer → **Remove BG** again

## Architecture

```
[Gallery / Camera photo]
        │
        └─ Remove BG ──► on-device ONNX only
                │
                ▼
        Transparent PNG on canvas
```

## Optional rembg server (tools only)

`tools/rembg_server` on port **8787** is a **developer CLI demo** (`curl` / `demo_remove.py`). It is **not** wired into Drive Studio Settings or the editor.

```powershell
cd tools\rembg_server
.\.venv\Scripts\Activate.ps1
uvicorn main:app --host 127.0.0.1 --port 8787
```

## Package

- **Chosen:** [`image_background_remover`](https://pub.dev/packages/image_background_remover) `2.0.1`
- **Platforms:** iOS (16+), Android, Windows, macOS, Linux
- **App size:** ONNX model adds ~30MB on mobile/desktop

## Product rules

1. **Add photo** = Gallery / Camera / Remove BG. No stock car photos.
2. **Remove BG** works without Python on device/desktop builds.
3. Success → transparent PNG on canvas.
