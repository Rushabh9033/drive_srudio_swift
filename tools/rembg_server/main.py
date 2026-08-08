"""
Drive Studio rembg cutout API — THE quality background-removal path.

Runs on desktop / VPS / Docker only. Does NOT embed in the iPhone binary.
iPhone Flutter uploads to this same HTTP contract over HTTPS when hosted.

POST /remove-bg  multipart field "file" → PNG with alpha
GET  /health     {"ok": true, "engine": "rembg", ...}
"""

from __future__ import annotations

import io
from typing import Annotated

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from PIL import Image
from rembg import new_session, remove

app = FastAPI(
    title="Drive Studio rembg",
    description=(
        "HQ background removal for user car photos (rembg[cpu]). "
        "Host this API; Flutter never runs rembg on-device."
    ),
    version="1.1.0",
)

# Flutter web / desktop / phone (LAN) need CORS for local demo.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

_MAX_BYTES = 25 * 1024 * 1024  # 25 MB
_SESSION = None


def _session():
    """Lazy-load ONNX session once (first request downloads model if needed)."""
    global _SESSION
    if _SESSION is None:
        _SESSION = new_session()
    return _SESSION


@app.on_event("startup")
def _warmup() -> None:
    # Fail fast if rembg/onnx cannot initialize; keep first user request faster.
    try:
        _session()
    except Exception:  # noqa: BLE001 — health will still report; warmup is best-effort
        pass


@app.get("/health")
def health() -> dict[str, object]:
    ready = _SESSION is not None
    return {
        "ok": True,
        "engine": "rembg",
        "device": "cpu",
        "session_ready": ready,
        "quality": "hq",
    }


@app.post("/remove-bg")
async def remove_bg(
    file: Annotated[UploadFile, File(description="Car photo (JPEG/PNG/WebP)")],
) -> Response:
    raw = await file.read()
    if not raw:
        raise HTTPException(status_code=400, detail="Empty upload")
    if len(raw) > _MAX_BYTES:
        raise HTTPException(status_code=413, detail="Image too large (max 25 MB)")

    content_type = (file.content_type or "").lower()
    if content_type and not (
        content_type.startswith("image/")
        or content_type in {"application/octet-stream", "binary/octet-stream"}
    ):
        raise HTTPException(
            status_code=415,
            detail=f"Expected an image upload, got {content_type!r}",
        )

    try:
        out = remove(raw, session=_session())
    except Exception as exc:  # noqa: BLE001 — surface to client
        raise HTTPException(status_code=422, detail=f"rembg failed: {exc}") from exc

    if not out:
        raise HTTPException(status_code=500, detail="Empty rembg output")

    # Ensure valid PNG (defensive)
    try:
        Image.open(io.BytesIO(out)).verify()
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=500, detail=f"Invalid rembg output: {exc}") from exc

    return Response(
        content=out,
        media_type="image/png",
        headers={"Cache-Control": "no-store"},
    )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="127.0.0.1", port=8787, reload=False)
