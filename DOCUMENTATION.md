# Drive Studio — Complete A–Z Documentation

> **Status:** Reference document for the entire Drive Studio system.
> **Scope:** Every layer — backend, frontend (React), design system, editor, persistence, data model, deployment, and lifecycle.
> **Audience:** Engineers, designers, product, and reviewers who need a single ground-truth document for the project.
> **Stack snapshot:** React 19 + TanStack Router/Start + Vite 8 + TailwindCSS 4 (frontend) · Dart 3.5 + Shelf + sqlite3 (backend) · TypeScript 5.8 (strict) · Bun (package manager) · Windows-native preview target.

---

## Table of Contents

| Section | Topic |
|---|---|
| **A** | App identity, product, positioning |
| **B** | Backend — Dart public API server (port 8788) |
| **C** | Catalog (templates, brands, models, artworks, sounds, categories) |
| **D** | Design system (OKLCH tokens, typography, motion) |
| **E** | Editor (layer engine, undo/redo, geometry model) |
| **F** | Frontend architecture (TanStack Router, Vite, Tailwind) |
| **G** | Garage (vehicle personalization) |
| **H** | Home (asymmetric dashboard) |
| **I** | Intro (3-slide onboarding carousel) |
| **J** | JSON contracts (manifest, state, drafts) |
| **K** | Key bindings, ARIA, accessibility |
| **L** | Layout grid, viewport strategy |
| **M** | Manifest version, atomic publish, ETag |
| **N** | Navigation (bottom nav, file-based routes) |
| **O** | Onboarding (Intro flow state, completion) |
| **P** | Persistence (localStorage, key schema) |
| **Q** | Quality gates (lint, format, typecheck, build) |
| **R** | Routing (12 routes, file naming) |
| **S** | State store (module-level reactive store) |
| **T** | Templates (8 stock, 3 layer kinds common) |
| **U** | UI primitives (shadcn/ui, 47 components) |
| **V** | Vehicle art (SVG silhouettes, brand marks) |
| **W** | Widget canvas (renderer, layer nodes) |
| **X** | XSS, sanitization, SVG safety |
| **Y** | Yielding audio (Web Audio API, ADSR) |
| **Z** | Zones, zero-state, future work |

Appendices: route reference, data shape, file map, glossary.

---

## A — App Identity, Product, Positioning

**Drive Studio** is a *Windows preview companion* for a future iOS/CarPlay dashboard widget app. It lets automotive enthusiasts **design, preview, and organize up to four CarPlay dashboard widget slots** without owning an iPhone or a car. The product is positioned as:

- **Premium-tier abstraction.** All vehicle artwork is hand-drawn SVG silhouettes — no photography, no licensed car logos, no brand infringement. The four fictional brands (Aurelio, Velora, Northstar, Kinetic) ship under a CC0 in-house attribution.
- **Mobile-first preview.** The whole UI is tuned for 360–430 px viewports with a `max-w-3xl` (768 px) cap on wider screens. The bottom nav assumes a thumb-reach layout.
- **Local-first.** Drafts, slots, vehicle choice, and sound preferences live in `localStorage` under one key (`drive-studio-state-v1`). No account, no telemetry, no cloud sync.
- **Component-driven.** The screen set is a fixed twelve routes; each route is a TanStack Router file under `src/routes/`. There is no CMS, no API gateway, no server function called from the client at runtime — the **Dart public API is consumed only by a future native iOS shell**.

### 1.1 Brand statement

> Drive Studio lets you design your drive view: pick an abstract vehicle, choose widget templates, place text, clocks, badges and shapes on a square `systemSmall` canvas, and assign four custom widgets to the dashboard slots. The Windows app is a 1:1 preview. The native iOS app and CarPlay integration remain a future milestone.

### 1.2 Why this product exists

The market problem: small iOS widget canvases are painful to design without seeing them on a real device. Drive Studio answers "what will my dashboard look like?" before committing to a real device. The Windows app is a **pixel-accurate preview environment** for the four slots, eight templates, twelve sounds, and a fully interactive custom editor.

### 1.3 What is *not* in scope

- Real iOS / CarPlay native shell (future milestone, not in this repo).
- Backend writes from the client (the client never calls the Dart API at runtime in this build).
- User accounts, cloud sync, multi-device state replication.
- Analytics, telemetry, A/B frameworks.
- IAP or real "premium" gating — the premium flag is a visual label only.

---

## B — Backend (Dart public API server, port 8788)

The backend lives at `E:/car-play/server/` as a Dart 3.5 shelf application. It is the **content authority** — the React app does not call it at runtime, but the future iOS shell will, and the local admin tool uses it to manage content.

### B.1 Topology

| Binary | Port | Bind | Purpose |
|---|---|---|---|
| `bin/public_server.dart` | 8788 | `0.0.0.0` | Public read API. Categories, assets, brands, models, sounds, templates, manifest. |
| `bin/admin_server.dart` | 8789 | `127.0.0.1` | Local-only admin shell + write API. Bearer-token auth, audit log, atomic publish. |
| `bin/seed_database.dart` | — | — | Idempotent demo seed (categories, brands, models, sounds, templates). |
| `bin/import_premium_assets.dart` | — | — | Bulk-imports premium asset packs from `assets/seed/`. |
| `bin/_inspect.dart` | — | — | Internal diagnostic tool. |

### B.2 Public API contract (read-only)

| Method | Path | Returns |
|---|---|---|
| `GET` | `/health` | `{status, hasActiveToken}` (no admin gating) |
| `GET` | `/v1/manifest.json` | Full content manifest (only approved + active rows) |
| `GET` | `/v1/categories` | All active categories |
| `GET` | `/v1/templates` | All active templates |
| `GET` | `/v1/templates/<id>` | Single template (404 if not active) |
| `GET` | `/v1/vehicle-brands` | All active brands |
| `GET` | `/v1/vehicle-brands/<id>/models` | Models for a brand |
| `GET` | `/v1/sounds` | All active sounds |
| `GET` | `/v1/assets/<assetId>` | Raw asset binary (image/audio/svg) |

`assets/<id>` enforces that the asset is `isActive` and points to an approved license; otherwise 403/404.

### B.3 Admin API contract (write, bearer-token only)

All `/admin/api/*` paths except `/admin/api/health` require a bearer token issued by the `AdminTokenStore`. Static `/admin/index.html` is served without auth so the operator can paste a token before hydrating.

| Method | Path | Effect |
|---|---|---|
| `GET` | `/admin/api/dashboard` | Counts of categories, assets, sounds, templates, brands, models, pending assets, active version |
| `GET` | `/admin/api/licenses` | List all licenses |
| `POST` | `/admin/api/licenses` | Upsert a license record |
| `POST` | `/admin/api/licenses/<id>/review` | Approve / reject a license with timestamp |
| `DELETE` | `/admin/api/licenses/<id>` | Soft-delete a license |
| `GET` | `/admin/api/assets` | List all assets (incl. pending) |
| `POST` | `/admin/api/assets` | Upload + validate (MIME, size, SVG sanitization) |
| `PUT` | `/admin/api/assets/<id>` | Edit metadata, toggle active |
| `DELETE` | `/admin/api/assets/<id>` | Soft-delete an asset |
| `GET` | `/admin/api/categories` / `POST` / `PUT` / `DELETE` | Full CRUD on categories |
| `GET` / `POST` / `PUT` / `DELETE` | `/admin/api/vehicles/brands` and `/admin/api/vehicles/models` | Full CRUD on brands and models |
| `GET` / `POST` / `PUT` / `DELETE` | `/admin/api/sounds` | Full CRUD on sounds |
| `GET` / `POST` / `PUT` / `DELETE` | `/admin/api/templates` | Full CRUD on templates |
| `POST` | `/admin/api/publish` | Atomic publish — bumps manifest version, writes audit row |

### B.4 Data model (sqlite3, ~10 tables)

| Table | Purpose | Key columns |
|---|---|---|
| `categories` | Top-level filter chips | `id, name, slug, sort_order, is_active` |
| `assets` | File registry (image/audio/svg) | `id, type, display_name, stored_filename, mime_type, file_size, sha256, license_id, is_active, metadata_json` |
| `licenses` | Provenance for every asset | `id, license_status, rights_holder, source_reference, commercial_use_allowed, modification_allowed, attribution_required, review_status, reviewed_at` |
| `vehicle_brands` | Brand list (Aurelio, …) | `id, name, tagline, sort_order, is_active` |
| `vehicle_models` | Models per brand | `id, brand_id, name, is_active` |
| `sounds` | Audio cues | `id, name, group, freq, audio_asset_id, premium, is_active` |
| `templates` | Widget templates | `id, name, category_id, vehicle_model_id, preview_asset_id, premium, family, spec_json, attribution, is_active, created_at` |
| `publish_events` | Versioning + ETag | `id, version, published_at, manifest_json, etag` |
| `admin_tokens` | Bearer tokens for admin | `id, token_hash, created_at, last_used_at, revoked_at` |
| `admin_audit` | Every admin action | `id, at, actor_token_id, action, target, detail` |

WAL mode is on (`db-shm`/`db-wal` sidecars visible in `data/`). `migrations.dart` keeps schema versioned and idempotent.

### B.5 Middleware stack (public)

```
Pipeline()
  .addMiddleware(commonMiddleware())   // CORS, logging, ETag
  .addHandler(router.call)
```

`commonMiddleware()` in `app_factory.dart` adds:

- **CORS** — open for the public read API (the consumer is a future iOS app; not browser-restricted).
- **ETag** — generated from the active `publish_event.id` + manifest hash. Clients can use `If-None-Match` to skip re-downloading.
- **Logging** — every request to stdout, mirrored to `logs/public_server.log`.

