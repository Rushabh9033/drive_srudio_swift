# Drive Studio — App Store listing draft

**Status:** Metadata draft for Wave 2 submission (not live).  
**Product:** Drive Studio — design Home Screen drive widgets, slots, and connection sounds.  
**Honest framing:** Not a custom CarPlay OS UI. Home Screen widgets + Shortcuts.  
**4.3 positioning:** See `APPLE_4_3_POSITIONING.md`.

---

## Name & subtitle

| Field | Draft |
|-------|--------|
| **Name** | Drive Studio |
| **Subtitle** | Widgets & drive sounds |
| **Bundle ID** | `com.drivestudio.app` (confirm in Xcode) |
| **SKU** | `drive_studio_ios` |
| **Primary category** | Lifestyle |
| **Secondary** | Utilities |

Avoid keyword stuffing with “CarPlay dashboard”, “replace CarPlay”, or competitor clones.

---

## Promotional text (170 chars)

```
Design four Home Screen drive widgets with GPS speedometers, your photos, slots, and Shortcuts cues. Premium optional — not a CarPlay OS shell.
```

---

## Description

```
Drive Studio helps you design the glanceable widgets and sounds that frame your drive — before you leave the driveway.

WHAT YOU GET
• Widget Studio — drag, resize, copy/paste layers; text, clocks, dates, badges, shapes, speedometers, and your photos on a systemSmall canvas
• Four slots — assign finished drafts so each Home Screen widget instance stays purposeful
• Your photos — Gallery or Camera for garage art and layers (no stock OEM car photo library). Optional on-device Remove BG
• Live glance data — battery, charging, clocks, and GPS speed while the app is open (with Location permission)
• Fictional marques — Aurelio, Velora, Northstar, Kinetic silhouettes for branding (not affiliated with any OEM)
• Sounds — synthesize connect, disconnect, and reminder cues for Shortcuts automations
• Setup guide — honest steps for Home Screen widgets + Shortcuts (Apple does not allow a custom CarPlay UI shell)

PREMIUM
Unlock additional templates and cue packs with a one-time non-consumable purchase (drive_studio_premium). Restore anytime with the same Apple ID.

PRIVACY
Drafts, preferences, and photos stay on your device. No account required for V1. No ads or tracking SDKs in V1.
Privacy Policy: https://drivestudio.app/privacy (host docs/legal/privacy.html on HTTPS before Connect).
Support: https://drivestudio.app/support

Drive Studio is for enthusiasts who want a crafted Home Screen drive view — not a fake CarPlay dashboard.
```

---

## Keywords (100 char max, comma-separated)

```
widget,home screen,drive,garage,shortcuts,car,clock,speedometer,sound,studio
```

Do **not** include trademarked OEM names. Avoid “CarPlay dashboard” / “replace CarPlay” as keywords.

---

## What’s New (1.0)

```
First release: Widget Studio (drag, resize, copy/paste), speedometers with GPS speed, user photos + on-device Remove BG, four slots, fictional garage silhouettes, synthesized drive cues, Setup guide, and optional Premium templates.
```

---

## In-App Purchase

| Type | Product ID | Reference name | Price tier (draft) |
|------|------------|----------------|--------------------|
| Non-Consumable | `drive_studio_premium` | Drive Studio Premium | TBD (e.g. Tier 5 ≈ $4.99 USD) |

Display name: **Drive Studio Premium**  
Description: Unlock premium widget templates and sound cues. One-time purchase; restores with your Apple ID.

Review tip: Sandbox tester must own no prior purchase of `drive_studio_premium` for first-buy testing; use Restore to verify reinstall. Debug Premium unlock is web/Windows only — never shown on the iOS StoreKit path.

---

## Privacy nutrition labels (draft)

| Data type | Linked to user | Used for tracking | Notes |
|-----------|----------------|-------------------|--------|
| Purchases | No* | No | StoreKit purchase state only |
| User content (drafts / photos) | No | No | On-device; Photo Library + Camera for optional images |
| Location | No | No | While In Use — GPS speed for speedometer widgets while app is open; not used for tracking |
| Diagnostics | No | No | None in V1 (add Crashlytics later only with consent) |

\*Apple may list purchase history as linked when using StoreKit; keep “tracking” off.

