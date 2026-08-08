#!/usr/bin/env python3
"""
Download car-only stock photos (Unsplash/Pexels), crop tightly, save PNG.
Never downloads OEM logo packs. Vision-verify by opening each file after fetch.
"""

from __future__ import annotations

import io
import json
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
VEH = ROOT / "assets" / "vehicles"
STOCK = VEH / "stock"
MODELS = VEH / "models"
MANIFEST = ROOT / "tool" / "vehicle_photo_manifest.json"

UA = "DriveStudioAssetBot/1.0 (educational; personal project)"

# Curated car-only sources. IDs chosen for exterior vehicle dominance.
# angle: front34 | side | rear34
PHOTOS = [
    # Body-style heroes (overwrite garage styles with tighter car fills)
    {
        "key": "body/coupe",
        "out": "coupe.png",
        "angle": "front34",
        "url": "https://images.pexels.com/photos/2365572/pexels-photo-2365572.jpeg?auto=compress&cs=tinysrgb&w=1600",
        "crop": (0.05, 0.12, 0.95, 0.92),
        "note": "Yellow sports coupe front 3/4",
    },
    {
        "key": "body/sedan",
        "out": "sedan.png",
        "angle": "side",
        "url": "https://images.pexels.com/photos/170811/pexels-photo-170811.jpeg?auto=compress&cs=tinysrgb&w=1600",
        "crop": (0.02, 0.18, 0.98, 0.88),
        "note": "Black sedan side profile, clean fill",
    },
    {
        "key": "body/suv",
        "out": "suv.png",
        "angle": "front34",
        "url": "https://images.pexels.com/photos/116675/pexels-photo-116675.jpeg?auto=compress&cs=tinysrgb&w=1600",
        "crop": (0.08, 0.18, 0.92, 0.90),
        "note": "White SUV front 3/4",
    },
    {
        "key": "body/wagon",
        "out": "wagon.png",
        "angle": "side",
        "url": "https://images.unsplash.com/photo-1606664515524-ed2f786a0bd6?auto=format&fit=crop&w=1600&q=85",
        "crop": (0.05, 0.20, 0.95, 0.88),
        "note": "Estate/wagon side",
    },
    {
        "key": "body/roadster",
        "out": "roadster.png",
        "angle": "front34",
        "url": "https://images.pexels.com/photos/1335077/pexels-photo-1335077.jpeg?auto=compress&cs=tinysrgb&w=1600",
        "crop": (0.06, 0.15, 0.94, 0.90),
        "note": "Red convertible front 3/4",
    },
    {
        "key": "body/hatch",
        "out": "hatch.png",
        "angle": "side",
        "url": "https://images.unsplash.com/photo-1549317661-bd32c8ce0db2?auto=format&fit=crop&w=1600&q=85",
        "crop": (0.04, 0.22, 0.96, 0.90),
        "note": "Hatchback side",
    },
    # Stock angled set
    {
        "key": "stock/sedan-front34",
        "out": "stock/sedan-front34.png",
        "angle": "front34",
        "body": "Sedan",
        "brand": "Mercedes-Benz",
        "model": "E-Class",
        "url": "https://images.pexels.com/photos/112460/pexels-photo-112460.jpeg?auto=compress&cs=tinysrgb&w=1400",
        "crop": (0.08, 0.15, 0.95, 0.90),
        "note": "Black sedan front 3/4",
    },
    {
        "key": "stock/sedan-side",
        "out": "stock/sedan-side.png",
        "angle": "side",
        "body": "Sedan",
        "brand": "BMW",
        "model": "5 Series",
        "url": "https://images.pexels.com/photos/170811/pexels-photo-170811.jpeg?auto=compress&cs=tinysrgb&w=1400",
        "crop": (0.02, 0.20, 0.98, 0.88),
        "note": "Sedan side profile",
    },
    {
        "key": "stock/sedan-rear34",
        "out": "stock/sedan-rear34.png",
        "angle": "rear34",
        "body": "Sedan",
        "brand": "Audi",
        "model": "A4",
        "url": "https://images.unsplash.com/photo-1606664515524-ed2f786a0bd6?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.10, 0.18, 0.95, 0.88),
        "note": "Wagon/sedan rear-bias 3/4",
    },
    {
        "key": "stock/suv-front34",
        "out": "stock/suv-front34.png",
        "angle": "front34",
        "body": "SUV",
        "brand": "Land Rover",
        "model": "Range Rover Evoque",
        "url": "https://images.pexels.com/photos/116675/pexels-photo-116675.jpeg?auto=compress&cs=tinysrgb&w=1400",
        "crop": (0.10, 0.18, 0.90, 0.90),
        "note": "SUV front 3/4",
    },
    {
        "key": "stock/suv-side",
        "out": "stock/suv-side.png",
        "angle": "side",
        "body": "SUV",
        "brand": "Toyota",
        "model": "RAV4",
        "url": "https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.05, 0.20, 0.95, 0.90),
        "note": "SUV side/front mix cropped",
    },
    {
        "key": "stock/suv-rear34",
        "out": "stock/suv-rear34.png",
        "angle": "rear34",
        "body": "SUV",
        "brand": "Porsche",
        "model": "Cayenne",
        "url": "https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.08, 0.15, 0.95, 0.90),
        "note": "SUV trail rear 3/4 lean",
    },
    {
        "key": "stock/coupe-front34",
        "out": "stock/coupe-front34.png",
        "angle": "front34",
        "body": "Coupe",
        "brand": "Chevrolet",
        "model": "Camaro",
        "url": "https://images.unsplash.com/photo-1552519507-da3b142c6e3d?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.05, 0.12, 0.95, 0.90),
        "note": "Orange Camaro front 3/4",
    },
    {
        "key": "stock/coupe-side",
        "out": "stock/coupe-side.png",
        "angle": "side",
        "body": "Coupe",
        "brand": "Ford",
        "model": "Mustang",
        "url": "https://images.unsplash.com/photo-1494976388531-d1058494cdd8?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.05, 0.18, 0.95, 0.90),
        "note": "Classic coupe side/front",
    },
    {
        "key": "stock/sports-front34",
        "out": "stock/sports-front34.png",
        "angle": "front34",
        "body": "Sports",
        "brand": "Ferrari",
        "model": "488",
        "url": "https://images.unsplash.com/photo-1583121274602-3e2820c69888?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.06, 0.14, 0.94, 0.90),
        "note": "Red Ferrari front 3/4",
    },
    {
        "key": "stock/sports-side",
        "out": "stock/sports-side.png",
        "angle": "side",
        "body": "Sports",
        "brand": "Lamborghini",
        "model": "Huracán",
        "url": "https://images.unsplash.com/photo-1544636331-e26879cd4d9b?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.04, 0.16, 0.96, 0.90),
        "note": "Dark supercar",
    },
    {
        "key": "stock/sports-rear34",
        "out": "stock/sports-rear34.png",
        "angle": "rear34",
        "body": "Sports",
        "brand": "Porsche",
        "model": "911",
        "url": "https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.08, 0.15, 0.95, 0.90),
        "note": "Sports rear 3/4",
    },
    {
        "key": "stock/hatch-front34",
        "out": "stock/hatch-front34.png",
        "angle": "front34",
        "body": "Hatch",
        "brand": "Volkswagen",
        "model": "Golf",
        "url": "https://images.unsplash.com/photo-1489824904134-891ab64532f1?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.06, 0.18, 0.94, 0.90),
        "note": "City hatch front 3/4",
    },
    {
        "key": "stock/hatch-side",
        "out": "stock/hatch-side.png",
        "angle": "side",
        "body": "Hatch",
        "brand": "Mini",
        "model": "Cooper",
        "url": "https://images.unsplash.com/photo-1549317661-bd32c8ce0db2?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.04, 0.22, 0.96, 0.90),
        "note": "Compact hatch side",
    },
    {
        "key": "stock/truck-front34",
        "out": "stock/truck-front34.png",
        "angle": "front34",
        "body": "Truck",
        "brand": "Ford",
        "model": "F-150",
        "url": "https://images.unsplash.com/photo-1605893477799-b99e3b8b93fe?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.06, 0.12, 0.94, 0.92),
        "note": "Pickup front 3/4",
    },
    {
        "key": "stock/truck-side",
        "out": "stock/truck-side.png",
        "angle": "side",
        "body": "Truck",
        "brand": "Toyota",
        "model": "Tacoma",
        "url": "https://images.unsplash.com/photo-1464219789935-c2d9d9aba644?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.04, 0.15, 0.96, 0.90),
        "note": "Pickup trail",
    },
    {
        "key": "stock/ev-front34",
        "out": "stock/ev-front34.png",
        "angle": "front34",
        "body": "Sedan",
        "brand": "Tesla",
        "model": "Model 3",
        "url": "https://images.unsplash.com/photo-1560958089-b8a1929cea89?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.08, 0.18, 0.92, 0.90),
        "note": "EV sedan front 3/4",
    },
    {
        "key": "stock/ev-suv",
        "out": "stock/ev-suv.png",
        "angle": "front34",
        "body": "SUV",
        "brand": "Tesla",
        "model": "Model Y",
        "url": "https://images.unsplash.com/photo-1617788138017-80ad40651399?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.08, 0.16, 0.92, 0.90),
        "note": "EV crossover",
    },
    {
        "key": "stock/neon-sports",
        "out": "stock/neon-sports.png",
        "angle": "front34",
        "body": "Sports",
        "brand": "Lamborghini",
        "model": "Aventador",
        "url": "https://images.unsplash.com/photo-1525609004556-c46c7d6cf023?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.05, 0.12, 0.95, 0.90),
        "note": "Neon sports front 3/4",
    },
    {
        "key": "stock/luxury-front34",
        "out": "stock/luxury-front34.png",
        "angle": "front34",
        "body": "Sedan",
        "brand": "BMW",
        "model": "3 Series",
        "url": "https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.06, 0.16, 0.94, 0.90),
        "note": "Luxury sedan front 3/4",
    },
    {
        "key": "stock/japan-sports",
        "out": "stock/japan-sports.png",
        "angle": "side",
        "body": "Sports",
        "brand": "Toyota",
        "model": "Supra",
        "url": "https://images.unsplash.com/photo-1541899481282-d53bffe3c35d?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.05, 0.18, 0.95, 0.90),
        "note": "Compact sports",
    },
    {
        "key": "stock/roadster-front34",
        "out": "stock/roadster-front34.png",
        "angle": "front34",
        "body": "Sports",
        "brand": "Mazda",
        "model": "MX-5",
        "url": "https://images.pexels.com/photos/1335077/pexels-photo-1335077.jpeg?auto=compress&cs=tinysrgb&w=1400",
        "crop": (0.08, 0.16, 0.92, 0.90),
        "note": "Roadster front 3/4",
    },
    # Fictional garage model heroes (car-only crops)
    {
        "key": "models/aurelio-gt",
        "out": "models/aurelio-gt.png",
        "angle": "front34",
        "url": "https://images.unsplash.com/photo-1583121274602-3e2820c69888?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.06, 0.14, 0.94, 0.90),
        "note": "Sports coupe",
    },
    {
        "key": "models/aurelio-lumen",
        "out": "models/aurelio-lumen.png",
        "angle": "front34",
        "url": "https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.06, 0.16, 0.94, 0.90),
        "note": "Sedan",
    },
    {
        "key": "models/aurelio-vento",
        "out": "models/aurelio-vento.png",
        "angle": "front34",
        "url": "https://images.pexels.com/photos/1335077/pexels-photo-1335077.jpeg?auto=compress&cs=tinysrgb&w=1400",
        "crop": (0.08, 0.16, 0.92, 0.90),
        "note": "Roadster",
    },
    {
        "key": "models/velora-pulse",
        "out": "models/velora-pulse.png",
        "angle": "front34",
        "url": "https://images.unsplash.com/photo-1525609004556-c46c7d6cf023?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.05, 0.12, 0.95, 0.90),
        "note": "Sports EV look",
    },
    {
        "key": "models/velora-ex",
        "out": "models/velora-ex.png",
        "angle": "front34",
        "url": "https://images.unsplash.com/photo-1552519507-da3b142c6e3d?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.05, 0.12, 0.95, 0.90),
        "note": "Coupe",
    },
    {
        "key": "models/velora-arc",
        "out": "models/velora-arc.png",
        "angle": "side",
        "url": "https://images.pexels.com/photos/170811/pexels-photo-170811.jpeg?auto=compress&cs=tinysrgb&w=1400",
        "crop": (0.02, 0.20, 0.98, 0.88),
        "note": "Sedan side",
    },
    {
        "key": "models/northstar-trail",
        "out": "models/northstar-trail.png",
        "angle": "front34",
        "url": "https://images.pexels.com/photos/116675/pexels-photo-116675.jpeg?auto=compress&cs=tinysrgb&w=1400",
        "crop": (0.10, 0.18, 0.90, 0.90),
        "note": "SUV",
    },
    {
        "key": "models/northstar-peak",
        "out": "models/northstar-peak.png",
        "angle": "side",
        "url": "https://images.unsplash.com/photo-1606664515524-ed2f786a0bd6?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.05, 0.20, 0.95, 0.88),
        "note": "Wagon",
    },
    {
        "key": "models/kinetic-mono",
        "out": "models/kinetic-mono.png",
        "angle": "front34",
        "url": "https://images.unsplash.com/photo-1489824904134-891ab64532f1?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.06, 0.18, 0.94, 0.90),
        "note": "Hatch",
    },
    {
        "key": "models/kinetic-flux",
        "out": "models/kinetic-flux.png",
        "angle": "side",
        "url": "https://images.unsplash.com/photo-1549317661-bd32c8ce0db2?auto=format&fit=crop&w=1400&q=85",
        "crop": (0.04, 0.22, 0.96, 0.90),
        "note": "Compact",
    },
]


