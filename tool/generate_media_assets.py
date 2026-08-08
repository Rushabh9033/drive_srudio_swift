#!/usr/bin/env python3
"""Generate catalog cue WAVs (and optional legacy procedural vehicle PNGs).

IMPORTANT: Garage / Home use **photographic** Unsplash assets under
assets/vehicles/ — see ASSETS.md. Do not overwrite those photos with the
procedural studio renders in this script unless you intentionally want
illustrations again.

Fictional brands only in catalog UI — no trademarked marques or logos.
Re-run sounds:  python tool/generate_media_assets.py
"""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageEnhance, ImageFont

ROOT = Path(__file__).resolve().parents[1]
VEHICLES = ROOT / "assets" / "vehicles"
MODELS = VEHICLES / "models"
SOUNDS = ROOT / "assets" / "sounds"

W, H = 1280, 720


def mix(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def clamp(v, lo=0, hi=255):
    return max(lo, min(hi, int(v)))


def grad_rect(size, top, bot, horizontal=False):
    img = Image.new("RGB", size)
    px = img.load()
    w, h = size
    for y in range(h):
        for x in range(w):
            t = (x / max(w - 1, 1)) if horizontal else (y / max(h - 1, 1))
            px[x, y] = mix(top, bot, t)
    return img


def radial(size, center, inner, outer, radius):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    px = img.load()
    cx, cy = center
    w, h = size
    r2 = radius * radius
    for y in range(h):
        for x in range(w):
            d2 = (x - cx) ** 2 + (y - cy) ** 2
            if d2 > r2:
                continue
            t = math.sqrt(d2) / radius
            c = mix(inner[:3], outer[:3], t)
            a = int(lerp(inner[3] if len(inner) > 3 else 255, outer[3] if len(outer) > 3 else 0, t))
            px[x, y] = (*c, a)
    return img


def lerp(a, b, t):
    return a + (b - a) * t


def bezier_points(p0, p1, p2, p3, steps=32):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        x = u*u*u*p0[0] + 3*u*u*t*p1[0] + 3*u*t*t*p2[0] + t*t*t*p3[0]
        y = u*u*u*p0[1] + 3*u*u*t*p1[1] + 3*u*t*t*p2[1] + t*t*t*p3[1]
        pts.append((x, y))
    return pts


# Profile control: roof line + rocker as cubic segments (normalized 0-1 frame)
# Each kind: list of cubics for upper silhouette (hood→trunk), then lower return.
PROFILES = {
    "coupe": {
        "upper": [
            ((0.04, 0.72), (0.08, 0.68), (0.14, 0.58), (0.22, 0.48)),
            ((0.22, 0.48), (0.30, 0.38), (0.40, 0.34), (0.52, 0.34)),
            ((0.52, 0.34), (0.64, 0.34), (0.74, 0.40), (0.82, 0.50)),
            ((0.82, 0.50), (0.88, 0.56), (0.93, 0.64), (0.96, 0.72)),
        ],
        "windows": [
            [(0.30, 0.42), (0.38, 0.36), (0.50, 0.36), (0.58, 0.40), (0.56, 0.50), (0.32, 0.50)],
            [(0.60, 0.41), (0.68, 0.42), (0.74, 0.48), (0.72, 0.52), (0.60, 0.50)],
        ],
        "wheelbase": (0.24, 0.76),
    },
    "sedan": {
        "upper": [
            ((0.03, 0.72), (0.08, 0.66), (0.14, 0.56), (0.22, 0.48)),
            ((0.22, 0.48), (0.28, 0.40), (0.36, 0.36), (0.46, 0.36)),
            ((0.46, 0.36), (0.58, 0.36), (0.68, 0.38), (0.76, 0.46)),
            ((0.76, 0.46), (0.84, 0.52), (0.92, 0.62), (0.97, 0.72)),
        ],
        "windows": [
            [(0.28, 0.44), (0.36, 0.38), (0.48, 0.38), (0.54, 0.44), (0.52, 0.52), (0.30, 0.52)],
            [(0.56, 0.44), (0.66, 0.40), (0.74, 0.44), (0.72, 0.52), (0.56, 0.52)],
        ],
        "wheelbase": (0.22, 0.78),
    },
    "suv": {
        "upper": [
            ((0.04, 0.74), (0.08, 0.58), (0.12, 0.48), (0.18, 0.42)),
            ((0.18, 0.42), (0.28, 0.34), (0.40, 0.32), (0.55, 0.32)),
            ((0.55, 0.32), (0.70, 0.32), (0.82, 0.36), (0.90, 0.46)),
            ((0.90, 0.46), (0.94, 0.54), (0.96, 0.64), (0.97, 0.74)),
        ],
        "windows": [
            [(0.22, 0.40), (0.30, 0.34), (0.48, 0.34), (0.54, 0.40), (0.52, 0.50), (0.24, 0.50)],
            [(0.56, 0.40), (0.70, 0.34), (0.82, 0.40), (0.80, 0.50), (0.56, 0.50)],
        ],
        "wheelbase": (0.24, 0.76),
    },
    "wagon": {
        "upper": [
            ((0.04, 0.74), (0.08, 0.60), (0.14, 0.50), (0.22, 0.42)),
            ((0.22, 0.42), (0.30, 0.34), (0.42, 0.32), (0.58, 0.32)),
            ((0.58, 0.32), (0.74, 0.32), (0.86, 0.38), (0.92, 0.50)),
            ((0.92, 0.50), (0.95, 0.58), (0.96, 0.66), (0.97, 0.74)),
        ],
        "windows": [
            [(0.24, 0.40), (0.32, 0.34), (0.52, 0.34), (0.58, 0.40), (0.56, 0.50), (0.26, 0.50)],
            [(0.60, 0.40), (0.78, 0.34), (0.86, 0.42), (0.84, 0.50), (0.60, 0.50)],
        ],
        "wheelbase": (0.22, 0.78),
    },
    "roadster": {
        "upper": [
            ((0.04, 0.74), (0.10, 0.66), (0.18, 0.56), (0.28, 0.50)),
            ((0.28, 0.50), (0.40, 0.46), (0.52, 0.46), (0.64, 0.50)),
            ((0.64, 0.50), (0.76, 0.56), (0.88, 0.64), (0.96, 0.74)),
        ],
        "windows": [
            [(0.34, 0.50), (0.44, 0.48), (0.58, 0.48), (0.64, 0.52), (0.62, 0.58), (0.36, 0.58)],
        ],
        "wheelbase": (0.26, 0.74),
    },
    "hatch": {
        "upper": [
            ((0.05, 0.74), (0.10, 0.62), (0.16, 0.52), (0.24, 0.44)),
            ((0.24, 0.44), (0.34, 0.36), (0.48, 0.34), (0.60, 0.34)),
            ((0.60, 0.34), (0.72, 0.36), (0.82, 0.46), (0.90, 0.58)),
            ((0.90, 0.58), (0.94, 0.64), (0.96, 0.70), (0.96, 0.74)),
        ],
        "windows": [
            [(0.28, 0.42), (0.38, 0.36), (0.55, 0.36), (0.66, 0.42), (0.64, 0.52), (0.30, 0.52)],
            [(0.68, 0.42), (0.78, 0.46), (0.82, 0.54), (0.70, 0.54)],
        ],
        "wheelbase": (0.24, 0.74),
    },
}

PALETTES = {
    "coupe": dict(bg1=(12, 18, 32), bg2=(4, 6, 12), body=(40, 110, 210), dark=(14, 42, 90),
                  light=(140, 190, 255), chrome=(200, 210, 225), glass=(40, 55, 80)),
    "sedan": dict(bg1=(18, 20, 26), bg2=(6, 7, 10), body=(200, 206, 214), dark=(80, 86, 98),
                  light=(245, 248, 252), chrome=(180, 188, 200), glass=(50, 60, 75)),
    "suv": dict(bg1=(12, 24, 18), bg2=(4, 10, 8), body=(42, 78, 54), dark=(18, 40, 26),
                light=(150, 200, 160), chrome=(170, 180, 175), glass=(35, 50, 45)),
    "wagon": dict(bg1=(28, 20, 12), bg2=(10, 8, 4), body=(160, 88, 42), dark=(80, 40, 18),
                  light=(230, 180, 120), chrome=(190, 170, 150), glass=(55, 45, 35)),
    "roadster": dict(bg1=(32, 10, 14), bg2=(12, 4, 6), body=(185, 36, 42), dark=(90, 14, 18),
                     light=(255, 150, 140), chrome=(210, 200, 200), glass=(50, 35, 40)),
    "hatch": dict(bg1=(12, 16, 28), bg2=(4, 6, 12), body=(58, 66, 88), dark=(24, 28, 40),
                  light=(140, 165, 210), chrome=(180, 190, 205), glass=(40, 48, 65)),
}

MODEL_THEMES = {
    "aurelio-gt": ("coupe", dict(bg1=(10, 16, 36), bg2=(4, 6, 14), body=(30, 95, 205), dark=(10, 40, 95),
                   light=(150, 195, 255), chrome=(200, 210, 230), glass=(35, 50, 80))),
    "aurelio-lumen": ("sedan", dict(bg1=(16, 22, 30), bg2=(6, 8, 12), body=(228, 232, 238), dark=(100, 108, 120),
                      light=(255, 255, 255), chrome=(190, 198, 210), glass=(55, 65, 80))),
    "aurelio-vento": ("roadster", dict(bg1=(24, 14, 36), bg2=(8, 4, 14), body=(95, 48, 175), dark=(42, 18, 85),
                       light=(200, 165, 255), chrome=(190, 180, 210), glass=(45, 35, 65))),
    "velora-pulse": ("coupe", dict(bg1=(22, 10, 28), bg2=(8, 4, 12), body=(115, 38, 165), dark=(48, 14, 72),
                     light=(215, 145, 255), chrome=(190, 175, 205), glass=(50, 35, 65))),
    "velora-ex": ("coupe", dict(bg1=(10, 12, 20), bg2=(2, 3, 6), body=(22, 24, 30), dark=(8, 9, 12),
                  light=(100, 160, 255), chrome=(140, 150, 165), glass=(25, 30, 40))),
    "velora-arc": ("sedan", dict(bg1=(12, 18, 28), bg2=(4, 6, 10), body=(55, 125, 175), dark=(22, 55, 85),
                   light=(150, 205, 255), chrome=(170, 190, 210), glass=(40, 55, 70))),
    "northstar-trail": ("suv", dict(bg1=(14, 26, 16), bg2=(4, 10, 6), body=(50, 88, 56), dark=(20, 40, 24),
                        light=(155, 210, 155), chrome=(160, 175, 165), glass=(30, 45, 35))),
    "northstar-peak": ("wagon", dict(bg1=(20, 24, 14), bg2=(8, 10, 6), body=(130, 112, 62), dark=(65, 54, 28),
                       light=(220, 200, 140), chrome=(180, 170, 145), glass=(50, 48, 35))),
    "kinetic-mono": ("hatch", dict(bg1=(14, 16, 24), bg2=(5, 6, 10), body=(235, 115, 35), dark=(130, 55, 12),
                     light=(255, 195, 130), chrome=(200, 185, 170), glass=(55, 45, 40))),
    "kinetic-flux": ("hatch", dict(bg1=(10, 18, 26), bg2=(4, 8, 10), body=(28, 155, 165), dark=(12, 68, 74),
                     light=(130, 230, 240), chrome=(160, 195, 200), glass=(30, 50, 55))),
}


def build_body_poly(kind):
    prof = PROFILES[kind]
    upper = []
    for seg in prof["upper"]:
        pts = bezier_points(*seg, steps=28)
        if upper:
            pts = pts[1:]
        upper.extend(pts)
    # rocker return (flat underside with wheel arches)
    wb0, wb1 = prof["wheelbase"]
    last = upper[-1]
    first = upper[0]
    rocker_y = 0.78
    arch_r = 0.055
    lower = [(last[0], rocker_y)]
    # rear arch
    for a in range(0, 181, 8):
        rad = math.radians(a)
        lower.append((wb1 + arch_r * math.cos(rad), rocker_y - arch_r * math.sin(rad) * 0.95))
    lower.append((wb0 + arch_r + 0.02, rocker_y))
    # front arch
    for a in range(0, 181, 8):
        rad = math.radians(a)
        lower.append((wb0 - arch_r * math.cos(rad), rocker_y - arch_r * math.sin(rad) * 0.95))
    lower.append((first[0], rocker_y))
    return upper + lower


def nx(p, ox, oy, sx, sy):
    return (ox + p[0] * sx, oy + p[1] * sy)


def paint_metallic(base: Image.Image, mask: Image.Image, palette, light_xy):
    """Shade body with soft metallic gradient inside mask."""
    w, h = base.size
    shaded = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = shaded.load()
    mpx = mask.load()
    lx, ly = light_xy
    body, dark, light = palette["body"], palette["dark"], palette["light"]
    for y in range(h):
        for x in range(w):
            a = mpx[x, y][3] if isinstance(mpx[x, y], tuple) else mpx[x, y]
            if a < 8:
                continue
            # vertical panel + specular lobe
            vt = y / max(h - 1, 1)
            dx, dy = (x - lx) / w, (y - ly) / h
            spec = math.exp(-(dx * dx * 18 + dy * dy * 28))
            c = mix(dark, body, 0.35 + 0.55 * (1 - abs(vt - 0.45)))
            c = mix(c, light, min(0.55, spec * 0.7))
            # lower rocker darker
            if vt > 0.62:
                c = mix(c, dark, (vt - 0.62) / 0.38 * 0.65)
            px[x, y] = (*c, a)
    return shaded


def draw_wheel(draw, cx, cy, r, chrome):
    # tire
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(12, 12, 14, 255))
    draw.ellipse((cx - r + 3, cy - r + 3, cx + r - 3, cy + r - 3), fill=(28, 28, 32, 255))
    # rim
    rr = r * 0.62
    draw.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=(*chrome, 255))
    draw.ellipse((cx - rr + 4, cy - rr + 4, cx + rr - 4, cy + rr - 4), fill=(55, 58, 65, 255))
    hub = r * 0.22
    draw.ellipse((cx - hub, cy - hub, cx + hub, cy + hub), fill=(*mix(chrome, (255, 255, 255), 0.3), 255))
    for a in range(0, 360, 30):
        rad = math.radians(a)
        x1 = cx + math.cos(rad) * hub * 1.2
        y1 = cy + math.sin(rad) * hub * 1.2
        x2 = cx + math.cos(rad) * rr * 0.85
        y2 = cy + math.sin(rad) * rr * 0.85
        draw.line((x1, y1, x2, y2), fill=(*chrome, 220), width=3)
    # tire highlight
    draw.arc((cx - r + 6, cy - r + 6, cx + r - 6, cy + r - 6), 200, 320, fill=(80, 80, 90, 120), width=2)