**Data collection:** None beyond what StoreKit / OS requires for IAP restore. No ads/trackers in V1.

**Privacy Policy URL:** Host `docs/legal/privacy.html` on HTTPS before submission.  
**Support URL:** Host `docs/legal/support.html` on HTTPS before submission.

---

## Info.plist usage strings (checklist)

| Key | Present | Copy |
|-----|---------|------|
| `NSPhotoLibraryUsageDescription` | Yes (Runner) | Custom vehicle images and widget layer artwork |
| `NSPhotoLibraryAddUsageDescription` | Yes | Save edited widget previews when you export |
| `NSCameraUsageDescription` | Yes | Photograph your car for widget artwork |
| `NSLocationWhenInUseUsageDescription` | Yes | Live GPS speed on speedometer widgets (while app is open) |
| App Tracking Transparency | N/A V1 | Do not add until ads/tracking ship |
| Bluetooth / Mic | N/A | No CoreBluetooth scan; car-link is manual |
| Privacy Manifest (`PrivacyInfo.xcprivacy`) | **Done** | `ios/Runner/PrivacyInfo.xcprivacy` (+ `ios/DriveStudioWidget/PrivacyInfo.xcprivacy` when extension is linked). No tracking. Declares UserDefaults (CA92.1) and file timestamp (C617.1) for Flutter plugin / app-container use. |
| URL scheme | `drivestudio` | Registered for Wave 2 deep links |

Verify exact strings in `ios/Runner/Info.plist` before submission.

---

## Support / marketing / privacy URLs

| Field | Repo source | Host before Connect (HTTPS) |
|-------|-------------|------------------------------|
| Privacy Policy | `docs/legal/privacy.html` | `https://drivestudio.app/privacy` |
| Support URL | `docs/legal/support.html` | `https://drivestudio.app/support` |
| Terms (optional) | `docs/legal/terms.html` | `https://drivestudio.app/terms` |
| Marketing URL | — | `https://drivestudio.app` |

Deploy steps: see `docs/legal/README.md`. In-app: Settings → Privacy Policy / Terms (`/privacy`, `/terms`) show the same content offline.

Until HTTPS hosting is live, App Store Connect cannot be submitted — keep URLs ready but do not claim the domain is live until it is.

---

## Screenshots plan (6.7" + 6.1")

1. Home — four slots + vehicle glance  
2. Studio — template grid with Electric Blue accents  
3. Editor — selected layer + resize handles / speedometer  
4. Garage — fictional brand silhouettes + user photo path  
5. Sounds — connect / disconnect groups  
6. Setup — honest Home Screen + Shortcuts framing  

No fake CarPlay screenshots. No competitor UI clones. Capture on a real device after WidgetKit is linked (Wave 2).

---

## Review notes (paste for App Review)

```
Drive Studio designs Home Screen widgets and Shortcuts sound automations for driving contexts. It does not implement a custom CarPlay UI (Apple forbids third-party CarPlay dashboard shells). See APPLE_4_3_POSITIONING.md themes: compositor, Electric Blue brand, fictional marques, user photos only.

Premium: non-consumable drive_studio_premium unlocks gated templates/sounds. Sandbox test account: [FILL].

Location: used only while the app is open for GPS speed on speedometer widgets.

Photos: private/on-device; users must have rights to images they add. No public UGC feed.

Widgets: after assigning slots in-app, add Drive Studio Slot 1–4 from the widget gallery (requires WidgetKit Wave 2 build). Data syncs via App Group group.com.drivestudio.shared key widget_state_v1.

Privacy / Support: https://drivestudio.app/privacy and https://drivestudio.app/support (hosted from docs/legal/).

Deep links: drivestudio://sounds and drivestudio://setup (URL scheme registered; Flutter go_router handler ships with V1 — use from Shortcuts → Open URL).
```

---

## Age rating questionnaire (expected)

Infrequent / Mild: none of violence, horror, gambling, unrestricted web. Likely **4+**.

---

## Still Mac-only before submit

See **`MAC_HANDOFF.md`** for the full Wave 2 session checklist.

- Link WidgetKit extension + prove Home Screen widgets on device  
- StoreKit sandbox purchase + Restore  
- TestFlight build  
- Live HTTPS hosting of privacy/support pages (files are ready in-repo)
