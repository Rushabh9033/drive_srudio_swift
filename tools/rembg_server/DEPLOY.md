# Deploy rembg (HQ cutouts)

Same FastAPI contract as local demo: `GET /health`, `POST /remove-bg`.

## Docker one-liner

From `tools/rembg_server`:

```bash
docker build -t drive-studio-rembg . && docker run --rm -p 8787:8787 drive-studio-rembg
```

Health: `http://127.0.0.1:8787/health`

Put a reverse proxy (Caddy / nginx / Cloud Run) in front with **HTTPS**, then set that base URL in Drive Studio → Settings (iPhone must use HTTPS, not `127.0.0.1`).

## Production URL placeholder

In the Flutter app:

```
https://rembg.example.com
```

Replace with your real host. Routes stay:

- `GET  {base}/health`
- `POST {base}/remove-bg`  (multipart field `file` → `image/png`)

## Notes

- First request may download the ONNX model (~hundreds of MB) unless baked into the image volume.
- Mount `~/.u2net` as a volume to cache models across restarts.
- GPU optional later (`rembg[gpu]`); CPU is the supported quality path for this stack.
