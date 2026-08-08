# Drive Studio — rembg CLI demo server (optional)

**Not used by the Flutter editor.** In-app Remove BG is on-device ONNX only (`image_background_remover`). This FastAPI app is a **local tools demo** for comparing cutouts via curl / `demo_remove.py`.

Stack: Python **rembg[cpu]** + Pillow + FastAPI + uvicorn. See [`REMBG_IPHONE.md`](../../REMBG_IPHONE.md).

## Install

```powershell
cd tools\rembg_server
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

## Run API (port 8787)

```powershell
uvicorn main:app --host 127.0.0.1 --port 8787
```

| Route | Purpose |
|--------|---------|
| `GET /health` | `{"ok": true, "engine": "rembg", ...}` |
| `POST /remove-bg` | multipart `file` → transparent PNG |

```powershell
curl http://127.0.0.1:8787/health
curl -X POST http://127.0.0.1:8787/remove-bg -F "file=@car.jpg" --output cutout.png
```

## Offline demo

```powershell
python demo_remove.py
```

Writes `demo_out/before.png` and `demo_out/after.png`.

## Flutter

Drive Studio does **not** need this server. Settings has no rembg URL. Editor never falls back to HTTP cutouts.