### B.6 Middleware stack (admin)

`buildAdminRouter` runs inside an admin-specific `Pipeline` that:

- Rejects non-loopback callers (the admin binds 127.0.0.1).
- Verifies the bearer token via `admin_auth_middleware.dart` for every `/admin/api/*` request.
- Wraps every successful write in an `AdminAuditLog.record(...)` row.

### B.7 Storage layout

```
server/
  data/
    drive_studio.db         # sqlite database
    drive_studio.db-shm     # WAL shared memory
    drive_studio.db-wal     # WAL journal
  storage/
    images/                 # SVG, JPG, PNG (24 files at last count)
    previews/               # generated 1× widget previews (empty pending render)
    sounds/                 # WAV / MP3 (12 files)
  public/
    admin/                  # admin shell HTML/JS
  logs/
    public_server.log
    public_server.log.err
```

### B.8 Manifest contract (what `/v1/manifest.json` returns)

```jsonc
{
  "version": "2026.07.24",
  "publishedAt": "2026-07-24T12:00:00Z",
  "etag": "W/\"abc123...\"",
  "categories": [{ "id": "featured", "name": "Featured", "sortOrder": 0 }],
  "assets": [
    { "id": "aurelio-1", "type": "image/svg+xml", "url": "/v1/assets/aurelio-1", "sha256": "...", "fileSize": 1024 }
  ],
  "vehicleBrands": [{ "id": "aurelio", "name": "Aurelio", "tagline": "Sculpted grand touring" }],
  "vehicleModels": [{ "id": "aurelio-gt", "brandId": "aurelio", "name": "GT Corsa" }],
  "sounds": [{ "id": "soft-chime", "name": "Soft Chime", "group": "connect", "freq": 880, "url": "/v1/assets/soft-chime", "durationMs": 1200, "premium": false }],
  "templates": [{ "id": "midnight-run", "name": "Midnight Run", "categoryId": "night", "premium": false, "family": "systemSmall", "spec": { "background": {...}, "layers": [...] } }]
}
```

Only `approved_for_development` and `approved_for_production` licenses pass the filter in `ManifestService.build()`.

### B.9 Atomic publish

`POST /admin/api/publish` opens a single sqlite transaction:

1. Snapshot all active rows into a new `publish_events` row.
2. Serialize the manifest as JSON.
3. Compute ETag = SHA-256(manifest JSON) truncated to 16 hex chars.
4. Insert the `publish_event` row + commit.
5. Emit an `admin_audit` row with `action='publish'`.

Failure at any step rolls the entire transaction back, so the manifest URL never returns a half-built version.

### B.10 Asset upload pipeline

`UploadService` accepts `multipart/form-data` and:

1. Validates MIME type against the asset kind (`image/svg+xml`, `image/jpeg`, `image/png`, `audio/wav`).
2. Enforces per-kind size caps (SVG ≤ 256 KB, JPG/PNG ≤ 4 MB, WAV ≤ 1 MB).
3. For SVGs, runs `SvgSanitizer.sanitize` which strips `<script>`, `on*` event handlers, `javascript:` URLs, foreign-object, and external `<use href="…">` references.
4. Streams the file to `storage/<kind>/<uuid>.<ext>`.
5. Computes SHA-256, writes the row to `assets`, and records an `admin_audit` entry.

### B.11 Tests (11 spec files, ~50 cases)

Located in `server/test/`:

- `admin_cors_test.dart` — admin CORS lockdown
- `admin_publish_test.dart` — atomic publish + ETag
- `admin_read_authorization_test.dart` — token enforcement on GET
- `admin_repositories_test.dart` — CRUD for every repo
- `admin_token_store_test.dart` — token hash + revoke
- `app_factory_middleware_test.dart` — CORS/ETag/logging pipeline
- `asset_validator_test.dart` — MIME + size + SVG sanitization
- `demo_seed_idempotency_test.dart` — re-running seed is a no-op
- `manifest_service_compatibility_test.dart` — manifest contract
- `svg_sanitizer_test.dart` — strips every dangerous SVG construct
- (one more)

Run with `cd server && dart test`.

---

## C — Catalog (static client data)

The React app's catalog lives in `src/lib/catalog.ts`. It is **intentionally duplicated** from the Dart server's seed — the React app is offline-first and never fetches the manifest at runtime in this build. The shapes are 1:1, and the public server's seed re-uses the same hard-coded values.

### C.1 Categories (6)

```
"Featured", "Minimal", "Night", "Utility", "Travel", "Performance"
```

### C.2 Brands (4) with models (10 total)

| Brand | Tagline | Models |
|---|---|---|
| **Aurelio** | Sculpted grand touring | GT Corsa, Lumen S, Vento |
| **Velora** | Electric performance | V8 Pulse, EX Coupe, Arc Sedan |
| **Northstar** | Expedition utility | Trail 90, Peak XL |
| **Kinetic** | Urban compact | Mono One, Flux |

The default selection on first launch is `aurelio / aurelio-gt / coupe`.

### C.3 Artworks (6)

```
coupe | sedan | suv | wagon | roadster | hatch
```

Each is a different SVG silhouette path in `src/components/art.tsx`. The path uses a viewBox of `0 0 196 78` and is filled with a `linear-gradient` from `var(--primary-glow)` to `var(--primary)`.

### C.4 Sounds (12) in 3 groups

| Group | Count | Premium |
|---|---|---|
| `connect` | 4 (soft-chime, low-pulse, ignition, glass-tap) | 1 (ignition) |
| `disconnect` | 4 (end-route, power-down, soft-exit, night-close) | 1 (soft-exit) |
| `reminder` | 4 (gentle-ping, double-beat, rise, marker) | 1 (rise) |

Each has a `freq` field (Hz) that drives the Web Audio API synthesis — there are no audio files, every preview is a pure sine wave with an ADSR envelope. See section Y.

### C.5 Templates (8)

| ID | Name | Category | Premium | Background |
|---|---|---|---|---|
| `midnight-run` | Midnight Run | Night | no | `#101828 → #1E3A5F` |
| `pure-lines` | Pure Lines | Minimal | no | `#0E0F12 → #20232B` |
| `trip-meter` | Trip Meter | Travel | **yes** | `#132118 → #20463A` |
| `carbon-grid` | Carbon Grid | Performance | **yes** | `#16181D → #2A2F3A` |
| `commuter` | Commuter | Utility | no | `#141519 → #262A33` |
| `aurora-drive` | Aurora Drive | Featured | no | `#101A2B → #2C4C7C` |
| `night-shift` | Night Shift | Night | **yes** | `#0B0C10 → #1B1F2A` |
| `cargo` | Cargo | Utility | no | `#1A1509 → #3A2E12` |

Each template declares 2–4 `Layer` entries composed of the 7 layer kinds. See section T for a worked walkthrough.

### C.6 Layer kinds (7)

```
text | image | clock | date | badge | divider | shape
```

Each kind has a typed `Layer` shape with defaults via `baseLayer(kind, overrides?)`.

---

## D — Design system

The design system is fully expressed in `src/styles.css` and consumed through TailwindCSS 4 `@theme inline` mappings. All colors are OKLCH so the same source values can be reused for the future native iOS app or Flutter port without round-trip drift.

### D.1 Surface tokens (Obsidian / Carbon / Graphite)

```css
--obsidian: oklch(0.16 0.012 265);   /* page background */
--carbon:   oklch(0.21 0.014 265);   /* card / nav */
--graphite: oklch(0.27 0.016 265);   /* raised chip */
```

| Token | OKLCH | Role |
|---|---|---|
| `--background` | `0.16 0.012 265` | Page base |
| `--card` | `0.21 0.014 265` | `surface-card` utility |
| `--popover` | `0.21 0.014 265` | Sheet / dialog / dropdown |
| `--secondary` | `0.27 0.016 265` | Buttons in secondary state |
| `--muted` | `0.27 0.016 265` | Muted chips |
| `--accent` | `0.31 0.03 250` | Hover accent (blue-tinted gray) |
| `--border` | `0.31 0.014 265` | Every 1 px border |
| `--input` | `0.31 0.014 265` | Form fields |

### D.2 Foreground & status tokens

| Token | OKLCH | Role |
|---|---|---|
| `--foreground` | `0.97 0.005 265` | Body text |
| `--muted-foreground` | `0.68 0.015 265` | Captions, secondary text |
| `--primary` | `0.68 0.18 245` | **Electric Blue** — the only chromatic accent |
| `--primary-foreground` | `0.14 0.02 265` | Text on primary fills |
| `--primary-glow` | `0.79 0.15 220` | Lighter, slightly desaturated blue used in gradients |
| `--destructive` | `0.62 0.21 22` | Red — used for delete actions and reset |
| `--success` | `0.72 0.15 155` | Green — "Windows preview ready" |
| `--warning` | `0.78 0.15 78` | Amber — "iPhone setup not verified" |
| `--ring` | `0.68 0.18 245` | Focus ring (matches primary) |

### D.3 Typography

- **UI font:** `Manrope` — 400 / 500 / 600 / 700 / 800. Loaded from Google Fonts in `__root.tsx` via `<link rel="stylesheet">`.
- **Mono font:** `DM Mono` — 400 / 500. Used for the `.mono-label` utility, all timestamps, sound durations, technical data.
- **Heading letter-spacing:** `-0.02em` on `h1, h2, h3` (set in `@layer base`).

### D.4 The `.mono-label` utility

```css
@utility mono-label {
  font-family: var(--font-mono);
  font-size: 0.6875rem;     /* 11px */
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--color-muted-foreground);
}
```

