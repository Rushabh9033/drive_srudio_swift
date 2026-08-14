# DriveStudio Asset Generation Prompt

Use this spec to generate library assets. Output must be valid Swift code that drops directly into `Runner/WidgetLibrarySheet.swift` inside a `LibraryItem(name: ..., layers: [ ... ])` array.

---

## 1. The data model (WidgetLayer)

Argument order in the memberwise initializer is **fixed**. Use exactly this:

```swift
WidgetLayer(
    id: UUID().uuidString,
    kind: "...",
    label: "...",      // optional — for "shape" kinds: "rect" | "circle" | "ring"
    text: "...",       // optional — for "text" / "clock" / "date" kinds
    src: "...",        // optional — for "image" kind (use "template_car")
    x: ..., y: ..., w: ..., h: ...,
    fontSize: ...,     // optional — only for text-like kinds
    weight: ...,       // optional — 400|500|600|700|800
    align: "...",      // optional — "left" | "center" | "right"
    color: "......",   // 6-char hex, NO leading "#"
    opacity: ...,      // 0.0 ... 1.0 — optional
    radius: ...,       // corner radius for "rect", ring-radius for "circle"/"ring" — optional
    strokes: nil,
    format: nil
)
```

- `id` is always `UUID().uuidString`.
- `strokes` and `format` are advanced — pass `nil` unless you specifically need a custom date format.

---

## 2. Coordinate system (CRITICAL — read this)

- All coordinates are in a **0–100 design space** where 100 = the full widget canvas (340 pt on screen).
- **`x` / `y` = top-left corner of the layer's bounding box.** Not the center.
- `w` and `h` are the layer's width / height, also in 0–100 units.
- A layer that fills the canvas is `x:0, y:0, w:100, h:100`.
- A centered 80%-wide label is `x:10, y:..., w:80, h:...`.

---

## 3. Supported `kind` values

| kind | required fields | notes |
|------|-----------------|-------|
| `"text"` | `text`, `fontSize`, `weight`, `align`, `color` | Static text |
| `"clock"` | `fontSize`, `weight`, `align`, `color` | Live current time |
| `"date"` | `fontSize`, `weight`, `align`, `color` | Live current date |
| `"battery"` | `fontSize`, `weight`, `align`, `color` | Live battery % |
| `"speed"` | `fontSize`, `weight`, `align`, `color` | Live speed (km/h) |
| `"vehicle_name"` | `text` (optional), `fontSize`, `weight`, `align`, `color` | Live vehicle label |
| `"analog"` | `color`, `opacity` | Analog clock face (rendered by `AnalogClockView`) |
| `"image"` | `src` | Use `src: "template_car"` for the car silhouette |
| `"shape"` | `label`, `color`, `opacity`, `radius` | `label` is `"rect"` \| `"circle"` \| `"ring"` |

`label: "ring"` is a circle outline (stroke only). `label: "circle"` is filled.

---

## 4. Weight values

`400` Regular · `500` Medium · `600` Semibold · `700` Bold · `800` Heavy · use `900` for the heaviest display feel if you want — it maps to `.heavy`.

---

## 5. Colors

- 6-character hex, **uppercase**, no `#`.
- Examples: `"FFFFFF"` white, `"0A0A0F"` near-black, `"FF6B35"` orange, `"22D3EE"` cyan, `"FACC15"` amber, `"DC2626"` red, `"22C55E"` green, `"A855F7"` purple, `"0EA5E9"` sky, `"94A3B8"` slate, `"FBCFE8"` pink, `"F5DEB3"` wheat, `"B08D57"` bronze, `"D4AF37"` gold.

---

## 6. The "asset" wrapper — `LibraryItem`

Every asset is one `LibraryItem` with a name + an array of layers. To make a multi-layer asset **behave as a single unit** on the canvas (move/resize/delete together), set the same `groupId` UUID on every layer that belongs to it:

```swift
let assetGroup = UUID().uuidString

LibraryItem(name: "My Asset", layers: [
    WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect",
                x: 0, y: 0, w: 100, h: 100, color: "0A0A0F", opacity: 1.0, radius: 22,
                groupId: assetGroup),
    WidgetLayer(id: UUID().uuidString, kind: "text", text: "HELLO",
                x: 10, y: 40, w: 80, h: 20, fontSize: 18, weight: 800,
                align: "center", color: "FFFFFF", groupId: assetGroup)
])
```

> **For single-layer assets you can omit `groupId` entirely.**

---

## 7. The wrapper macro — output format

Wrap your batch in this block. Every asset goes inside one `LibraryItem(...)` literal:

```swift
LibraryItem(name: "<display name>", layers: [
    WidgetLayer(...),
    WidgetLayer(...),
    ...
])
```

---

## 8. Full working example — a 4-layer "Racing HUD" speedometer asset

```swift
let racingGid = UUID().uuidString

LibraryItem(name: "Racing HUD Speed", layers: [
    WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect",
                x: 0, y: 0, w: 100, h: 100, color: "000000", opacity: 1.0, radius: 22,
                groupId: racingGid),
    WidgetLayer(id: UUID().uuidString, kind: "shape", label: "rect",
                x: 4, y: 4, w: 92, h: 92, color: "0F0F0F", opacity: 1.0, radius: 18,
                groupId: racingGid),
    WidgetLayer(id: UUID().uuidString, kind: "text", text: "RACING",
                x: 10, y: 12, w: 80, h: 7, fontSize: 8, weight: 800,
                align: "left", color: "DC2626", groupId: racingGid),
    WidgetLayer(id: UUID().uuidString, kind: "speed",
                x: 10, y: 24, w: 80, h: 30, fontSize: 32, weight: 900,
                align: "center", color: "FFFFFF", groupId: racingGid),
    WidgetLayer(id: UUID().uuidString, kind: "text", text: "KM/H",
                x: 10, y: 56, w: 80, h: 6, fontSize: 7, weight: 800,
                align: "center", color: "FB923C", groupId: racingGid)
])
```

---

## 9. Layout tips (so assets actually look good in 340pt)

- **Safe zone:** keep important content inside `x:6 … x:94, y:6 … y:94` so it doesn't clip the rounded corners.
- **Stack from top to bottom:** if you want three vertical zones (label / big number / unit), use `y:8–14` for label, `y:24–60` for the big number (`h ≈ 30–36`), `y:64–72` for the unit.
- **Horizontal split:** use `x:4–50` for left half and `x:50–96` for right half, each with `w:46`.
- **Font scale:** `fontSize: 8–10` for tiny labels, `12–16` for secondary values, `22–32` for hero numbers, `36–52` for full-bleed displays.
- **Stroke widths:** a 1-px hairline uses `h: 1` or `h: 2` on a colored rect — that's the trick for dividers.
- **Ring/circle overlap:** stack a filled `circle` then a smaller `circle` on top to fake a ring if you need a different thickness than `ring` provides.
- **Group everything visual together** with one shared `groupId` UUID, including background fills, so the user can drag the whole asset as one piece.

---

## 10. Hand it back to me

When you give me your output, just paste the `LibraryItem(name: "...", layers: [ ... ])` blocks (or a whole `SectionView(title: "...", items: [...])` block if you're making a whole new category). I'll wire it into `Runner/WidgetLibrarySheet.swift`, build, and install on your iPhone.
