# iPhone live data — what works today

Drive Studio treats the **end user’s physical iPhone** as the live data source. Web and Windows builds are **preview only**.

## Run on a physical iPhone (Mac + Xcode)

1. Install Flutter stable and Xcode 15+ on a Mac.
2. On the iPhone: Settings → Privacy & Security → **Developer Mode** → On; trust the computer.
3. Connect the iPhone with USB (or pair wireless debugging after first trust).
4. From the project root:

```bash
flutter pub get
cd ios && pod install && cd ..
flutter devices
flutter run -d <your-iphone-id>
```

Or open `ios/Runner.xcworkspace` in Xcode, select the iPhone, then **Run**.

Minimum iOS: **15.0** (`Info.plist` / project settings). GPS cutout package needs **iOS 16+** for on-device Remove BG.

## What is live on the iPhone app today

| Signal | Source | Notes |
|--------|--------|--------|
| Clock / date | System `DateTime` | Always live in Studio canvases |
| Battery % | `battery_plus` → `UIDevice` | Default **Use live device data = ON** on iOS |
| Charging / full | `battery_plus` battery state stream | Polled ~30s while app is foreground |
| GPS speed (km/h) | `geolocator` position stream | **In-app Location pre-prompt** (Settings → live data) before the system dialog; requires permission + usable fix; otherwise **— / Unavailable** (never invented). Cold start never surprises with an OS dialog until consent. |
| Network online | `connectivity_plus` (`NWPathMonitor`) | wifi / cellular / ethernet / other |
| Phone ↔ Car link | **Manual “Car connected”** in Settings | Reliable path when iPhone is in the car |
| App Group snapshot | Flutter → JSON mirror (+ MethodChannel when wired) | Includes `telemetry` (battery + speed) for future WidgetKit |

## What is *not* live (honest)

- **CarPlay dashboard / custom CarPlay UI** — Apple does not allow a custom CarPlay shell. We do **not** fake a CarPlay session API.
- **Home Screen WidgetKit surfaces** — Mac/Xcode Wave 2 (see `README_IOS_NATIVE.md`). The iPhone app already writes telemetry into the App Group payload so widgets can read it later.
- **Bluetooth auto car-link on iOS** — `connectivity_plus` does **not** report `ConnectivityResult.bluetooth` on iOS (Android only). No `NSBluetoothAlwaysUsageDescription` is declared because we do not scan CoreBluetooth. Use the manual toggle; wire real connect/disconnect sounds via **Shortcuts → CarPlay/Bluetooth**.
- **Web / Windows GPS** — preview builds keep speed **— / Unavailable** (live hardware path is iPhone/Android only).

## Defaults

- iOS / Android: `useLiveDeviceData = true` on first run.
- Web / desktop preview: `useLiveDeviceData = false` on first run.

## Privacy / Info.plist

Declared today (with in-app pre-prompt before the system dialog):

- Photo library (custom vehicle / layer images)
- Camera (photograph your car)
- Location when in use (GPS speedometers)

Permanently denied → in-app offer to open system Settings.

Not declared (intentionally):

- Bluetooth always / peripheral usage — not used; car-link is manual + Shortcuts.

## Quick verify on device

1. Open Drive Studio on the iPhone → Home should show **Live from this iPhone** with a real battery %.
2. Settings → Device sync → confirm battery / charging / online; grant location and walk/drive to see speed digits update.
3. Deny location → speedometers stay **—** / **GPS · unavailable**.
4. Toggle **Car connected** ON/OFF and confirm Studio badges / App Group `telemetry.carConnected` flip.
5. Sounds → **Playback output**: Phone / Car / Auto. With Auto + Car link on, connect previews prefer the car Bluetooth route; with link off, they prefer iPhone speakers (never earpiece).
6. Optional: Shortcuts automation for Connect/Disconnect cue sounds (Setup guide).