def render_vehicle(kind: str, palette: dict, label: str | None = None) -> Image.Image:
    # studio backdrop
    bg = grad_rect((W, H), palette["bg1"], palette["bg2"])
    # floor reflection plane
    floor = grad_rect((W, H // 3), mix(palette["bg2"], (0, 0, 0), 0.2), palette["bg2"])
    bg.paste(floor, (0, H - H // 3))

    # soft key light
    glow = radial((W, H), (W * 0.35, H * 0.25), (*mix(palette["light"], (255, 255, 255), 0.4), 55), (0, 0, 0, 0), 520)
    bg = Image.alpha_composite(bg.convert("RGBA"), glow).convert("RGB")
    rim = radial((W, H), (W * 0.78, H * 0.4), (*palette["light"], 35), (0, 0, 0, 0), 380)
    bg = Image.alpha_composite(bg.convert("RGBA"), rim).convert("RGB")

    ox, oy, sx, sy = 80.0, 40.0, 1120.0, 560.0
    body_norm = build_body_poly(kind)
    body = [nx(p, ox, oy, sx, sy) for p in body_norm]

    # contact shadow
    shadow_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow_layer)
    xs = [p[0] for p in body]
    ys = [p[1] for p in body]
    cy_ground = max(ys) + 8
    sd.ellipse((min(xs) + 40, cy_ground - 18, max(xs) - 40, cy_ground + 28), fill=(0, 0, 0, 110))
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(18))

    # body mask
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon(body, fill=255)
    mask_rgba = Image.merge("RGBA", (mask, mask, mask, mask))

    # base fill then metallic shade
    base_fill = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(base_fill).polygon(body, fill=(*palette["body"], 255))
    metallic = paint_metallic(base_fill, mask_rgba, palette, (W * 0.38, H * 0.32))
    metallic = Image.composite(metallic, Image.new("RGBA", (W, H), (0, 0, 0, 0)), mask)

    # clear-coat stripe
    stripe = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    st = ImageDraw.Draw(stripe)
    miny = min(ys)
    st.polygon([
        (min(xs) + 90, miny + 8),
        (max(xs) - 120, miny + 14),
        (max(xs) - 140, miny + 48),
        (min(xs) + 110, miny + 42),
    ], fill=(*palette["light"], 55))
    stripe = stripe.filter(ImageFilter.GaussianBlur(6))
    stripe = Image.composite(stripe, Image.new("RGBA", (W, H), (0, 0, 0, 0)), mask)

    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    layer = Image.alpha_composite(layer, shadow_layer)
    layer = Image.alpha_composite(layer, metallic)
    layer = Image.alpha_composite(layer, stripe)

    draw = ImageDraw.Draw(layer)

    # windows with glass depth
    for win in PROFILES[kind]["windows"]:
        wp = [nx(p, ox, oy, sx, sy) for p in win]
        draw.polygon(wp, fill=(*palette["glass"], 230))
        # inner glass
        if len(wp) >= 3:
            inset = [
                (wp[0][0] + 6, wp[0][1] + 4),
                (wp[1][0] + 4, wp[1][1] + 4),
                (wp[2][0] - 4, wp[2][1] + 4),
            ]
            if len(wp) > 3:
                inset.append((wp[3][0] - 6, wp[3][1] + 2))
            draw.polygon(inset[:4] if len(inset) >= 4 else inset, fill=(20, 28, 40, 100))
        # reflection slash
        draw.polygon([
            (wp[0][0] + 8, wp[0][1] + 6),
            (wp[1][0] - 4, wp[1][1] + 8),
            (wp[1][0] + 10, wp[1][1] + 22),
            (wp[0][0] + 18, wp[0][1] + 20),
        ], fill=(220, 235, 255, 70))

    # chrome trim under windows
    for win in PROFILES[kind]["windows"]:
        wp = [nx(p, ox, oy, sx, sy) for p in win]
        bottom = sorted(wp, key=lambda p: -p[1])[:2]
        if len(bottom) == 2:
            draw.line((bottom[0], bottom[1]), fill=(*palette["chrome"], 160), width=2)

    # lights
    maxx, minx = max(xs), min(xs)
    maxy = max(ys)
    # headlight cluster (front = right in our profiles)
    hx1, hy1 = maxx - 58, maxy - 130
    draw.rounded_rectangle((hx1, hy1, hx1 + 48, hy1 + 22), radius=8, fill=(255, 248, 220, 255))
    draw.ellipse((hx1 - 10, hy1 - 8, hx1 + 58, hy1 + 30), fill=(255, 250, 230, 45))
    # taillight
    draw.rounded_rectangle((minx + 18, maxy - 125, minx + 48, maxy - 105), radius=5, fill=(230, 40, 45, 255))
    draw.rounded_rectangle((minx + 18, maxy - 125, minx + 48, maxy - 105), radius=5, outline=(255, 120, 120, 180))

    # door crease + handle
    door_x = (minx + maxx) * 0.48
    draw.line((door_x, miny + 70, door_x, maxy - 55), fill=(0, 0, 0, 55), width=2)
    draw.rounded_rectangle((door_x + 8, (miny + maxy) * 0.52, door_x + 28, (miny + maxy) * 0.52 + 8),
                           radius=3, fill=(*palette["chrome"], 200))

    # side skirt highlight
    draw.arc((minx + 40, maxy - 70, maxx - 40, maxy + 10), 200, 340, fill=(*palette["light"], 40), width=3)

    # wheels
    wb0, wb1 = PROFILES[kind]["wheelbase"]
    wheel_y = oy + 0.78 * sy
    wr = 52
    for wx in (ox + wb0 * sx, ox + wb1 * sx):
        draw_wheel(draw, wx, wheel_y, wr, palette["chrome"])

    # body outline soft
    draw.line(body + [body[0]], fill=(*mix(palette["body"], (255, 255, 255), 0.25), 90), width=2)

    # floor reflection (mirrored soft body)
    refl = metallic.transpose(Image.FLIP_TOP_BOTTOM)
    refl = refl.crop((0, H - int(maxy) - 40, W, H))
    # rebuild simpler: faded ellipse already used; add translucent body ghost
    ghost = metallic.copy()
    gpx = ghost.load()
    for y in range(H):
        for x in range(W):
            p = gpx[x, y]
            if p[3] < 8:
                continue
            # map to below car
            ny = int(2 * maxy - y + 20)
            if 0 <= ny < H:
                fade = max(0, 70 - abs(ny - maxy) // 2)
                if fade > 0:
                    pass  # skip expensive; use blur of shadow instead
    # soft reflection blot
    refl_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rd = ImageDraw.Draw(refl_layer)
    rd.ellipse((minx + 60, maxy + 4, maxx - 60, maxy + 70), fill=(*palette["body"], 35))
    refl_layer = refl_layer.filter(ImageFilter.GaussianBlur(12))
    layer = Image.alpha_composite(Image.alpha_composite(Image.new("RGBA", (W, H), (0, 0, 0, 0)), refl_layer), layer)

    out = Image.alpha_composite(bg.convert("RGBA"), layer).convert("RGB")
    out = ImageEnhance.Contrast(out).enhance(1.12)
    out = ImageEnhance.Color(out).enhance(1.08)
    out = ImageEnhance.Sharpness(out).enhance(1.15)

    if label:
        d = ImageDraw.Draw(out)
        tw = max(72, 10 * len(label) + 36)
        d.rounded_rectangle((28, 28, 28 + tw, 62), radius=12, fill=(12, 14, 20))
        d.rounded_rectangle((28, 28, 28 + tw, 62), radius=12, outline=(*palette["light"],))
        try:
            font = ImageFont.truetype("arial.ttf", 18)
        except Exception:
            font = ImageFont.load_default()
        d.text((42, 36), label.upper(), fill=mix(palette["light"], (255, 255, 255), 0.4), font=font)

    return out


def write_wav(path: Path, samples: list[float], sample_rate: int = 44100) -> float:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        frames = bytearray()
        for s in samples:
            v = max(-1.0, min(1.0, s))
            frames += struct.pack("<h", int(v * 32767))
        wf.writeframes(frames)
    return len(samples) / sample_rate


def env_adsr(t, dur, a=0.02, d=0.08, s=0.55, r=0.25):
    if t < a:
        return t / a
    if t < a + d:
        return 1.0 - (1.0 - s) * ((t - a) / d)
    if t < dur - r:
        return s
    if t < dur:
        return s * (1.0 - (t - (dur - r)) / r)
    return 0.0


def tone(freq, t, phase=0.0):
    return math.sin(2 * math.pi * freq * t + phase)


def synth_cue(cue_id: str, base_freq: float) -> list[float]:
    sr = 44100
    dur = 1.15
    n = int(sr * dur)
    out = [0.0] * n
    f = base_freq
    for i in range(n):
        t = i / sr
        e = env_adsr(t, dur)
        s = 0.0
        if cue_id == "soft-chime":
            s = 0.45 * tone(f, t) * e + 0.22 * tone(f * 2.01, t) * e + 0.12 * tone(f * 3.02, t) * e
        elif cue_id == "low-pulse":
            pulse = 0.5 + 0.5 * math.sin(2 * math.pi * 3.5 * t)
            s = 0.55 * tone(f, t) * e * pulse + 0.15 * tone(f * 0.5, t) * e
        elif cue_id == "ignition":
            sweep = f * (0.55 + 0.9 * min(1.0, t / 0.35))
            noise = (hash(i * 2654435761) % 1000) / 1000.0 - 0.5
            s = 0.4 * tone(sweep, t) * e + 0.18 * noise * e * math.exp(-t * 4)
        elif cue_id == "glass-tap":
            s = (0.5 * tone(f, t) + 0.25 * tone(f * 1.41, t) + 0.15 * tone(f * 2.2, t)) * math.exp(-t * 9)
        elif cue_id == "spark-line":
            s = 0.35 * tone(f, t) * e
            if 0.08 < t < 0.14 or 0.22 < t < 0.28:
                s += 0.45 * tone(f * 1.5, t) * math.exp(-(t % 0.14) * 20)
        elif cue_id == "end-route":
            s = 0.4 * tone(f, t) * e + 0.3 * tone(f * 0.75, t) * env_adsr(t - 0.12, max(0.01, dur - 0.12))
        elif cue_id == "power-down":
            sweep = f * (1.2 - 0.7 * min(1.0, t / dur))
            s = 0.5 * tone(sweep, t) * e + 0.15 * tone(sweep * 0.5, t) * e
        elif cue_id == "soft-exit":
            s = 0.35 * tone(f, t) * e + 0.2 * tone(f * 1.5, t) * e * math.exp(-t * 2)
        elif cue_id == "night-close":
            s = 0.4 * tone(f, t) * e + 0.2 * tone(f * 1.01, t, 0.4) * e
        elif cue_id == "gentle-ping":
            s = 0.55 * tone(f, t) * math.exp(-t * 6) + 0.2 * tone(f * 2, t) * math.exp(-t * 9)
        elif cue_id == "double-beat":
            hit1 = math.exp(-max(0, t) * 12) if t < 0.35 else 0
            hit2 = math.exp(-max(0, t - 0.18) * 12) if t >= 0.18 else 0
            s = 0.5 * tone(f, t) * hit1 + 0.45 * tone(f * 1.25, t) * hit2
        elif cue_id == "rise":
            sweep = f * (0.6 + 1.1 * min(1.0, t / 0.7))
            s = 0.4 * tone(sweep, t) * e + 0.2 * tone(sweep * 2, t) * e
        elif cue_id == "marker":
            s = 0.5 * tone(f, t) * math.exp(-t * 7)
            if 0.15 < t < 0.35:
                s += 0.25 * tone(f * 0.5, t) * e
        elif cue_id == "lane-nudge":
            s = 0.35 * tone(f, t) * e + 0.25 * tone(f * 1.33, t) * env_adsr(t - 0.05, dur)
        elif cue_id == "harbor-bell":
            s = (0.4 * tone(f, t) + 0.28 * tone(f * 2.76, t) + 0.16 * tone(f * 5.4, t)) * e
            s *= 0.7 + 0.3 * math.sin(2 * math.pi * 5 * t)
        elif cue_id == "coast-wind":
            noise = (hash(i * 97) % 2000) / 2000.0 - 0.5
            s = noise * 0.55 * e * (0.5 + 0.5 * math.sin(2 * math.pi * 0.7 * t)) + 0.12 * tone(f, t) * e
        elif cue_id == "summit-ping":
            s = (0.45 * tone(f, t) + 0.25 * tone(f * 1.5, t) + 0.15 * tone(f * 3, t)) * math.exp(-t * 6)
        else:
            s = 0.4 * tone(f, t) * e
        out[i] = max(-0.95, min(0.95, s * 0.85))
    fade = int(0.01 * sr)
    for i in range(fade):
        out[i] *= i / fade
        out[-1 - i] *= i / fade
    return out


SOUND_CATALOG = [
    ("soft-chime", 880), ("low-pulse", 220), ("ignition", 440), ("glass-tap", 1320),
    ("spark-line", 990), ("end-route", 330), ("power-down", 180), ("soft-exit", 520),
    ("night-close", 260), ("gentle-ping", 990), ("double-beat", 660), ("rise", 740),
    ("marker", 1100), ("lane-nudge", 550), ("harbor-bell", 660), ("coast-wind", 190),
    ("summit-ping", 1180),
]


def main():
    VEHICLES.mkdir(parents=True, exist_ok=True)
    MODELS.mkdir(parents=True, exist_ok=True)
    SOUNDS.mkdir(parents=True, exist_ok=True)

    print("Generating vehicle artwork kinds…")
    for kind, palette in PALETTES.items():
        img = render_vehicle(kind, palette)
        path = VEHICLES / f"{kind}.png"
        img.save(path, "PNG", optimize=True)
        print(f"  {path.relative_to(ROOT)} ({path.stat().st_size // 1024} KB)")

    print("Generating per-model heroes…")
    for model_id, (kind, palette) in MODEL_THEMES.items():
        short = model_id.split("-", 1)[-1]
        img = render_vehicle(kind, palette, label=short)
        path = MODELS / f"{model_id}.png"
        img.save(path, "PNG", optimize=True)
        print(f"  {path.relative_to(ROOT)} ({path.stat().st_size // 1024} KB)")

    print("Generating sound cues…")
    for cue_id, freq in SOUND_CATALOG:
        samples = synth_cue(cue_id, freq)
        path = SOUNDS / f"{cue_id}.wav"
        dur = write_wav(path, samples)
        print(f"  {path.relative_to(ROOT)} {dur:.2f}s")

    print("Done.")


if __name__ == "__main__":
    main()