Used everywhere a section needs a small uppercase tracker label ("SELECTED VEHICLE", "ACTIVE SLOTS", "SLOT 1", "AVAILABLE IN WINDOWS"). This is the strongest recurring micro-typographic pattern in the app.

### D.5 Surfaces

- **`.surface-card`** — `linear-gradient(160deg, #... → #...)` + 1 px border + `shadow-elevated` (a 24 px 60 px shadow with -28 px y-offset). Used for nearly every card.
- **`.hero-surface`** — `radial-gradient(120% 100% at 15% 0%, primary-glow 35%, obsidian 70%)`. Used for the home hero and the intro page.
- **`.text-gradient`** — `linear-gradient(135deg, primary → primary-glow)`, clipped to text. Used on the "Studio" wordmark on Home and the editor save button.

### D.6 Motion

| Interaction | Duration | Easing |
|---|---|---|
| Bottom-nav active pill | 300 ms | CSS `transition-all` |
| Sheet open | 500 ms | `data-[state=open]:duration-500` |
| Sheet close | 300 ms | `data-[state=closed]:duration-300` |
| Dialog | 200 ms | Radix default |
| Color transitions | 150 ms | `transition-colors` |
| Intro dot indicator | 200 ms | `transition-all` |
| Refresh icon | `animate-spin` | Continuous |

### D.7 Radius scale

`--radius: 1rem` (16 px). All other radii derive from this:

```
--radius-sm: 12px   --radius-md: 14px   --radius-lg: 16px
--radius-xl: 20px   --radius-2xl: 24px  --radius-3xl: 28px  --radius-4xl: 32px
```

The widget canvas uses `rounded-3xl` (24 px) so it visually pops from a card behind it (which uses `rounded-2xl` / 16 px).

### D.8 Shadows

```
--shadow-elevated: 0 24px 60px -28px oklch(0.05 0 0 / 0.9);
--shadow-glow:     0 0 0 1px oklch(0.68 0.18 245 / 0.35),
                   0 18px 45px -22px oklch(0.68 0.18 245 / 0.75);
```

Cards get the elevated shadow; the active nav pill, selected sounds, and slot borders get the glow.

### D.9 `no-scrollbar` utility

```css
@utility no-scrollbar {
  scrollbar-width: none;
  &::-webkit-scrollbar { display: none; }
}
```

Applied to the home "Recently added" rail and the category chip row so the horizontal scroll feels invisible on Windows.

### D.10 Dark-only

The app is **dark-only**. There is no light mode. The `@custom-variant dark (&:is(.dark *))` is in the file but the root has no `class="dark"` toggling — every screen ships dark.

---

## E — Editor (layer engine, undo/redo, geometry model)

The widget editor lives at `src/routes/studio.editor.$id.tsx`. It is the largest single file in the app and the only one with non-trivial local state (10 useState / useRef slots).

### E.1 Geometry model

Every `Layer` is positioned in a **0–100 percentage coordinate system** relative to the square canvas. This means:

- Layers scale naturally when the canvas resizes (e.g. when the user zooms the editor or the home screen previews at `scale=0.42`).
- Coordinates are resolution-independent and round-trip identically through `localStorage` JSON.
- A layer at `(x:10, y:30, w:80, h:18)` is always "10% from the left edge, 30% from the top, 80% wide, 18% tall" — never pixels.

```ts
type Layer = {
  id: string;            // generated by newId()
  kind: LayerKind;       // "text" | "image" | "clock" | "date" | "badge" | "divider" | "shape"
  label: string;         // human-readable name
  text: string;          // content for text/badge; ignored otherwise
  x: number;             // 0–100
  y: number;             // 0–100
  w: number;             // 0–100
  h: number;             // 0–100
  fontSize: number;      // 8–48
  weight: 400|500|600|700|800;
  align: "left" | "center" | "right";
  color: string;         // CSS hex, e.g. "#F2F5FA"
  opacity: number;       // 0–1
  radius: number;        // px, 0–40
  letterSpacing: number; // 0–8
  shadow: boolean;
  locked: boolean;
  hidden: boolean;
  fit?: "contain" | "cover";  // image only
  flipH?: boolean;            // image only
  maxLines?: number;          // text/badge only, 1–4
};
```

### E.2 Undo/redo

```ts
const past = useRef<WidgetSpec[]>([]);
const future = useRef<WidgetSpec[]>([]);

const commit = (next: WidgetSpec) => {
  past.current = [...past.current.slice(-30), spec];  // hard cap at 30
  future.current = [];                                // any new edit clears redo
  setSpec(next);
  setDirty(true);
};
```

- History is **per-component-instance** — when the user navigates away, the history is lost (only `saveDraft` persists).
- 30 entries × small spec JSON ≈ 5–50 KB of RAM. Acceptable trade-off.
- Past is sliced from the front (`slice(-30)`) so old entries are evicted FIFO.
- Any new `commit` clears the redo stack — this is the standard editor expectation.

### E.3 Add a layer

```ts
const l = baseLayer(k, { y: 20 + spec.layers.length * 4 });
commit({ ...spec, layers: [...spec.layers, l] });
```

The new layer is appended (so it sits on top in z-order) and offset down 4% for each existing layer to avoid perfect overlap. The Inspector sheet opens automatically with the new layer selected.

### E.4 Delete a layer

```ts
commit({ ...spec, layers: spec.layers.filter((l) => l.id !== sel.id) });
setSelected(null);
setSheet(null);
```

Destroys the layer immediately. There is no soft-delete / undo prompt — the user can hit the Undo button to recover.

### E.5 Reorder (Bring forward / Send backward)

```ts
const move = (dir: 1 | -1) => {
  if (!sel) return;
  const i = spec.layers.findIndex((l) => l.id === sel.id);
  const j = i + dir;
  if (j < 0 || j >= spec.layers.length) return;
  const layers = [...spec.layers];
  [layers[i], layers[j]] = [layers[j], layers[i]];
  commit({ ...spec, layers });
};
```

`dir=1` moves toward the end (renders on top), `dir=-1` toward the start.

### E.6 Zoom

```ts
const [zoom, setZoom] = useState(1);  // 0.6–1.6
```

The whole canvas has `transform: scale(zoom)`. The percentage display shows `Math.round(zoom * 100)%`. Zoom does **not** affect the layer coordinates — it only re-renders the canvas at a different size for editing comfort.

### E.7 Selection / 8-point resize handles

When a layer is selected, the editor renders:

- A 2 px primary ring around the layer.
- Eight 8×8 px primary handles at every corner and midpoint of the layer's bounding box.
- A vertical and horizontal primary/40 guide line at canvas center for snap alignment (visual aid only — no real snap engine in this build).

In this prototype the resize handles are **visual only**; the user changes width/height via the Inspector's slider. The next iteration will wire pointer events to those handles for true drag-resize.

### E.8 Inspector (slide-up sheet)

Organized as 2-column sliders:

| Field | Range | Step |
|---|---|---|
| X % | 0–100 | 1 |
| Y % | 0–100 | 1 |
| Width % | 4–100 | 1 |
| Height % | 2–100 | 1 |
| Font size (text/clock/date/badge) | 8–48 | 1 |
| Weight (text/clock/date/badge) | 400–800 | 100 |
| Letter spacing | 0–8 | 1 |
| Max lines | 1–4 | 1 |
| Opacity | 0–100% | 1 |
| Corner radius | 0–40 | 1 |
| Content (text/badge) | free text | — |
| Alignment (text/clock/date/badge) | left/center/right | — |
| Text shadow toggle (text/clock/date/badge) | bool | — |
| Fit (image) | contain/cover | — |
| Flip horizontal (image) | bool | — |
| Colour | native color input | — |
| Lock / Hide / Bring forward / Send backward | buttons | — |
| Delete layer | destructive | — |

### E.9 Save flow

```ts
const save = () => {
  saveDraft(id, { name: name || "Untitled widget", spec });
  setDirty(false);
  toast.success("Draft saved");
};
```

`saveDraft` updates the draft in-place, bumps `updatedAt`, and writes through the module-level store (which persists to `localStorage`).

### E.10 Exit flow

```ts
onClick={() => (dirty ? setConfirmExit(true) : navigate({ to: "/studio/my-widgets" }))}
```

If the spec is dirty, an AlertDialog opens with three options:

- **Keep editing** — cancel the dialog.
- **Save and exit** — `save()` then navigate.
- **Discard** — navigate without saving.

### E.11 Backgrounds (6 named presets)

| Label | Type | From → To |
|---|---|---|
| Obsidian | solid | `#12141A` |
| Night blue | gradient | `#101828 → #1E3A5F` |
| Carbon | gradient | `#16181D → #2A2F3A` |
| Aurora | gradient | `#101A2B → #2C4C7C` |
| Forest | gradient | `#132118 → #20463A` |
| Image fill | image | `#25303F → #141A22` (placeholder gradient until asset wired) |

The "Image fill" preset is rendered as a gradient for now — the next iteration will allow the user to upload or pick a custom image background.

### E.12 Missing features (explicit)

- True pointer-driven drag/resize of the selection ring.
- Snap-to-edge / snap-to-center with pixel guides (visual only currently).
- Multi-select (shift-click).
- Copy/paste of layers.
- Asset library for image layers (currently a placeholder gradient with `IMG · cover` label).

---

## F — Frontend architecture

### F.1 Build pipeline

