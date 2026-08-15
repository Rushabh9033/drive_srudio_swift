import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Shared Live Activity attributes
//
// Compiled into BOTH the Runner host app (to start/update/end the
// activity) AND the widget extension (to render the Lock Screen +
// Dynamic Island UI). Lives in the synchronized `DriveStudioWidget/`
// folder so both targets see it without explicit project.pbxproj edits.
//
// Apple requires ActivityAttributes to be Codable + Hashable so the
// system can serialize the activity state across process boundaries.
// `ContentState` is the per-update payload (the data that changes with
// every GPS fix). `Attributes` is the launch-time payload (data that
// doesn't change during the activity — currently nothing because we
// don't know the user's vehicle until they pick one).

public struct DriveStudioActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        public var speedKmh: Double?
        public var isCharging: Bool
        public var batteryPercent: Int?
        public var carConnected: Bool
        public var speedUnit: String
        public var gpsLost: Bool

        public init(
            speedKmh: Double?,
            isCharging: Bool,
            batteryPercent: Int?,
            carConnected: Bool,
            speedUnit: String,
            gpsLost: Bool
        ) {
            self.speedKmh = speedKmh
            self.isCharging = isCharging
            self.batteryPercent = batteryPercent
            self.carConnected = carConnected
            self.speedUnit = speedUnit
            self.gpsLost = gpsLost
        }
    }

    /// Launch-time payload. Currently empty because Drive Studio
    /// reads all live data from the App Group on demand. The
    /// attributes struct still needs to exist for ActivityKit.
    public init() {}
}

// MARK: - Live Activity widget
//
// Renders the Dynamic Island (compact / minimal / expanded) and the
// Lock Screen banner. The widget bundle lists this alongside the
// home-screen widgets so the system knows it's available.
//
// Lock-screen presence is automatic when the activity is active.
// Dynamic Island regions follow the four standard regions defined by
// Apple's Human Interface Guidelines for live activities.
//
// All Live Activity APIs are iOS 16.1+. The deployment target is
// iOS 16.0 so the surrounding types compile in the extension binary
// without crashing on older devices — the whole widget is gated.
@available(iOS 16.1, *)
struct DriveStudioLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DriveStudioActivityAttributes.self) { context in
            // Lock-screen / banner UI.
            DriveStudioLockScreenView(state: context.state)
                .activityBackgroundTint(Color(hex: "0A0A14"))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    DriveStudioExpandedLeading(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    DriveStudioExpandedTrailing(state: context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    DriveStudioExpandedCenter(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DriveStudioExpandedBottom(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .foregroundColor(.cyan)
            } compactTrailing: {
                Text(context.state.gpsLost ? "—" : formattedSpeed(context.state))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: context.state.gpsLost
                      ? "location.slash"
                      : "gauge.with.dots.needle.bottom.50percent")
                    .foregroundColor(context.state.gpsLost ? .orange : .cyan)
            }
            .keylineTint(.cyan)
        }
    }
}

// MARK: - Speed formatting helpers (widget-local; Runner has its own)

/// Render a speed in the user's chosen unit. Mirrors the Runner's
/// formatting rules exactly so the home-screen widget and the Live
/// Activity show the same string for the same speed value.
fileprivate func formattedSpeed(_ state: DriveStudioActivityAttributes.ContentState) -> String {
    guard let kmh = state.speedKmh else { return "—" }
    switch state.speedUnit {
    case "mph":
        let mph = Int(kmh / 1.609344)
        return "\(mph)"
    default:
        return "\(Int(kmh))"
    }
}

/// Speed + unit label (e.g. "60 km/h") for layouts that show the
/// unit alongside the number.
fileprivate func formattedSpeedWithUnit(_ state: DriveStudioActivityAttributes.ContentState) -> String {
    guard let kmh = state.speedKmh else { return "—" }
    switch state.speedUnit {
    case "mph":
        let mph = Int(kmh / 1.609344)
        return "\(mph) mph"
    default:
        return "\(Int(kmh)) km/h"
    }
}

// MARK: - Lock-screen layout

struct DriveStudioLockScreenView: View {
    let state: DriveStudioActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text(formattedSpeedWithUnit(state))
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                if state.gpsLost {
                    HStack(spacing: 4) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 10))
                        Text("GPS lost")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.orange)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if let pct = state.batteryPercent {
                    HStack(spacing: 4) {
                        Text("\(pct)%")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .monospacedDigit()
                        Image(systemName: state.isCharging
                              ? "battery.100.bolt"
                              : "battery.100")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(state.isCharging ? .green : .white)
                    }
                } else {
                    Text("—")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                }
                Text(state.carConnected ? "Linked" : "Not linked")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(state.carConnected
                                ? Color.green.opacity(0.25)
                                : Color.orange.opacity(0.25))
                    .foregroundColor(state.carConnected ? .green : .orange)
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Dynamic Island expanded regions

struct DriveStudioExpandedLeading: View {
    let state: DriveStudioActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.cyan)
            Text("Speed")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
        }
    }
}

struct DriveStudioExpandedTrailing: View {
    let state: DriveStudioActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let pct = state.batteryPercent {
                HStack(spacing: 3) {
                    Text("\(pct)%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    if state.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }
                }
            } else {
                Text("—")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
            }
            Text("Battery")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
        }
    }
}

struct DriveStudioExpandedCenter: View {
    let state: DriveStudioActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 0) {
            Text(formattedSpeed(state))
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundColor(state.gpsLost ? .gray : .white)
                .monospacedDigit()
            Text(state.speedUnit == "mph" ? "mph" : "km/h")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
        }
    }
}

struct DriveStudioExpandedBottom: View {
    let state: DriveStudioActivityAttributes.ContentState

    var body: some View {
        HStack {
            Image(systemName: state.carConnected
                  ? "checkmark.circle.fill"
                  : "circle.dashed")
                .font(.system(size: 11))
                .foregroundColor(state.carConnected ? .green : .orange)
            Text(state.carConnected ? "Car linked" : "Car not linked")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(state.carConnected ? .green : .orange)
            Spacer()
            if state.gpsLost {
                HStack(spacing: 4) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 11))
                    Text("GPS lost")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.orange)
            } else {
                Text("Live")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.25))
                    .cornerRadius(4)
            }
        }
    }
}

