#!/usr/bin/env python3
"""Generate abstract monogram / badge PNG marks (never OEM trademark artwork)."""

from __future__ import annotations

import colorsys
import hashlib
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "logos"

MAKES = [
    "Abarth",
    "Acura",
    "Alfa Romeo",
    "Alpine",
    "Aston Martin",
    "Audi",
    "Bentley",
    "BMW",
    "Buick",
    "BYD",
    "Cadillac",
    "Chevrolet",
    "Chrysler",
    "Citroën",
    "Cupra",
    "Dacia",
    "Dodge",
    "Ferrari",
    "Fiat",
    "Ford",
    "Genesis",
    "GMC",
    "Honda",
    "Hongqi",
    "Hyundai",
    "Ineos",
    "Infiniti",
    "Jaguar",
    "Jeep",
    "Kia",
    "Lamborghini",
    "Land Rover",
    "Lexus",
    "Lincoln",
    "Lotus",
    "Maserati",
    "Mazda",
    "McLaren",
    "Mercedes-Benz",
    "Mini",
    "Mitsubishi",
    "Nissan",
    "Peugeot",
    "Polestar",
    "Porsche",
    "Ram",
    "Renault",
    "Rivian",
    "Rolls-Royce",
    "Seat",
    "Skoda",
    "Smart",
    "SsangYong",
    "Subaru",
    "Suzuki",
    "Tesla",
    "Toyota",
    "Volkswagen",
    "Volvo",
]


def slugify(name: str) -> str:
    s = name.lower().replace("ë", "e").replace("é", "e")
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return s


def monogram(brand: str) -> str:
    parts = re.sub(r"[^A-Za-z0-9\s-]", "", brand)
    parts = [p for p in re.split(r"[\s-]+", parts) if p]
    if not parts:
        return "?"
    if len(parts) == 1:
        w = parts[0].upper()
        return w[:2] if len(w) >= 2 else w
    return (parts[0][0] + parts[1][0]).upper()


def accent_for(brand: str) -> tuple[int, int, int]:
    h = int(hashlib.md5(brand.lower().encode()).hexdigest()[:8], 16) % 360
    r, g, b = colorsys.hls_to_rgb(h / 360.0, 0.52, 0.55)
    return int(r * 255), int(g * 255), int(b * 255)


def load_font(size: int) -> ImageFont.ImageFont:
    candidates = [
        "C:/Windows/Fonts/segoeuib.ttf",
        "C:/Windows/Fonts/arialbd.ttf",
        "C:/Windows/Fonts/arial.ttf",
        "/System/Library/Fonts/SFNS.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def render_badge(brand: str, size: int = 256) -> Image.Image:
    mark = monogram(brand)
    accent = accent_for(brand)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    pad = size * 0.04
    # Soft outer ring
    draw.ellipse(
        [pad, pad, size - pad, size - pad],
        fill=(18, 20, 28, 255),
        outline=(*accent, 220),
        width=max(3, size // 42),
    )
    # Inner fill gradient approximation via concentric discs
    cx = cy = size / 2
    for i in range(18, 0, -1):
        t = i / 18
        r = int(18 + (accent[0] - 18) * (1 - t) * 0.45)
        g = int(20 + (accent[1] - 20) * (1 - t) * 0.45)
        b = int(28 + (accent[2] - 28) * (1 - t) * 0.45)
        rad = (size * 0.42) * t
        draw.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=(r, g, b, 255))

    font_size = int(size * (0.30 if len(mark) > 2 else 0.38))
    font = load_font(font_size)
    bbox = draw.textbbox((0, 0), mark, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(
        ((size - tw) / 2 - bbox[0], (size - th) / 2 - bbox[1] - size * 0.02),
        mark,
        font=font,
        fill=(245, 247, 250, 255),
    )

    # Thin highlight arc
    draw.arc(
        [size * 0.14, size * 0.12, size * 0.86, size * 0.78],
        start=200,
        end=340,
        fill=(255, 255, 255, 55),
        width=max(2, size // 80),
    )
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for brand in MAKES:
        slug = slugify(brand)
        path = OUT / f"{slug}.png"
        render_badge(brand).save(path, "PNG", optimize=True)
        print(f"wrote {path.relative_to(ROOT)}")
    print(f"done: {len(MAKES)} logos")


if __name__ == "__main__":
    main()