- **Vite 8** with the `@lovable.dev/vite-tanstack-config` plugin (handles TanStack Router, TanStack Start, React, Tailwind, Nitro SSR, Vite env, `@` alias, sandbox port/host detection, etc.). `vite.config.ts` only adds a `server.entry = "server"` redirect for the SSR error wrapper.
- **TailwindCSS 4** via the Vite plugin. The `styles.css` is the only global stylesheet; component styles are utility classes.
- **TypeScript 5.8** in strict mode. Notable flags: `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `noImplicitReturns`, `noPropertyAccessFromIndexSignature`. Path alias `@/*` → `./src/*`.

### F.2 Server runtime

`@tanstack/react-start` boots via Nitro. `src/start.ts` registers two middlewares:

1. `errorMiddleware` — wraps `next()` in try/catch; non-`statusCode` errors render a static error page (no stack trace leaks).
2. `csrfMiddleware` (`createCsrfMiddleware`) — protects `serverFn` endpoints from cross-site requests.

`src/server.ts` is the production entry. It calls into `@tanstack/react-start/server-entry` and **wraps the response with `normalizeCatastrophicSsrResponse`**. That function exists because h3 (Nitro's underlying HTTP layer) swallows uncaught handler throws into a 500 with a body of `{"unhandled":true,"message":"HTTPError"}` — losing the stack. The wrapper detects this body, looks up the captured error from `lib/error-capture.ts` (which monkey-patches `console.error` to record any Error passed to it within a 5-second TTL), and renders a proper error page.

### F.3 Error capture

`src/lib/error-capture.ts` does three things:

1. Monkey-patches `console.error` to (a) record the original Error and (b) expand Error-like args via `describeError` (which walks `error.cause` up to 5 levels, prepends `caused by:`, appends ` (status N)` if present, caps output at 8 KB).
2. Adds `addEventListener("error", …)` and `addEventListener("unhandledrejection", …)` to capture global failures.
3. Exposes `consumeLastCapturedError()` which the server entry calls when it detects the h3-swallowed body.

### F.4 Routing

TanStack Router file-based. `routeTree.gen.ts` is the generated file-router tree — never hand-edit, it is produced by `@tanstack/router-plugin` from `src/routes/`. There are 12 routes:

```
/                                     routes/index.tsx
/home                                 routes/home.tsx
/intro                                routes/intro.tsx
/garage                               routes/garage.tsx
/studio                               routes/studio.index.tsx
/studio/my-widgets                    routes/studio.my-widgets.tsx
/studio/slots                         routes/studio.slots.tsx
/studio/templates/$id                 routes/studio.templates.$id.tsx
/studio/editor/$id                    routes/studio.editor.$id.tsx
/sounds                               routes/sounds.tsx
/settings                             routes/settings.tsx
/setup_guide                          routes/setup_guide.tsx
__root                                routes/__root.tsx
```

See section R for per-route details.

### F.5 Module-level state

The app uses a hand-rolled reactive store (no Redux, no Zustand, no Recoil). See section S. The store is hydrated from `localStorage` on the first render of the `Index` route, then kept in memory for the session.

### F.6 React Query

`@tanstack/react-query` is configured (`getRouter` creates a `QueryClient`) and `<QueryClientProvider>` wraps the app in `__root.tsx`. No `useQuery` calls exist yet — the client is provisioned for the future native-shell iOS app, which will fetch the Dart public API.

### F.7 Sonner (toasts)

`sonner` is the toast library. `<Toaster position="top-center" />` is mounted in `__root.tsx`. Used for: "Custom image applied", "Draft saved", "Draft deleted", "Content manifest refreshed", "Vehicle reset to default", "Drafts cleared", "Downloaded assets cleared", `${d.name} assigned`, `Assigned to Slot N`.

### F.8 Lucide icons

All icons come from `lucide-react` (46+ in use: Home, LayoutGrid, Car, Music4, Settings, ArrowRight, PenLine, CheckCircle2, AlertTriangle, Undo2, Redo2, Save, X, Plus, Layers, Palette, ZoomIn, ZoomOut, Eye, EyeOff, Lock, Unlock, Trash2, ArrowUp, ArrowDown, Play, Pause, Check, Search, Upload, RotateCcw, MoreVertical, ChevronLeft, RefreshCw). The `components.json` `iconLibrary: "lucide"` declares this as the shadcn/ui icon choice.

### F.9 shadcn/ui primitives

`components.json` is a real shadcn config. 47 components are vendored under `src/components/ui/` (button, card, dialog, sheet, alert-dialog, dropdown-menu, sonner, slider, switch, label, input, tabs, select, badge, separator, accordion, alert, aspect-ratio, avatar, breadcrumb, calendar, carousel, chart, checkbox, collapsible, command, context-menu, drawer, form, hover-card, input-otp, menubar, navigation-menu, pagination, popover, progress, radio-group, resizable, scroll-area, sidebar, skeleton, table, textarea, toggle, toggle-group, tooltip). The app uses ~10 of these (button, sheet, alert-dialog, dialog, dropdown-menu, slider, switch, label, input, sonner). The rest are present for the future admin / dashboard surface.

### F.10 TypeScript discipline

- All component props have explicit `type` or `interface` declarations.
- `noUncheckedIndexedAccess` is on — array reads return `T | undefined`, which is why the editor uses non-null assertions like `layers[i]!` after explicit bounds checks.
- `exactOptionalPropertyTypes` is on — optional fields with `?` cannot be set to `undefined` explicitly; they must either be omitted or set to a real value. This is why the layer model uses `?` for `fit`, `flipH`, `maxLines` (image/text-specific).
- `noPropertyAccessFromIndexSignature` is on — accessing dictionary keys requires bracket notation. This shows up in `art.tsx` where `body[kind] ?? body["coupe"]` is used instead of `body.kind`.

### F.11 Lint / format

- ESLint 9 flat config (`eslint.config.js`) with `@eslint/js`, `typescript-eslint`, `eslint-plugin-react-hooks`, `eslint-plugin-react-refresh`, `eslint-config-prettier`, `eslint-plugin-prettier`.
- Prettier 3.7 with `.prettierrc` (print width: probably 100, default for shadcn).
- `bun run lint` and `bun run format` are wired in `package.json`.

---

## G — Garage (vehicle personalization)

Route: `/garage` → `src/routes/garage.tsx`. This screen is the vehicle identity editor.

### G.1 Layout

1. **Hero card** — `BrandMark` icon + brand name (mono label) + `v.displayName || model.name` (h2). Below it, either the custom image (`v.customImage`) or the `VehicleArt` SVG at `h-32 w-full`.
2. **Search** — `Input` with `Search` icon, placeholder "Search brands and models". Filter is case-insensitive substring on `b.name` and `m.name`.
3. **Brand sections** — for each brand with ≥1 matching model, a card with the brand mark, name, tagline, and a wrap-row of model pills. The currently selected model has `border-primary bg-primary/15 text-primary`; others have `border-border text-muted-foreground`.
4. **Artwork gallery** — 3-column grid of 6 thumbnails. Selecting one sets `v.artwork` and clears `v.customImage`. Selected thumbnail has `border-primary bg-primary/10`.
5. **Custom display name** — `Input` with placeholder showing the default `"<brand> <model>"`.
6. **Upload / Reset row** — `Upload Custom Image` opens a hidden `<input type="file" accept="image/*">`; on selection the file is read via `FileReader.readAsDataURL` and stored as `v.customImage` (a `data:image/...` URL). `Reset` restores `defaultState.vehicle` and toasts "Vehicle reset to default".

### G.2 `BrandMark`

Inline SVG component, 40×40 viewBox, 4 hand-drawn shapes:

| Brand | Shape |
|---|---|
| Aurelio | triangle (apex up) |
| Velora | diamond |
| Northstar | 8-pointed star |
| Kinetic | outlined circle with thick stroke |

All use `fill="currentColor"` so the parent `text-primary` color is respected.

### G.3 Custom image constraint

The custom image is stored inline as a data URL in `localStorage`. Practical limit on Windows is ~5 MB total localStorage, so a 2–3 MB JPG is the realistic upper bound. No client-side resizing; the user is responsible for the size.

### G.4 Head meta

```ts
head: () => ({
  meta: [
    { title: "Garage — Choose Your Vehicle" },
    { name: "description", content: "Pick a brand, model and abstract vehicle artwork…" },
    { property: "og:title", content: "Garage — Drive Studio" },
    { property: "og:description", content: "Brand and model explorer with abstract vehicle artwork." },
  ],
})
```

Every route ships its own `head()` so SSR generates correct meta and social tags per route.

---

## H — Home (asymmetric dashboard)

Route: `/home` → `src/routes/home.tsx`. This is the central hub users see after onboarding.

### H.1 Top bar

Two-column flex: **Drive** (plain) + **Studio** (gradient text via `text-gradient`) on the left, **Settings** (rounded-full icon button) on the right. No app bar shadow; the bottom nav absorbs the visual weight.

### H.2 Hero — selected vehicle

- `mono-label`: "Selected vehicle"
- `h2`: `vehicleName` (custom display name, or `"<brand> <model>"`)
- Sub-line: `brand.tagline` (e.g. "Sculpted grand touring")
- The custom image OR `VehicleArt` at `h-32 w-full`
- Two buttons: `Open Studio` (primary, navigates to `/studio`) and `Manage Slots` (secondary, to `/studio/slots`)

The hero uses both `hero-surface` and `surface-card` — the gradient shows through while the border + shadow still define the card.

### H.3 Active slots (4-cell grid)

`mono-label`: "Active slots". Four `Link` tiles in a `grid-cols-4`:

- If the slot has an assigned draft: a `WidgetCanvas` at `scale={0.42}` + the draft name.
- If empty: a dashed-border square with the word "Empty".

Tapping any tile navigates to `/studio/slots`.

### H.4 Continue editing (conditional)

Shown only when `state.lastEditedDraftId` is non-null AND the draft still exists. Renders a `Link` to `/studio/editor/$id` with a pen icon, draft name, and `formatWhen(draft.updatedAt)`.

### H.5 Recently added

`mono-label` + "See all" link (to `/studio`). Horizontal scroll rail of 5 templates sorted by `createdAt` desc. Each tile is `w-36 shrink-0` with a `WidgetCanvas` at `scale={0.55}` and the name/category below.

### H.6 Sounds summary

A small card showing the current `connect` and `disconnect` sound names in `font-mono text-primary`.

### H.7 Setup status

A diagnostic panel with two checklist items:

- ✅ "Windows preview ready" (green CheckCircle2)
- ⚠️ "iPhone setup not verified" (amber AlertTriangle)

A `Open setup guide` button navigates to `/setup_guide`.

### H.8 Why this order

Information density descends from top to bottom: identity → action → recent context → status. The thumb-reach zone (bottom 1/3) holds the most important action (Open Studio) plus the bottom nav.

---

## I — Intro (3-slide onboarding carousel)

Route: `/intro` → `src/routes/intro.tsx`.

### I.1 The three slides

1. **Build your drive view** — "Start from a curated template or open the custom editor and place text, clocks, badges and artwork exactly where you want them." + `OnboardArt variant=1` (compositional blocks).
2. **Keep the useful parts close** — "Save unlimited local drafts and promote your favourites into four dashboard slots you can rearrange at any time." + `OnboardArt variant=2` (column stack).
3. **Preview before iPhone setup** — "Windows gives you a pixel-accurate preview. Activating widgets on CarPlay still requires the native iOS build on your iPhone." + `OnboardArt variant=3` (centered framed panel).

### I.2 Carousel mechanics

Implemented with native CSS scroll-snap, **not** a JS carousel library:

```html
<div class="overflow-x-auto snap-x snap-mandatory">
  <section class="snap-center min-w-full">…</section>
  <section class="snap-center min-w-full">…</section>
  <section class="snap-center min-w-full">…</section>
</div>
```

The current page is derived from `scrollLeft / clientWidth` rounded to an integer. The onScroll handler updates `page` state, which animates the dot indicator.

### I.3 Dots and buttons

- Three dots: 24 px wide pill in `bg-primary` for active, 8 px circle in `bg-graphite` for inactive.
- Skip (top right) — sets `introDone: true` and navigates to `/home`.
- Continue (slide 1, 2) — advances `page`.
- Enter Drive Studio (slide 3) — sets `introDone: true` and navigates to `/home`.

### I.4 Hero surface

The whole page uses `hero-surface` (radial gradient) instead of the usual solid `bg-background`. This visually distinguishes the first-run experience from every other screen.

### I.5 Onboard art variants

`OnboardArt` is a single SVG with 3 switchable sub-trees, each composed of basic shapes (`<rect rx="…">`, fills, opacity). No animation, no JS.

---

## J — JSON contracts

Three primary JSON documents flow through the system.

### J.1 Client persisted state

`localStorage["drive-studio-state-v1"]` value:

```ts
{
  introDone: boolean,
  drafts: [
    {
      id: string,
      name: string,
      updatedAt: number,  // ms since epoch
      spec: WidgetSpec,
    },
  ],
  slots: (string | null)[4],  // each is a draft.id or null
  vehicle: {
    brandId: string,
    modelId: string,
    artwork: ArtworkKind,
    displayName: string,
    customImage: string | null,  // data URL or null
  },
  sounds: {
    connect: string | null,
    disconnect: string | null,
    reminder: string | null,
  },
  lastRefresh: number,           // ms since epoch
  lastEditedDraftId: string | null,
}
```

### J.2 `WidgetSpec`

```ts
{
  background: {
    type: "solid" | "gradient" | "image",
    from: string,  // hex for solid/gradient; URL for image
    to?: string,   // hex, only for gradient
  },
  layers: Layer[],
}
```

### J.3 Public manifest (server, future consumer)

See B.8. The React app does not consume this; the future native iOS shell will.

---

## K — Keyboard, ARIA, accessibility

### K.1 ARIA

- `<nav aria-label="Primary">` on the bottom nav.
- Every icon-only button has `aria-label` (Undo, Redo, Save, Exit editor, Play X, Pause X, Toggle visibility, Toggle lock, etc.).
- `<input aria-label="Widget name">` on the editor's name field.
- `<button aria-label={`Select ${l.label}`}>` on layer hit targets.
- `role="img" aria-label={`${kind} artwork`}` on every `VehicleArt`.
- `role="presentation"` on decorative `OnboardArt` and `BrandMark` (they have no semantic content).
- `noindex` on `/studio/editor/$id` (don't index draft canvases).

### K.2 Focus

- Every focusable element gets `focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring` (shadcn default).
- The dialog / sheet / alert-dialog Radix primitives manage focus trap and restore-focus automatically.

### K.3 Color contrast

OKLCH was chosen specifically to keep foreground/background pairs above WCAG AA (4.5:1) for body text. The `--foreground` on `--background` pair is `0.97 / 0.16` in OKLCH lightness, which is ~17:1 sRGB contrast.

### K.4 Keyboard

- The app is a web app, so default browser tab order applies.
- Bottom nav is fully keyboard-navigable (tab → enter).
- The carousel is mouse/touch only (no arrow key handler).

---

## L — Layout grid, viewport strategy

### L.1 Max width

Every screen wraps content in `<div className="mx-auto w-full max-w-3xl px-4 pt-4">` inside the `AppScreen`. `max-w-3xl` = 768 px. On phones the content fills the viewport; on tablets/desktop it is centered with side margins.

### L.2 Bottom padding

`AppScreen` has `pb-24` (96 px) so content never hides behind the 64 px bottom nav. The editor adds an extra `pb-40` (160 px) for its 64 px tool rail + breathing room.

### L.3 Spacing rhythm

Tailwind defaults: `gap-2` (8 px) for tight clusters, `gap-3` (12 px) for buttons, `gap-4` (16 px) for sections, `mt-5` (20 px) between unrelated sections, `mt-6` (24 px) for top-level section breaks.

### L.4 Hero sizes

- Brand mark / icon: `h-5 w-5` (inline) or `h-8 w-8` (hero).
- VehicleArt: `h-32 w-full` in hero, `h-12 w-full` in artwork gallery.
- WidgetCanvas: native square (1:1), `scale` prop (0.42, 0.55, 0.6, 0.62, 1.0) applied via inner `transform: scale(N)`.

---

## M — Manifest version, atomic publish, ETag

### M.1 Versioning

`publish_events.version` follows `YYYY.MM.DD` (e.g. `2026.07.24`). The admin publish action generates this from the current date.

### M.2 Atomic transaction

`POST /admin/api/publish` runs inside a single sqlite transaction:

1. Read all active rows from `categories`, `assets`, `vehicle_brands`, `vehicle_models`, `sounds`, `templates`.
2. Filter assets by approved license.
3. Filter templates by active category and active vehicle model.
4. Serialize the manifest.
5. Compute ETag.
6. Insert `publish_events` row.
7. Commit.

If any step throws, the transaction rolls back; the previous manifest URL is still valid.

### M.3 ETag

`etag = SHA-256(manifest_json).substring(0, 16)` returned as `W/"<16 hex>"`. Clients send `If-None-Match: W/"<16 hex>"` to short-circuit downloads. The middleware compares and returns 304 Not Modified.

### M.4 What the React app *does not* do (yet)

It does not fetch the manifest. The client catalog in `src/lib/catalog.ts` is the static content for now. The wire-up to fetch the manifest is intentionally deferred to the native iOS app milestone.

---

## N — Navigation

### N.1 Bottom nav

4 tabs in `src/components/app-shell.tsx`:

| Order | Label | Icon | Route | Active match |
|---|---|---|---|---|
| 1 | Home | `Home` | `/home` | exact `/home` |
| 2 | Studio | `LayoutGrid` | `/studio` | `/studio` + `/studio/*` |
| 3 | Garage | `Car` | `/garage` | exact `/garage` |
| 4 | Sounds | `Music4` | `/sounds` | exact `/sounds` |

The active tab gets:

- `text-primary` (instead of `text-muted-foreground`)
- A 1 px tall, 40 px wide, `bg-primary` pill at the top of the tab (animated from `w-0 opacity-0` to `w-10 opacity-100` over 300 ms)
- A thicker icon stroke (2.4 vs 1.8)

### N.2 No floating action button

The bottom nav is the **only** global navigation. The Studio tab contains the "Create New" and "Manage Slots" CTAs as regular buttons within its screen. The home hero holds the "Open Studio" CTA.

### N.3 Top-bar nav

Two screens have a non-nav back link:

- `/studio/templates/$id` — "← Studio" → `/studio`
- `/studio/editor/$id` — sticky command bar with X exit button
- `/settings` — "← Home" → `/home`
- `/setup_guide` — "← Home" → `/home`

`/studio/my-widgets` and `/studio/slots` use the bottom-nav's Studio tab to back out; no per-page back link.

### N.4 URL state

- `studio/editor/$id` — `$id` is the draft id.
- `studio/templates/$id` — `$id` is the template id.
- All other routes have no path parameters.
- Query strings: none used.

---

## O — Onboarding flow state

- `state.introDone` (boolean) — set to `true` on Intro completion (any of: Skip, Enter Drive Studio).
- Reset to `false` via Settings → "Reset Introduction" → navigate to `/intro`.
- The `Index` (`/`) route reads `state.introDone` and routes to either `/home` (true) or `/intro` (false).
- Hydration is awaited via the `ready` flag from `useAppState` — the Index shows a "Loading Drive Studio" pulse until `ready` is true.

---

## P — Persistence

### P.1 Storage key

`localStorage["drive-studio-state-v1"]`. The `-v1` suffix is a deliberate version marker. Any future breaking change to the state shape gets a `-v2` key (and a one-time migration prompt).

### P.2 Read path

`hydrate()` in `src/lib/store.ts`:

```ts
export function hydrate() {
  if (hydrated || typeof window === "undefined") return;
  hydrated = true;
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) state = { ...defaultState, ...(JSON.parse(raw) as AppState) };
  } catch {
    state = defaultState;
  }
  listeners.forEach((l) => l(state));
}
```

Failure modes handled:

- No `window` (SSR) — bails.
- `localStorage` throws (e.g. disabled in private mode) — caught, state stays at default.
- JSON parse fails (corrupt data) — caught, state stays at default.

### P.3 Write path

Every `setState` call:

```ts
export function setState(updater: (s: AppState) => AppState) {
  state = updater(state);
  persist();           // try { localStorage.setItem(KEY, JSON.stringify(state)) } catch {}
  listeners.forEach((l) => l(state));
}
```

### P.4 Limits

Browsers cap `localStorage` at ~5 MB. The state JSON for a heavy user (50 drafts, 4 slot widgets, custom image) is ~50–200 KB, so this is safe.

### P.5 Settings clear actions

- **Clear Downloaded Assets** — sets `vehicle.customImage = null` (the only "downloaded" thing actually present in this build).
- **Clear Drafts** — requires typing the literal `DELETE` to confirm. Sets `drafts: []`, `slots: [null, null, null, null]`, `lastEditedDraftId: null`.
- **Reset Introduction** — sets `introDone: false`, navigates to `/intro`.

### P.6 Refresh Now

The button on Settings simulates a manifest refresh: 700 ms spinner, then `lastRefresh = Date.now()`. There is no actual fetch (the client is offline).

---

## Q — Quality gates

### Q.1 Lint

`bun run lint` → `eslint .` with the flat config. Plugins: `@eslint/js`, `typescript-eslint`, `react-hooks`, `react-refresh`, `prettier`.

### Q.2 Format

`bun run format` → `prettier --write .`. `.prettierignore` excludes `bun.lock` and the generated `routeTree.gen.ts`.

### Q.3 Typecheck

`tsc --noEmit` against `tsconfig.json` (strict, every strictest flag on).

### Q.4 Build

`bun run build` → `vite build` (TanStack Start + Nitro). Outputs the SSR bundle plus the static client assets.

### Q.5 Development

`bun run dev` → `vite dev` (port 3000 by default; sandbox detection in the lovable config may override).

### Q.6 Loovable sync

The `AGENTS.md` and `.lovable/` config mark this project as Lovable-managed. Commits to the connected branch auto-sync to Lovable's editor; never `--force` or amend pushed history.

---

## R — Routing (per-route reference)

### R.1 `/` (Index)

- File: `src/routes/index.tsx`
- Purpose: Bootstrap — hydrate store then redirect.
- Renders: A pulsing "Loading Drive Studio" mono-label.
- Logic: `useEffect(() => { hydrate(); }, [])` then `useEffect(() => { if (ready) navigate({ to: state.introDone ? "/home" : "/intro", replace: true }); }, …)`.

### R.2 `/home`

- File: `src/routes/home.tsx`
- See section H.

### R.3 `/intro`

- File: `src/routes/intro.tsx`
- See section I.

### R.4 `/garage`

- File: `src/routes/garage.tsx`
- See section G.

### R.5 `/studio`

- File: `src/routes/studio.index.tsx`
- Two-tab screen (Templates / My Widgets). Search by name, category chips, Free/Premium filter. Create new navigates to editor; tapping a card navigates to template detail or editor.

### R.6 `/studio/my-widgets`

- File: `src/routes/studio.my-widgets.tsx`
- Grid of saved drafts. Empty state with `OnboardArt variant=2`. Each card has a per-draft dropdown (Edit, Duplicate, Rename, Delete). Rename opens a Dialog; Delete opens an AlertDialog. Corrupted drafts (no `spec.layers` array) show a dashed-red "could not be read" panel.

### R.7 `/studio/slots`

- File: `src/routes/studio.slots.tsx`
- 4 vertical cards. Each shows the assigned widget preview, name, "Updated Nm ago", and Assign/Replace/Remove buttons. Picker is a `Sheet` (max-h-80vh) showing all drafts. Remove is an `AlertDialog`. Footer warning: "Preview only — iPhone and CarPlay activation requires the native iOS build."

### R.8 `/studio/templates/$id`

- File: `src/routes/studio.templates.$id.tsx`
- Loader fetches the template; `notFound()` if missing. Hero preview at native size, metadata pills (Category, Family, Free/Premium), included components list, attribution, Edit Copy / Assign to Slot buttons.

### R.9 `/studio/editor/$id`

- File: `src/routes/studio.editor.$id.tsx`
- See section E. The largest file (~560 LOC).

### R.10 `/sounds`

- File: `src/routes/sounds.tsx`
- See section Y.

### R.11 `/settings`

- File: `src/routes/settings.tsx`
- See section P.5 and P.6.

### R.12 `/setup_guide`

- File: `src/routes/setup_guide.tsx`
- 3 sections (iPhone install, CarPlay widgets, Shortcuts automation), each with 4 steps tagged "Available in Windows" / "Requires iPhone" / "Requires Mac/Xcode".

### R.13 `__root`

- File: `src/routes/__root.tsx`
- HTML shell, `<head>` content (charset, viewport, Manrope + DM Mono preconnect + stylesheet, OG meta), `<Outlet />` for the active route, `<Toaster position="top-center" />`, `notFoundComponent` (404 page), `errorComponent` (calls `router.invalidate()` and `reset()`).

---

## S — State store (module-level reactive)

`src/lib/store.ts` is the single source of truth for the whole app.

### S.1 Shape

```ts
type AppState = {
  introDone: boolean;
  drafts: Draft[];
  slots: (string | null)[];      // length 4
  vehicle: Vehicle;
  sounds: { connect: string | null; disconnect: string | null; reminder: string | null };
  lastRefresh: number;
  lastEditedDraftId: string | null;
};
```

### S.2 Internals

```ts
const KEY = "drive-studio-state-v1";
let state: AppState = defaultState;
let hydrated = false;
const listeners = new Set<Listener>();
```

A module-level mutable singleton. Listeners are registered by `useAppState` on mount, removed on unmount.

### S.3 API

| Function | Effect |
|---|---|
| `hydrate()` | Read from `localStorage` once, normalize with `defaultState`, notify listeners. |
| `setState(updater)` | Apply updater, persist, notify. |
| `useAppState()` | React hook returning `{ state, ready, update }`. |
| `createDraft(name, spec)` | New draft, prepend, set `lastEditedDraftId`. |
| `saveDraft(id, patch)` | Patch draft, bump `updatedAt`, set `lastEditedDraftId`. |
| `deleteDraft(id)` | Remove draft + null its slot refs + clear `lastEditedDraftId` if it was this draft. |
| `duplicateDraft(id)` | Deep-clone via `JSON.parse(JSON.stringify(spec))`, create as `"<name> copy"`. |
| `assignSlot(index, draftId)` | `slots[i] = draftId`. |
| `templateById(id)` | Lookup helper. |
| `formatWhen(ts)` | Relative time: "just now" / "Nm ago" / "Nh ago" / "Nd ago". |

### S.4 Why no library?

- 1 KB of code vs ~10 KB for Zustand.
- Zero ceremony — the React surface is a single hook.
- No provider tree (the store is a module-level singleton).
- Easy to inspect in DevTools (set breakpoints on `setState`).

The trade-off: no time-travel devtools, no middleware, no dev-only logging. Acceptable for a 12-route app.

### S.5 SSR safety

`hydrate()` checks `typeof window === "undefined"` and bails on the server. `useAppState`'s `ready` flag stays `false` until hydration runs, so the `Index` route can show the loading state without flashing wrong content.

---

## T — Templates (8 stock, layered)

Each template is a `WidgetSpec` (background + layers) stored in `src/lib/catalog.ts`. Worked example: **Midnight Run** (`midnight-run`):

```ts
mk("midnight-run", "Midnight Run", "Night", false, "#101828", "#1E3A5F", [
  baseLayer("text",   { text: "MIDNIGHT",   x: 10, y: 12, fontSize: 11, letterSpacing: 2, color: "#7FB6FF" }),
  baseLayer("clock",  {                       x: 10, y: 30, w: 80, h: 26, fontSize: 34, weight: 800 }),
  baseLayer("text",   { text: "Range 412 km",x: 10, y: 72, fontSize: 12, weight: 500, color: "#A8B6CC" }),
], "2026-07-18"),
```

Render flow:

1. `WidgetCanvas` applies the `linear-gradient(150deg, #101828, #1E3A5F)` to its background.
2. Three layers render in order (back to front):
   - "MIDNIGHT" (cyan-blue, letter-spaced) at top-left.
   - Live clock at 34 px, 800 weight, fills 80% width.
   - "Range 412 km" (muted gray) at bottom.
3. The clock updates every render via `toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })`.

### T.1 All 8 templates (summary)

| ID | Layers (kind: text) |
|---|---|
| `midnight-run` | text, clock, text |
| `pure-lines` | text, divider, date |
| `trip-meter` | badge, text, text (premium) |
| `carbon-grid` | shape, text, text, clock (premium) |
| `commuter` | clock, date, badge |
| `aurora-drive` | text, text, divider, text |
| `night-shift` | text, clock (premium) |
| `cargo` | badge, text, divider |

---

## U — UI primitives (shadcn/ui, 47 vendored)

The 47 components under `src/components/ui/` are vendored from shadcn/ui (New York style, slate base, lucide icons, RSC: false, CSS variables on). Only ~10 are actively used in the 12 routes; the rest are present for the future admin / dashboard surface.

### U.1 Actively used

- `button` — every CTA, every icon button.
- `sheet` — bottom sheets in editor (Add Layer, Background, Layers, Inspector) and slots (draft picker).
- `alert-dialog` — confirm dialogs in editor (exit), settings (clear drafts), my-widgets (delete), slots (remove).
- `dialog` — rename in my-widgets.
- `dropdown-menu` — per-draft actions in my-widgets.
- `slider` — every numeric field in the inspector.
- `switch` — text shadow, flip horizontal toggles.
- `label` — inspector field labels.
- `input` — widget name, garage display name, settings confirm field.
- `sonner` — toast system mounted in `__root`.

### U.2 Vendored but unused (in this build)

accordion, alert, aspect-ratio, avatar, breadcrumb, calendar, carousel, chart, checkbox, collapsible, command, context-menu, drawer, form, hover-card, input-otp, menubar, navigation-menu, pagination, popover, progress, radio-group, resizable, scroll-area, select, separator, sidebar, skeleton, table, tabs, textarea, toggle, toggle-group, tooltip.

### U.3 CVA pattern

`button.tsx` uses `class-variance-authority` to define 6 variants × 5 sizes:

```ts
const buttonVariants = cva("base classes…", {
  variants: {
    variant: { default, destructive, outline, secondary, ghost, link },
    size:    { default, sm, lg, icon },
  },
  defaultVariants: { variant: "default", size: "default" },
});
```

`asChild` prop swaps the rendered element to `Slot` from `@radix-ui/react-slot`, so you can do `<Button asChild><Link to="…">…</Link></Button>`.

---

## V — Vehicle art (SVG silhouettes, brand marks)

`src/components/art.tsx`. Three exported components, all pure inline SVG.

### V.1 `VehicleArt`

```ts
const body: Record<string, string> = {
  coupe:    "M10 62 C22 40 38 32 62 30 C86 28 108 34 124 44 L162 48 C176 50 184 56 184 62 Z",
  sedan:    "M8 62  C18 44 34 34 60 32 L112 32 C140 34 160 42 176 50 …",
  suv:      "M10 62 L10 44 C10 36 20 30 34 28 L128 26 …",
  wagon:    "M8 62  L8 42  C8 34  20 30  36 28  L140 28 …",
  roadster: "M6 62  C18 46 36 38 64 36  C96 34  128 38 152 44 …",
  hatch:    "M12 62 L12 46 C12 36 26 30 44 28 L120 28 …",
};
```

- viewBox: `0 0 196 78`.
- A `<linearGradient id="g-<kind>">` from `--primary-glow` (95% opacity) to `--primary` (45% opacity).
- Filled silhouette + a stroke version at 70% opacity.
- Two wheel circles at `(54, 63)` and `(146, 63)`, r=10, stroke currentColor, 75% opacity.
- A subtle ground line `y=74` at 20% opacity.

If `kind` is unknown, falls back to `coupe`.

### V.2 `OnboardArt`

Single 240×180 SVG with 3 switchable sub-trees. Used in the Intro carousel and the My Widgets empty state.

- **Variant 1** (compositional blocks): one large square + two stacked rectangles + a wide bar — suggests "screen + cards + footer".
- **Variant 2** (column stack): 4 vertical columns, the first 2 filled — suggests "drafts".
- **Variant 3** (framed panel): one centered rounded rectangle + inner square + thin bar — suggests "a widget".

All use `currentColor` so the parent `text-primary` color is respected.

### V.3 `BrandMark`

40×40 SVG with 4 switchable shapes:

- `aurelio` — triangle (apex up).
- `velora` — diamond.
- `northstar` — 8-point star.
- `kinetic` — outlined circle, 5 px stroke.

All `fill="currentColor"` or `stroke="currentColor"`. Falls back to `kinetic` on unknown id.

---

## W — Widget canvas (renderer, layer nodes)

`src/components/widget-canvas.tsx`. The single rendering surface for every widget preview and every editor canvas.

### W.1 `WidgetCanvas`

```tsx
<WidgetCanvas spec={spec} scale={1} className="…" />
```

- A `<div className="relative aspect-square w-full overflow-hidden rounded-3xl border border-border">`.
- Background:
  - `solid` → `bg.from`
  - `gradient` → `linear-gradient(150deg, bg.from, bg.to ?? bg.from)`
  - `image` → gradient placeholder (asset not yet wired)
- An inner `<div style={{ transform: scale(N), fontSize: 16 }}>` that renders the layers.
- Optional `children` slot for selection rings, handles, and guides (used by the editor).

### W.2 `LayerNode`

```tsx
<LayerNode layer={l} />
```

- Returns `null` if `l.hidden`.
- Positioned absolutely with `left/top/width/height: ${x|y|w|h}%`.
- Renders one of 7 sub-trees depending on `kind`:
  - `divider` → 1 px-tall colored bar (height = `max(1, h/6)`).
  - `shape` → solid color block.
  - `image` → gradient placeholder + `IMG · <fit>` mono label.
  - `badge` → 1 px border, centered mono text at `fontSize * 0.55` with `letter-spacing: 1.2`.
  - `text / clock / date` → styled div, font size from layer, weight, alignment, letter-spacing, optional shadow, `font-mono` for clocks.
- `flipH` → `transform: scaleX(-1)`.
- `radius` → `border-radius`.

### W.3 Time-driven layers

`clock` and `date` ignore `layer.text` and compute live:

```ts
if (l.kind === "clock") return now.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
if (l.kind === "date")  return now.toLocaleDateString([], { weekday: "short", day: "numeric", month: "short" });
```

`now` is captured at render time, so React re-renders propagate as the time advances (re-renders happen on every `setState` in the app, which is frequent enough that the clock updates visibly).

### W.4 Why not a real `<canvas>`?

SVG positioning is enough at this fidelity. A real canvas (skia / webgl) would buy hardware-accelerated transforms but cost ~200 KB of runtime code. The current 100% CSS approach is 0 KB and instantly editable via DevTools.

---

## X — XSS, sanitization, SVG safety

### X.1 SVG safety (server side)

`SvgSanitizer.sanitize` strips:

- `<script>` elements
- `on*` event handler attributes (`onclick`, `onload`, etc.)
- `javascript:` URLs
- `<foreignObject>` (can host arbitrary HTML)
- `<use href="external">` (can include external SVG with the same handlers)

The sanitization runs in the admin upload pipeline; admin-uploaded SVGs cannot reach the public manifest without passing it.

### X.2 React's default safety

React 19 escapes all string children by default. The only place user input flows into the DOM as raw HTML is `vehicle.customImage` (an `<img src>`), which is safe by construction (data URL or null). No `dangerouslySetInnerHTML` is used anywhere in the app.

### X.3 localStorage trust boundary

`hydrate()` blindly `JSON.parse`s the stored value. The user controls their own localStorage, so there is no XSS risk. If the JSON is corrupt (truncated, bad shape), the catch falls back to `defaultState`. The My Widgets screen additionally checks each draft for `Array.isArray(d.spec.layers)` and renders a "Draft could not be read" panel for corrupt entries.

### X.4 URL params

The only dynamic route params are `studio/editor/$id` and `studio/templates/$id`. They are matched against the in-memory drafts/templates arrays, not rendered as HTML. No reflection.

---

## Y — Yielding audio (Web Audio API, ADSR)

`src/routes/sounds.tsx`. Synthesizes a 1.15 s sine wave on every preview tap.

### Y.1 Lifecycle

```ts
const ctxRef = useRef<AudioContext | null>(null);
const stopRef = useRef<(() => void) | null>(null);

useEffect(() => () => stopRef.current?.(), []);  // unmount → stop

const stop = () => {
  stopRef.current?.();
  stopRef.current = null;
  setPlaying(null);
};
```

A single `AudioContext` is created on first use and reused. The `stopRef` holds the active "stop" callback so any new `play()` can kill the previous one.

### Y.2 Synthesis

```ts
const osc = ctx.createOscillator();
const gain = ctx.createGain();
osc.type = "sine";
osc.frequency.value = s.freq;                       // from the Sound row
gain.gain.setValueAtTime(0.0001, ctx.currentTime);
gain.gain.exponentialRampToValueAtTime(0.18, ctx.currentTime + 0.05);
gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + 1.1);
osc.connect(gain).connect(ctx.destination);
osc.start();
osc.stop(ctx.currentTime + 1.15);
```

This is a 3-point ADSR envelope:

| Phase | Time | Gain |
|---|---|---|
| Attack | 0 → 50 ms | 0.0001 → 0.18 (exp ramp) |
| Sustain | 50 ms → 1.1 s | 0.18 → 0.18 (held) — implicit |
| Release | 1.1 s → 1.15 s | 0.18 → 0.0001 (exp ramp) |

The exponential ramps avoid audible clicks at the start and end. The `setPlaying(s.id)` state is reset by a 1.2 s `setTimeout` that matches the `osc.stop` time.

### Y.3 WebKit fallback

```ts
const Ctx = window.AudioContext ?? (window as any).webkitAudioContext;
```

Safari still ships with the vendor-prefixed global on some iOS versions.

### Y.4 Why no audio files?

There are no audio files anywhere in the project. The 12 sounds are pure parameter rows (`freq: 880, 220, 440, …`). This keeps the bundle tiny (no MP3s/WAVs) and gives the future iOS app a deterministic way to recreate the exact same sounds on the device (the iOS app would use `AVAudioEngine` with a `sine` source — same parameter set, same envelope).

### Y.5 Setup notice

The Sounds screen footer says:

> These cues preview here instantly. Triggering them on a real device requires a manual Apple Shortcuts automation — see the setup guide.

Sets user expectation: this app previews the *idea* of a sound, the actual CarPlay trigger happens in iOS Shortcuts.

---

## Z — Zones, zero-state, future work

### Z.1 Zones (per-screen composition)

Every screen follows a vertical rhythm:

1. **Identity zone** (top 10%): wordmark, screen title, back link.
2. **Primary content zone** (10–80%): the screen's main panels.
3. **Action zone** (80–95%): primary CTA, secondary actions.
4. **Navigation zone** (bottom 5%): bottom nav (96 px reserved).

### Z.2 Zero-states

| Screen | Zero-state |
|---|---|
| Intro | Pulsing "Loading Drive Studio" pulse |
| Home | (no zero state — always shows default vehicle) |
| Studio (templates tab) | "No templates match those filters." |
| Studio (mine tab) | "No drafts yet." + Create your first widget button |
| My Widgets | OnboardArt variant 2 + "No saved widgets yet" + Browse templates |
| Slots | (always shows 4 slot cards) |
| Garage | (always shows default vehicle) |
| Sounds | "None" option always available at top |
| Settings | (always shows the panels) |
| Setup Guide | (always shows the 3 sections) |
| Editor | "This draft could not be found or failed to parse." + back button |

### Z.3 Future work (explicit backlog)

1. **iOS / CarPlay native shell** — the entire React app is a Windows preview. The Dart backend exists to feed the iOS app.
2. **Real drag/resize of layers** — current handles are visual only.
3. **Asset library for image layers** — current `image` kind is a placeholder gradient.
4. **Asset library for backgrounds** — current `image` background is a placeholder gradient.
5. **Multi-select layers** — currently one at a time.
6. **Snap guides** — visual only.
7. **Manifest fetch** — currently offline.
8. **Sync** — multi-device drafts via the backend.
9. **Account / IAP** — premium flag is visual only today.
10. **Image upload resize** — uploads are stored as-is, no client-side compression.
11. **Offline indicator** — no PWA service worker yet.
12. **Real iPhone → CarPlay widget bridging** — only Apple can ship this; the iOS app milestone is the gate.

### Z.4 Risk register

| Risk | Mitigation |
|---|---|
| OKLCH → sRGB drift on older Windows browsers | Browsers since 2023 all support OKLCH natively; Tailwind 4 emits OKLCH at the CSS layer. |
| localStorage 5 MB cap | Currently safe; a "Clear downloaded assets" button exists for future heavy users. |
| AudioContext suspended on first user gesture | iOS Safari requires a tap first — every preview button is a tap, so it works. |
| Large custom image → localStorage quota | Documented in G.3; a future resize step would help. |
| Lovable sync collision | AGENTS.md forbids force-push; commits stay linear on the connected branch. |

### Z.5 Architectural invariants

1. **No client → server calls in the React app.** The Dart backend is offline-reachable only from the future iOS app.
2. **No analytics, no telemetry, no error reporting.** `lib/lovable-error-reporting.ts` exists for the root error boundary but is a stub.
3. **Dark only.** No light-mode toggle.
4. **English only.** No i18n.
5. **Module-level state, not React Context.** Simpler, smaller, faster.
6. **No 3rd-party widget library besides shadcn + Radix.** No MUI, no Chakra, no Mantine.

---

## Appendix A — File map (high level)

```
drive-studio/                          # the React app (this doc lives here)
  src/
    routes/                            # 12 TanStack Router file routes
      __root.tsx
      index.tsx
      home.tsx
      intro.tsx
      garage.tsx
      sounds.tsx
      settings.tsx
      setup_guide.tsx
      studio.index.tsx
      studio.my-widgets.tsx
      studio.slots.tsx
      studio.templates.$id.tsx
      studio.editor.$id.tsx
    components/
      app-shell.tsx                    # BottomNav, AppScreen, ScreenHeader
      art.tsx                          # VehicleArt, OnboardArt, BrandMark
      widget-canvas.tsx                # WidgetCanvas, LayerNode
      ui/                              # 47 shadcn/ui components
    lib/
      catalog.ts                       # static data (brands, templates, sounds, etc.)
      store.ts                         # module-level state + persistence
      utils.ts                         # cn() helper
      error-capture.ts                 # console.error patch + cause walker
      error-page.ts                    # static SSR error HTML
      lovable-error-reporting.ts       # stub
    hooks/
      use-mobile.tsx                   # window.matchMedia("max-width: 768px")
    server.ts                          # Nitro fetch entry
    start.ts                           # TanStack Start middlewares (error, csrf)
    router.tsx                         # createRouter()
    routeTree.gen.ts                   # generated
    styles.css                         # design tokens
  public/
    favicon.ico
    robots.txt
  package.json
  vite.config.ts
  tsconfig.json
  components.json
  eslint.config.js
  .prettierrc
  .prettierignore
  bun.lock
  bunfig.toml
  README.md
  AGENTS.md
  DOCUMENTATION.md                     # ← this file

server/                                # the Dart backend
  bin/
    public_server.dart                 # port 8788, public read API
    admin_server.dart                  # port 8789, local-only admin
    seed_database.dart                 # idempotent demo seed
    import_premium_assets.dart
    _inspect.dart
  lib/
    app_factory.dart                   # ServerGraph + commonMiddleware
    auth/
      admin_token_store.dart
      admin_auth_middleware.dart
      admin_audit.dart
    database/
      database.dart                    # sqlite3 open + WAL
      migrations.dart                  # versioned schema
    models/
      asset.dart
      category.dart
      license.dart
      publish_event.dart
      sound.dart
      template.dart
      vehicle.dart
    repositories/
      asset_repository.dart
      category_repository.dart
      license_repository.dart
      publish_repository.dart
      sound_repository.dart
      template_repository.dart
      vehicle_repository.dart
    routes/
      public_routes.dart
      admin_routes.dart
    services/
      manifest_service.dart
      svg_sanitizer.dart
      upload_service.dart
    seed/
      demo_seed.dart
    validation/
      asset_validator.dart
  data/
    drive_studio.db (+ -shm, -wal)
  storage/
    images/    (24 files)
    previews/  (0 files, future render output)
    sounds/    (12 files)
  public/
    admin/    (admin shell)
  logs/
    public_server.log
    public_server.log.err
  test/                                # 11 spec files
```

## Appendix B — Glossary

| Term | Meaning |
|---|---|
| **Brand** | A fictional car manufacturer (Aurelio, Velora, Northstar, Kinetic). |
| **Model** | A specific vehicle from a brand (GT Corsa, V8 Pulse, etc.). |
| **Artwork** | A 1:1 aspect SVG silhouette representing the vehicle body. |
| **Widget** | A 1:1 aspect design that lives in a dashboard slot. |
| **Template** | A pre-built widget shipped with the app. |
| **Draft** | A user-saved widget, persisted to localStorage. |
| **Slot** | One of 4 dashboard positions that holds a draft reference. |
| **Layer** | A single positioned element within a widget (text, image, clock, etc.). |
| **Spec** | A `WidgetSpec` — a `background` + an ordered array of `Layer`s. |
| **Manifest** | The server-side JSON document listing all active content. |
| **ETag** | A 16-char hex fingerprint of the manifest, returned in `ETag` and honored via `If-None-Match`. |
| **Atomic publish** | The server's single-transaction publish flow that bumps the manifest version safely. |
| **systemSmall** | The iOS widget family name. All Drive Studio widgets target this family (155×155 pt on iPhone). |
| **Premium** | A visual label only — no IAP gate in this build. |
| **Drive Studio** | The product name. Always capitalized. |
| **Drive view** | The user's perspective on their car dashboard, designed via this app. |

## Appendix C — Verification commands

Frontend:
```bash
cd E:/car-play/drive-studio
bun install                       # or npm install
bun run dev                       # vite dev
bun run build                     # vite build
bun run lint                      # eslint
bun run format                    # prettier --write .
```

Backend:
```bash
cd E:/car-play/server
dart pub get
dart run bin/public_server.dart   # port 8788
dart run bin/admin_server.dart    # port 8789
dart test                         # all 11 spec files
```

End-to-end smoke:
1. Start the backend: `dart run bin/public_server.dart`.
2. Start the frontend: `bun run dev`.
3. Open `http://localhost:3000`.
4. Verify: 3-slide intro → home with default Aurelio GT → studio with 8 templates → garage → sounds (tap any) → editor (create new, add a layer, save, exit).
5. Kill the page, refresh: state persists via localStorage.

## Appendix D — Notable design decisions

1. **OKLCH over sRGB hex** — gives stable perceptual lightness across hue changes. Future iOS / Flutter ports reuse the same tokens without drift.
2. **Percentage geometry (0–100) over pixel geometry** — survives viewport changes, device rotations, and zoom.
3. **JSON round-trip for deep clone** — no structural sharing, no Immer, no risk of partial mutations.
4. **30-entry undo cap** — RAM guard, 5–50 KB worst case.
5. **Module-level state over Context** — 1 KB code, zero provider tree.
6. **Sonner over Radix Toast** — single-import API, top-center matches the spec.
7. **shadcn New York style** — tight radii (16 px base) match the automotive, hard-edged aesthetic.
8. **Synth audio over audio files** — 0 KB audio payload, deterministic across platforms.
9. **CC0 in-house artwork** — no IP risk, no photography licensing.
10. **Fictional brands** — same IP-safety reasoning.

---

*Last updated 2026-08-01. This document covers the Drive Studio system as of the React prototype (TanStack Router/Vite) and Dart public API (port 8788) on the `prototype/drive-studio-complete` branch.*
