# Drive Studio — Guideline 4.3 / 4.3(a) positioning

**Purpose:** Keep App Review metadata and screenshots differentiated from generic “car widget maker” clones.

## Reason to exist

Drive Studio is a **compositor-first** studio for glanceable **Home Screen** drive widgets: layered text, clocks, dates, badges, shapes, speedometers, and user photos on a `systemSmall` canvas — plus four purposeful slots and short Shortcuts connection cues.

It is **not** a fake CarPlay dashboard shell, not an OEM companion, and not a stock photo pack of trademarked cars.

## Differentiation pillars

| Pillar | Drive Studio | Generic car-widget apps |
|--------|--------------|-------------------------|
| Core job | Layer compositor + templates + slots + sound cues | Often single static car photo widget |
| Brand | Electric Blue / Obsidian Drive Studio identity | Template purple/cream kits |
| Vehicles | Fictional marques (Aurelio, Velora, Northstar, Kinetic) + **user photos only** | OEM names / stock car packs |
| Live data | Honest iPhone battery, charging, GPS speed (permissioned), manual car-link | Fake “CarPlay live” claims |
| Platform honesty | Home Screen WidgetKit + Shortcuts — **no CarPlay UI shell** | Misleading CarPlay screenshots |
| Cutout | On-device Remove BG | Often cloud upload without clear disclosure |

## Metadata rules (do not regress)

- Name/subtitle: widgets & drive sounds — not “CarPlay Dashboard”.
- Keywords: no trademarked OEM stuffing; no “replace CarPlay”.
- Screenshots: real Home Screen widgets after WidgetKit link — never a mocked CarPlay OS.
- Review notes: state clearly that Apple forbids custom CarPlay UI shells.

## Portfolio guard

If you ship other apps under the same developer account, keep **different problem statements**, UI identity, and IAP product IDs. Do not reuse this binary architecture or Electric Blue shell unchanged.

## Risk verdict (pre-submit)

**LOW–MED** 4.3 risk when listing, screenshots, and in-app copy stay honest and compositor-forward. Risk rises if metadata or screenshots look like a CarPlay clone or a stock My Car Widget template.