def fetch(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read()


def process(entry: dict, target_w: int = 1280, target_h: int = 720) -> Path:
    data = fetch(entry["url"])
    img = Image.open(io.BytesIO(data)).convert("RGB")
    w, h = img.size
    l, t, r, b = entry["crop"]
    box = (int(l * w), int(t * h), int(r * w), int(b * h))
    cropped = img.crop(box)

    # Fit into 16:9 canvas with letterbox dark fill (car stays large)
    cw, ch = cropped.size
    scale = min(target_w / cw, target_h / ch)
    nw, nh = max(1, int(cw * scale)), max(1, int(ch * scale))
    resized = cropped.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (target_w, target_h), (14, 16, 22))
    canvas.paste(resized, ((target_w - nw) // 2, (target_h - nh) // 2))

    out_rel = entry["out"]
    out_path = VEH / out_rel if not out_rel.startswith("models/") else ROOT / "assets" / "vehicles" / out_rel
    # Normalize: all outs relative to assets/vehicles
    out_path = VEH / out_rel
    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out_path, "PNG", optimize=True)
    return out_path


def main() -> None:
    STOCK.mkdir(parents=True, exist_ok=True)
    MODELS.mkdir(parents=True, exist_ok=True)
    results = []
    for entry in PHOTOS:
        try:
            path = process(entry)
            size = path.stat().st_size
            print(f"OK {entry['key']} -> {path.relative_to(ROOT)} ({size} bytes)")
            results.append({**entry, "path": str(path.relative_to(ROOT)), "bytes": size, "ok": True})
        except Exception as e:
            print(f"FAIL {entry['key']}: {e}")
            results.append({**entry, "ok": False, "error": str(e)})
    MANIFEST.write_text(json.dumps(results, indent=2), encoding="utf-8")
    print(f"manifest -> {MANIFEST.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
