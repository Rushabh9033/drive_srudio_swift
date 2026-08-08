"""
Offline rembg demo — no server required.

Usage (from tools/rembg_server):
  python demo_remove.py
  python demo_remove.py path/to/car.jpg

Writes before.png / after.png under demo_out/
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

from PIL import Image
from rembg import remove

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "demo_out"
REPO = ROOT.parent.parent


def _default_sample() -> Path:
    stock = REPO / "assets" / "vehicles" / "stock" / "coupe-front34.png"
    if stock.is_file():
        return stock
    raise FileNotFoundError(
        "No sample image. Pass a path: python demo_remove.py your_car.jpg"
    )


def main() -> int:
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else _default_sample()
    if not src.is_file():
        print(f"Missing input: {src}", file=sys.stderr)
        return 1

    OUT.mkdir(parents=True, exist_ok=True)
    before = OUT / "before.png"
    after = OUT / "after.png"

    # Normalize before as PNG for easy side-by-side open
    img = Image.open(src).convert("RGBA")
    img.save(before)
    print(f"Before -> {before}")

    raw = src.read_bytes()
    print("Running rembg (first run downloads the ONNX model)...")
    cut = remove(raw)
    after.write_bytes(cut)
    print(f"After  -> {after}")
    print("Open both files in demo_out/ to compare.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
