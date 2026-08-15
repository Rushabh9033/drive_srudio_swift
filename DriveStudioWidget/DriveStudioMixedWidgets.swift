import SwiftUI
import WidgetKit
import UIKit

// MARK: - Real Telemetry Timeline Entry
//
// Every telemetry field is optional on purpose. The widget must render
// an unavailable marker (`—` / `--`) for `nil`; it must never invent a
// number. The non-optional `date` is the only field guaranteed to be
// present (it is the TimelineEntry contract).
struct DriveEntry: TimelineEntry {
    var date: Date
    var speed: Double?       // km/h supplied by host. nil = unknown.
    var batteryLevel: Double? // 0.0…1.0. nil = unknown.
    var isCharging: Bool     // Exact charging state; never ORed with stale.
    var vehicleName: String? // Display name. nil = none selected.
}

// MARK: - Real Hardware & Telemetry Provider
//
// This provider reads ONLY the App Group. It never touches `UIDevice`
// (the widget extension cannot poll sensors reliably and the host app
// is the single owner of telemetry). All decoding flows through
// `WidgetTelemetryReader` so StaticProvider, DriveProvider,
// OrbitDateProvider, and NativeSpecialRenderer share one truth.
struct DriveProvider: TimelineProvider {
    func placeholder(in context: Context) -> DriveEntry {
        WidgetTelemetryFactory.driveEntry(at: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (DriveEntry) -> Void) {
        // WidgetGallery preview: do not invent values; use real reader.
        completion(WidgetTelemetryFactory.driveEntry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DriveEntry>) -> Void) {
        // Apple-documented normal-provider model:
        //   - First entry's `date` represents the current time.
        //   - Subsequent entries are spaced at least ~5 minutes apart.
        //   - `.atEnd` policy asks WidgetKit to call getTimeline again
        //     after the last entry is consumed.
        let now = Date()
        let timeline = WidgetTimelineSchedule.makeProviderTimeline(
            startingAt: now,
            providerEntryCount: WidgetTimelineSchedule.defaultProviderEntryCount,
            factory: { date in
                WidgetTelemetryFactory.driveEntry(at: date)
            }
        )
        completion(timeline)
    }
}

// MARK: - Date Helpers
fileprivate extension Date {
    var timeString: String { let f = DateFormatter(); f.dateFormat = "h:mm"; return f.string(from: self) }
    var dateString: String { let f = DateFormatter(); f.dateFormat = "EEE MMM d"; return f.string(from: self) }
    var ampm: String { Calendar.current.component(.hour, from: self) < 12 ? "AM" : "PM" }
    var hourFraction: Double {
        let c = Calendar.current
        return (Double(c.component(.hour, from: self)).truncatingRemainder(dividingBy: 12) + Double(c.component(.minute, from: self))/60) / 12
    }
    var minuteFraction: Double {
        let c = Calendar.current
        return (Double(c.component(.minute, from: self)) + Double(c.component(.second, from: self))/60) / 60
    }
    var dayFraction: Double {
        let c = Calendar.current
        let h = Double(c.component(.hour, from: self))
        let m = Double(c.component(.minute, from: self))
        let s = Double(c.component(.second, from: self))
        return (h*3600 + m*60 + s) / 86400
    }
}

// MARK: - 1. COMMAND CENTER
// Speed (large) + Clock (top) + Battery arc (bottom)
struct CommandCenterView: View {
    let e: DriveEntry
    var body: some View {
        let bgColor = Color(hex: "060C14")
        // Unknown battery = empty ring + "—". Known battery = exact clamped value.
        let batteryFrac: Double? = e.batteryLevel.map { max(0.0, min(1.0, $0)) }

        let content = ZStack {
            bgColor
            GeometryReader { g in
                let w = g.size.width
                let h = g.size.height
                let s = min(w, h)

                ZStack {
                    RoundedRectangle(cornerRadius: s * 0.08, style: .continuous)
                        .fill(Color(hex: "0D1A2A"))
                        .padding(s * 0.04)

                    VStack(spacing: s * 0.02) {
                        Text(e.date.timeString)
                            .font(.system(size: s * 0.16, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "00E5FF"))

                        Rectangle()
                            .fill(Color(hex: "0D2A3A"))
                            .frame(height: 1)
                            .padding(.horizontal, s * 0.1)

                        HStack(spacing: s * 0.02) {
                            // Unknown speed renders as "--"; genuine zero renders as "0".
                            if let kmh = e.speed {
                                Text("\(Int(kmh))")
                                    .font(.system(size: s * 0.15, weight: .black, design: .rounded))
                                    .foregroundColor(Color(hex: "FF6B35"))
                            } else {
                                Text("--")
                                    .font(.system(size: s * 0.15, weight: .black, design: .rounded))
                                    .foregroundColor(Color(hex: "FF6B35"))
                            }
                            Text("KM/H")
                                .font(.system(size: s * 0.06, weight: .bold))
                                .foregroundColor(Color(hex: "FF6B35").opacity(0.7))
                        }

                        Spacer()

                        ZStack {
                            Circle().trim(from: 0, to: 1)
                                .stroke(Color(hex: "1A3A1A"), lineWidth: s * 0.035)
                                .frame(width: s * 0.22, height: s * 0.22)
                            // Empty ring when battery is unknown; exact fill when known.
                            Circle().trim(from: 0, to: CGFloat(batteryFrac ?? 0))
                                .stroke(Color(hex: "22C55E"), style: StrokeStyle(lineWidth: s * 0.035, lineCap: .round))
                                .frame(width: s * 0.22, height: s * 0.22)
                                .rotationEffect(.degrees(-90))
                            if let frac = batteryFrac {
                                Text("\(Int(frac * 100))%")
                                    .font(.system(size: s * 0.05, weight: .bold))
                                    .foregroundColor(Color(hex: "22C55E"))
                            } else {
                                Text("—")
                                    .font(.system(size: s * 0.05, weight: .bold))
                                    .foregroundColor(Color(hex: "22C55E"))
                            }
                        }
                        .padding(.bottom, s * 0.04)
                    }
                    .padding(.top, s * 0.06)
                }
            }
        }.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

        if #available(iOS 17.0, *) {
            content.containerBackground(bgColor, for: .widget)
        } else {
            content
        }
    }
}

// MARK: - 2. VORTEX DRIVE
// Outer ring = minute progress (purple), inner ring = speed (orange), center = clock
struct VortexDriveView: View {
    let e: DriveEntry
    var body: some View {
        let bgColor = Color(hex: "0A0515")
        let speedFrac: Double? = e.speed.map { max(0.0, min(1.0, $0 / 200.0)) }

        let content = ZStack {
            bgColor
            GeometryReader { g in
                let s = min(g.size.width, g.size.height), cx = g.size.width/2, cy = g.size.height/2
                ZStack {
                    // Outer minute ring
                    Circle().stroke(Color(hex: "1A0830"), lineWidth: s*0.09).frame(width: s*0.78).position(x: cx, y: cy)
                    Circle().trim(from: 0, to: CGFloat(e.date.minuteFraction))
                        .stroke(Color(hex: "7C3AED"), style: StrokeStyle(lineWidth: s*0.09, lineCap: .round))
                        .frame(width: s*0.78).rotationEffect(.degrees(-90)).position(x: cx, y: cy)

                    // Inner speed ring — empty when speed unknown; never an artificial minimum fill.
                    Circle().stroke((Color(hex: "C084FC")).opacity(0.3), lineWidth: s*0.04).frame(width: s*0.60).position(x: cx, y: cy)
                    Circle().trim(from: 0, to: CGFloat(speedFrac ?? 0))
                        .stroke(Color(hex: "F97316"), style: StrokeStyle(lineWidth: s*0.04, lineCap: .round))
                        .frame(width: s*0.60).rotationEffect(.degrees(-90)).position(x: cx, y: cy)

                    // Center
                    Circle().fill(bgColor).frame(width: s*0.44).position(x: cx, y: cy)
                    VStack(spacing: 2) {
                        Text(e.date.timeString).font(.system(size: s*0.14, weight: .black, design: .rounded)).foregroundColor(.white)
                        if let kmh = e.speed {
                            Text(WidgetDisplayMath.formattedSpeed(kmh: kmh)).font(.system(size: s*0.07, weight: .bold)).foregroundColor(Color(hex: "F97316"))
                        } else {
                            Text("--").font(.system(size: s*0.07, weight: .bold)).foregroundColor(Color(hex: "F97316"))
                        }
                    }.position(x: cx, y: cy)
                }
            }
        }.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

        if #available(iOS 17.0, *) {
            content.containerBackground(bgColor, for: .widget)
        } else {
            content
        }
    }
}

// MARK: - 3. GRID HUD
// 2 top tiles (Speed | Battery) + bottom wide clock+date
struct GridHUDView: View {
    let e: DriveEntry
    var body: some View {
        let bgColor = Color(hex: "090D0D")
        let batteryFrac: Double? = e.batteryLevel.map { max(0.0, min(1.0, $0)) }

        let content = ZStack {
            bgColor
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    // Speed tile
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Color(hex: "0D1A1A"))
                        VStack(spacing: 2) {
                            if let kmh = e.speed {
                                Text("\(Int(kmh))").font(.system(size: 26, weight: .black, design: .rounded)).foregroundColor(Color(hex: "00F0FF"))
                            } else {
                                Text("--").font(.system(size: 26, weight: .black, design: .rounded)).foregroundColor(Color(hex: "00F0FF"))
                            }
                            Text(WidgetDisplayMath.speedUnitSuffix()).font(.system(size: 10)).foregroundColor((Color(hex: "00F0FF")).opacity(0.5))
                        }
                    }
                    // Battery tile
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Color(hex: "0D1A1A"))
                        VStack(spacing: 4) {
                            if let frac = batteryFrac {
                                Text("\(Int(frac * 100))%").font(.system(size: 20, weight: .black, design: .rounded)).foregroundColor(Color(hex: "22C55E"))
                            } else {
                                Text("—").font(.system(size: 20, weight: .black, design: .rounded)).foregroundColor(Color(hex: "22C55E"))
                            }
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4).fill(Color(hex: "1A3A1A")).frame(height: 8)
                                    // Empty track when battery unknown; exact width when known.
                                    RoundedRectangle(cornerRadius: 4).fill(Color(hex: "22C55E")).frame(width: g.size.width*CGFloat(batteryFrac ?? 0), height: 8)
                                }
                            }.frame(height: 8).padding(.horizontal, 8)
                        }
                    }
                }.padding(.horizontal, 10).padding(.top, 10)

                // Clock+date tile
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color(hex: "1A2020"))
                    VStack(spacing: 3) {
                        Text(e.date.timeString).font(.system(size: 30, weight: .black, design: .rounded)).foregroundColor(.white)
                        Text(e.date.dateString).font(.system(size: 10, weight: .medium)).foregroundColor(Color(hex: "4DC98A"))
                    }
                }.padding(.horizontal, 10).padding(.bottom, 10)
            }
        }.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

        if #available(iOS 17.0, *) {
            content.containerBackground(bgColor, for: .widget)
        } else {
            content
        }
    }
}

// MARK: - 4. COCKPIT
// Analog clock (large) + speed badge bottom + battery top bar
struct CockpitView: View {
    let e: DriveEntry
    var body: some View {
        let bgColor = Color(hex: "0C0C0C")
        let batteryFrac: Double? = e.batteryLevel.map { max(0.0, min(1.0, $0)) }

        let content = ZStack {
            bgColor
            GeometryReader { g in
                let s = min(g.size.width, g.size.height), cx = g.size.width/2, cy = g.size.height/2-8
                let R = s*0.40
                ZStack {
                    // Battery bar top — empty track when battery unknown.
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color(hex: "111111")).frame(height: 5)
                        RoundedRectangle(cornerRadius: 3).fill(Color(hex: "22C55E")).frame(width: g.size.width*0.55*CGFloat(batteryFrac ?? 0), height: 5)
                    }.frame(width: g.size.width*0.55).position(x: g.size.width*0.36, y: 14)
                    if let frac = batteryFrac {
                        Text("\(Int(frac * 100))%").font(.system(size: 8, weight: .medium)).foregroundColor(Color(hex: "22C55E")).position(x: g.size.width*0.76, y: 14)
                    } else {
                        Text("—").font(.system(size: 8, weight: .medium)).foregroundColor(Color(hex: "22C55E")).position(x: g.size.width*0.76, y: 14)
                    }

                    // Tick marks
                    ForEach(0..<60, id: \.self) { i in
                        let a = Double(i)/60*Double.pi*2 - Double.pi/2
                        let isM = i%5==0, r1 = R-(isM ? 10 : 5), r2 = R
                        Path { p in
                            p.move(to: CGPoint(x: cx+cos(a)*r1, y: cy+sin(a)*r1))
                            p.addLine(to: CGPoint(x: cx+cos(a)*r2, y: cy+sin(a)*r2))
                        }.stroke(isM ? (Color(hex: "333333")) : (Color(hex: "1E1E1E")), lineWidth: isM ? 2 : 1)
                    }

                    // Hour hand
                    let hA = e.date.hourFraction * Double.pi*2 - Double.pi/2
                    Path { p in
                        p.move(to: CGPoint(x: cx, y: cy))
                        p.addLine(to: CGPoint(x: cx+cos(hA)*R*0.55, y: cy+sin(hA)*R*0.55))
                    }.stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))

                    // Minute hand
                    let mA = e.date.minuteFraction * Double.pi*2 - Double.pi/2
                    Path { p in
                        p.move(to: CGPoint(x: cx, y: cy))
                        p.addLine(to: CGPoint(x: cx+cos(mA)*R*0.82, y: cy+sin(mA)*R*0.82))
                    }.stroke(Color(hex: "FF4444"), style: StrokeStyle(lineWidth: 2, lineCap: .round))

                    Circle().fill(Color(hex: "FF4444")).frame(width: 8).position(x: cx, y: cy)

                    // Speed badge
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(Color(hex: "1A0A0A"))
                        if let kmh = e.speed {
                            Text(WidgetDisplayMath.formattedSpeed(kmh: kmh)).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(Color(hex: "FF6B35"))
                        } else {
                            Text("--").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(Color(hex: "FF6B35"))
                        }
                    }.frame(width: 80, height: 26).position(x: cx, y: cy+R+18)
                }
            }
        }.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

        if #available(iOS 17.0, *) {
            content.containerBackground(bgColor, for: .widget)
        } else {
            content
        }
    }
}

// MARK: - 5. PHANTOM
// Purple gradient header with clock + vehicle info card + battery arc
struct PhantomView: View {
    let e: DriveEntry
    var body: some View {
        let bgColor = Color(hex: "080512")
        let batteryFrac: Double? = e.batteryLevel.map { max(0.0, min(1.0, $0)) }

        let content = ZStack {
            bgColor
            VStack(spacing: 0) {
                // Header
                ZStack {
                    LinearGradient(colors: [Color(hex: "4F46E5"), Color(hex: "7C3AED")], startPoint: .leading, endPoint: .trailing)
                    VStack(spacing: 2) {
                        Text(e.date.timeString).font(.system(size: 30, weight: .black, design: .rounded)).foregroundColor(.white)
                        Text(e.date.ampm).font(.system(size: 9, weight: .medium)).foregroundColor(.white.opacity(0.5))
                    }.padding(.top, 4)
                }.frame(height: 60).clipShape(UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))

                // Vehicle card — shows the live selected-vehicle label.
                // The previous version rendered a hardcoded "Premium · EV"
                // subtitle here regardless of the user's actual vehicle;
                // removed so the widget never displays a category the
                // user did not select. If no vehicle is selected,
                // `WidgetDisplayMath.vehicleLabel` already returns "—".
                ZStack {
                    Color(hex: "1A1230")
                    VStack(spacing: 3) {
                        Text(WidgetDisplayMath.vehicleLabel(e.vehicleName)).font(.system(size: 11, weight: .medium)).foregroundColor(Color(hex: "A78BFA"))
                    }
                }.frame(height: 46)

                // Battery arc
                Spacer()
                ZStack {
                    Circle().trim(from: 0, to: 1).stroke(Color(hex: "1A0830"), lineWidth: 8).frame(width: 48).rotationEffect(.degrees(180))
                    Circle().trim(from: 0, to: CGFloat(batteryFrac ?? 0))
                        .stroke(Color(hex: "A78BFA"), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 48).rotationEffect(.degrees(180))
                    VStack(spacing: 0) {
                        if let frac = batteryFrac {
                            Text("\(Int(frac * 100))%").font(.system(size: 9, weight: .bold)).foregroundColor(Color(hex: "A78BFA"))
                        } else {
                            Text("—").font(.system(size: 9, weight: .bold)).foregroundColor(Color(hex: "A78BFA"))
                        }
                        Text("battery").font(.system(size: 8)).foregroundColor(Color(hex: "444444"))
                    }
                }.padding(.bottom, 14)
            }
        }.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

        if #available(iOS 17.0, *) {
            content.containerBackground(bgColor, for: .widget)
        } else {
            content
        }
    }
}

// MARK: - 6. SPLIT PANEL
// Top half = teal clock+date, bottom half = orange speed, full-width battery bar at bottom
struct SplitPanelView: View {
    let e: DriveEntry
    var body: some View {
        let bgColor = Color(hex: "050A0A")
        let batteryFrac: Double? = e.batteryLevel.map { max(0.0, min(1.0, $0)) }

        let content = ZStack {
            bgColor
            VStack(spacing: 0) {
                // Top — clock
                ZStack {
                    Color(hex: "0D1A1A")
                    VStack(spacing: 3) {
                        Text(e.date.timeString).font(.system(size: 34, weight: .black, design: .rounded)).foregroundColor(Color(hex: "00F0FF"))
                        Text(e.date.dateString).font(.system(size: 10, weight: .medium)).foregroundColor(Color(hex: "4DC98A"))
                    }
                }
                Divider().background((Color(hex: "00F0FF")).opacity(0.2))

                // Bottom — speed
                ZStack {
                    Color.clear
                    VStack(spacing: 2) {
                        if let kmh = e.speed {
                            Text("\(Int(kmh))").font(.system(size: 36, weight: .black, design: .rounded)).foregroundColor(Color(hex: "FF6B35"))
                        } else {
                            Text("--").font(.system(size: 36, weight: .black, design: .rounded)).foregroundColor(Color(hex: "FF6B35"))
                        }
                        Text("KM / H").font(.system(size: 11, weight: .bold)).foregroundColor((Color(hex: "FF6B35")).opacity(0.4))
                    }
                }

                // Battery bar — empty track when unknown.
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color(hex: "111111"))
                        Rectangle().fill(Color(hex: "00F0FF")).frame(width: g.size.width*CGFloat(batteryFrac ?? 0))
                    }
                }.frame(height: 18).overlay(
                    Group {
                        if let frac = batteryFrac {
                            Text("\(Int(frac * 100))% battery").font(.system(size: 9, weight: .bold)).foregroundColor(.black)
                        } else {
                            Text("— battery").font(.system(size: 9, weight: .bold)).foregroundColor(.black)
                        }
                    }
                )
            }
        }.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

        if #available(iOS 17.0, *) {
            content.containerBackground(bgColor, for: .widget)
        } else {
            content
        }
    }
}

// MARK: - 7. SOLAR DASH
// 3 concentric rings: day fraction (blue), battery (green), speed (orange) + clock center + date bottom
struct SolarDashView: View {
    let e: DriveEntry
    var body: some View {
        let bgColor = Color(hex: "050810")
        let batteryFrac: Double? = e.batteryLevel.map { max(0.0, min(1.0, $0)) }
        let speedFrac: Double? = e.speed.map { max(0.0, min(1.0, $0 / 200.0)) }

        let content = ZStack {
            bgColor
            GeometryReader { g in
                let s = min(g.size.width, g.size.height), cx = g.size.width/2, cy = g.size.height/2-8
                let rings: [(Double, String, Double)] = [
                    (e.date.dayFraction, "378ADD", 54),
                    (batteryFrac ?? 0, "22C55E", 42),
                    (speedFrac ?? 0, "F97316", 30)
                ]
                ZStack {
                    ForEach(Array(rings.enumerated()), id: \.offset) { pair in
                        let (frac, c, r) = pair.element
                        let R = s*r/100
                        let ringColor = Color(hex: c) ?? .blue
                        Circle().stroke(ringColor.opacity(0.2), lineWidth: s*0.055).frame(width: R*2).position(x: cx, y: cy)
                        Circle().trim(from: 0, to: CGFloat(frac))
                            .stroke(ringColor, style: StrokeStyle(lineWidth: s*0.055, lineCap: .round))
                            .frame(width: R*2).rotationEffect(.degrees(-90)).position(x: cx, y: cy)
                    }
                    Circle().fill(bgColor).frame(width: s*0.24).position(x: cx, y: cy)
                    Text(e.date.timeString).font(.system(size: s*0.13, weight: .black, design: .rounded)).foregroundColor(.white).position(x: cx, y: cy-s*0.02)
                    Text(e.date.dateString).font(.system(size: s*0.065, weight: .medium)).foregroundColor(Color(hex: "4DC98A")).position(x: cx, y: g.size.height-14)
                }
            }
        }.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

        if #available(iOS 17.0, *) {
            content.containerBackground(bgColor, for: .widget)
        } else {
            content
        }
    }
}

// MARK: - 8. NEON STRIP
// Pink neon speed top, cyan neon battery bar bottom, white clock middle
struct NeonStripView: View {
    let e: DriveEntry
    var body: some View {
        let bgColor = Color(hex: "0A0A0A")
        let batteryFrac: Double? = e.batteryLevel.map { max(0.0, min(1.0, $0)) }
        let speedFrac: Double? = e.speed.map { max(0.0, min(1.0, $0 / 200.0)) }

        let content = ZStack {
            bgColor
            VStack(spacing: 0) {
                Spacer()
                // Speed
                if let kmh = e.speed {
                    Text("\(Int(kmh))").font(.system(size: 50, weight: .black, design: .rounded)).foregroundColor(Color(hex: "FF2D6B"))
                } else {
                    Text("--").font(.system(size: 50, weight: .black, design: .rounded)).foregroundColor(Color(hex: "FF2D6B"))
                }
                Text("KM/H").font(.system(size: 11, weight: .medium)).foregroundColor((Color(hex: "FF2D6B")).opacity(0.6))

                // Speed bar — empty track when speed unknown.
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Rectangle().fill((Color(hex: "FF2D6B")).opacity(0.15)).frame(height: 2)
                        Rectangle().fill(Color(hex: "FF2D6B")).frame(width: g.size.width*CGFloat(speedFrac ?? 0), height: 2)
                    }.offset(y: 1)
                }.frame(height: 4).padding(.horizontal, 16).padding(.bottom, 8)

                // Clock + date
                Text(e.date.timeString).font(.system(size: 22, weight: .black, design: .rounded)).foregroundColor(.white)
                Text(e.date.dateString).font(.system(size: 10, weight: .medium)).foregroundColor(Color(hex: "00E5FF"))
                if let frac = batteryFrac {
                    Text("\(Int(frac * 100))% battery").font(.system(size: 10)).foregroundColor((Color(hex: "00E5FF")).opacity(0.6)).padding(.top, 4)
                } else {
                    Text("— battery").font(.system(size: 10)).foregroundColor((Color(hex: "00E5FF")).opacity(0.6)).padding(.top, 4)
                }

                // Battery bar
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Rectangle().fill((Color(hex: "00E5FF")).opacity(0.15)).frame(height: 2)
                        Rectangle().fill(Color(hex: "00E5FF")).frame(width: g.size.width*CGFloat(batteryFrac ?? 0), height: 2)
                    }.offset(y: 1)
                }.frame(height: 4).padding(.horizontal, 16).padding(.top, 4)
                Spacer()

                // Bottom speed label
                ZStack {
                    Color(hex: "111111")
                    if let kmh = e.speed {
                        Text("\(WidgetDisplayMath.formattedSpeed(kmh: kmh)) · speed").font(.system(size: 9, weight: .bold)).foregroundColor(Color(hex: "FF2D6B"))
                    } else {
                        Text("-- · speed").font(.system(size: 9, weight: .bold)).foregroundColor(Color(hex: "FF2D6B"))
                    }
                }.frame(height: 18).clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 22, bottomTrailingRadius: 22))
            }
        }.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

        if #available(iOS 17.0, *) {
            content.containerBackground(bgColor, for: .widget)
        } else {
            content
        }
    }
}

// MARK: - 9. CARBON
// Carbon-texture bg, analog clock, battery bar + date strip
struct CarbonView: View {
    let e: DriveEntry
    var body: some View {
        let bgColor = Color(hex: "0A0A0A")
        let batteryFrac: Double? = e.batteryLevel.map { max(0.0, min(1.0, $0)) }

        let content = ZStack {
            bgColor
            Canvas { ctx, size in
                for i in stride(from: 0, to: size.width, by: 8) {
                    for j in stride(from: 0, to: size.height, by: 8) {
                        ctx.fill(Path(CGRect(x: i, y: j, width: 7, height: 7)), with: .color(Color(hex: "111111")))
                    }
                }
            }.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            bgColor.opacity(0.55)

            GeometryReader { g in
                let s = min(g.size.width, g.size.height), cx = g.size.width/2, cy = g.size.height/2-14
                let R = s*0.38
                ZStack {
                    ForEach(0..<12, id: \.self) { i in
                        let a = Double(i)/12*Double.pi*2 - Double.pi/2
                        Path { p in
                            p.move(to: CGPoint(x: cx+cos(a)*R*0.84, y: cy+sin(a)*R*0.84))
                            p.addLine(to: CGPoint(x: cx+cos(a)*R, y: cy+sin(a)*R))
                        }.stroke(Color(hex: "333333"), lineWidth: 2)
                    }
                    let hA = e.date.hourFraction*Double.pi*2 - Double.pi/2
                    let mA = e.date.minuteFraction*Double.pi*2 - Double.pi/2
                    Path { p in
                        p.move(to: CGPoint(x: cx, y: cy))
                        p.addLine(to: CGPoint(x: cx+cos(hA)*R*0.56, y: cy+sin(hA)*R*0.56))
                    }.stroke(Color(hex: "DBEAFE"), style: StrokeStyle(lineWidth: 3, lineCap: .round))

                    Path { p in
                        p.move(to: CGPoint(x: cx, y: cy))
                        p.addLine(to: CGPoint(x: cx+cos(mA)*R*0.80, y: cy+sin(mA)*R*0.80))
                    }.stroke(Color(hex: "60A5FA"), style: StrokeStyle(lineWidth: 2, lineCap: .round))

                    Circle().fill(Color(hex: "60A5FA")).frame(width: 8).position(x: cx, y: cy)

                    // Battery + date strip
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.7))
                        VStack(spacing: 3) {
                            GeometryReader { bg in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: "1A3A1A")).frame(height: 6)
                                    // Empty track when battery unknown.
                                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: "22C55E")).frame(width: bg.size.width*CGFloat(batteryFrac ?? 0), height: 6)
                                }
                            }.frame(height: 6).padding(.horizontal, 10)
                            if let frac = batteryFrac {
                                Text("\(Int(frac * 100))% batt · " + e.date.dateString)
                                    .font(.system(size: 9, weight: .medium)).foregroundColor(Color(hex: "22C55E"))
                            } else {
                                Text("— batt · " + e.date.dateString)
                                    .font(.system(size: 9, weight: .medium)).foregroundColor(Color(hex: "22C55E"))
                            }
                        }
                    }.frame(width: g.size.width-20, height: 32).position(x: cx, y: g.size.height-22)
                }
            }
        }.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

        if #available(iOS 17.0, *) {
            content.containerBackground(bgColor, for: .widget)
        } else {
            content
        }
    }
}

// MARK: - 10. RADAR
// Large speedometer arc (top 3/4 sweep) + clock center + battery mini-bar bottom
struct RadarView: View {
    let e: DriveEntry
    var body: some View {
        let bgColor = Color(hex: "030812")
        let batteryFrac: Double? = e.batteryLevel.map { max(0.0, min(1.0, $0)) }
        let spd: Double? = e.speed.map { max(0.0, min(1.0, $0 / 200.0)) }

        let content = ZStack {
            bgColor
            GeometryReader { g in
                let s = min(g.size.width, g.size.height), cx = g.size.width/2, cy = g.size.height/2-4
                let R = s*0.40, sw = s*0.10
                let startA = 0.8*Double.pi, sweep = 1.4*Double.pi
                ZStack {
                    // Track
                    Path { p in p.addArc(center: CGPoint(x: cx, y: cy), radius: R, startAngle: .radians(startA), endAngle: .radians(startA+sweep), clockwise: false) }
                        .stroke(Color(hex: "0A1A2A"), style: StrokeStyle(lineWidth: sw, lineCap: .round))

                    // Speed arc — empty track when speed unknown.
                    Path { p in p.addArc(center: CGPoint(x: cx, y: cy), radius: R, startAngle: .radians(startA), endAngle: .radians(startA+(spd ?? 0)*sweep), clockwise: false) }
                        .stroke(Color(hex: "00E5FF"), style: StrokeStyle(lineWidth: sw, lineCap: .round))

                    // Tick marks
                    ForEach(0...10, id: \.self) { i in
                        let a = startA + (Double(i)/10)*sweep
                        let lit = Double(i)/10 <= (spd ?? 0)
                        Path { p in
                            p.move(to: CGPoint(x: cx+cos(a)*(R-sw*0.7), y: cy+sin(a)*(R-sw*0.7)))
                            p.addLine(to: CGPoint(x: cx+cos(a)*(R-sw*0.1), y: cy+sin(a)*(R-sw*0.1)))
                        }.stroke(lit ? (Color(hex: "00E5FF")) : (Color(hex: "1A3A4A")), lineWidth: 2)
                    }

                    // Speed number
                    if let kmh = e.speed {
                        Text("\(Int(kmh))").font(.system(size: s*0.19, weight: .black, design: .rounded)).foregroundColor(Color(hex: "00E5FF")).position(x: cx, y: cy-s*0.04)
                    } else {
                        Text("--").font(.system(size: s*0.19, weight: .black, design: .rounded)).foregroundColor(Color(hex: "00E5FF")).position(x: cx, y: cy-s*0.04)
                    }
                    Text("KM/H").font(.system(size: s*0.065)).foregroundColor((Color(hex: "00E5FF")).opacity(0.5)).position(x: cx, y: cy+s*0.09)

                    // Clock
                    Text(e.date.timeString).font(.system(size: s*0.085, weight: .bold, design: .rounded)).foregroundColor(.white).position(x: cx, y: cy+s*0.21)

                    // Battery bar — empty track when battery unknown.
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color(hex: "111111")).frame(height: 8)
                        RoundedRectangle(cornerRadius: 4).fill(Color(hex: "22C55E")).frame(width: (g.size.width-80)*CGFloat(batteryFrac ?? 0), height: 8)
                    }.frame(width: g.size.width-80).position(x: cx, y: g.size.height-18)
                    if let frac = batteryFrac {
                        Text("\(Int(frac * 100))%").font(.system(size: 8)).foregroundColor(Color(hex: "22C55E")).position(x: cx, y: g.size.height-8)
                    } else {
                        Text("—").font(.system(size: 8)).foregroundColor(Color(hex: "22C55E")).position(x: cx, y: g.size.height-8)
                    }
                }
            }
        }.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

        if #available(iOS 17.0, *) {
            content.containerBackground(bgColor, for: .widget)
        } else {
            content
        }
    }
}

// MARK: - 11. TRI-ZONE
// Top wide = clock + date, bottom-left = speed, bottom-right = battery ring
struct TriZoneView: View {
    let e: DriveEntry
    var body: some View {
        let bgColor = Color(hex: "06080C")
        let batteryFrac: Double? = e.batteryLevel.map { max(0.0, min(1.0, $0)) }

        let content = ZStack {
            bgColor
            VStack(spacing: 6) {
                // Top clock zone
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color(hex: "0D1020"))
                    VStack(spacing: 2) {
                        Text(e.date.timeString).font(.system(size: 30, weight: .black, design: .rounded)).foregroundColor(.white)
                        Text(e.date.dateString).font(.system(size: 10, weight: .medium)).foregroundColor(Color(hex: "4F46E5"))
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 6) {
                    // Speed zone
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Color(hex: "0D1A10"))
                        VStack(spacing: 1) {
                            if let kmh = e.speed {
                                Text("\(Int(kmh))").font(.system(size: 24, weight: .black, design: .rounded)).foregroundColor(Color(hex: "FF6B35"))
                            } else {
                                Text("--").font(.system(size: 24, weight: .black, design: .rounded)).foregroundColor(Color(hex: "FF6B35"))
                            }
                            Text("KM/H").font(.system(size: 9)).foregroundColor((Color(hex: "FF6B35")).opacity(0.4))
                        }
                    }
                    // Battery zone — empty ring when battery unknown.
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Color(hex: "0A1A10"))
                        ZStack {
                            Circle().trim(from: 0, to: 1).stroke(Color(hex: "1A3A1A"), lineWidth: 8).frame(width: 44)
                            Circle().trim(from: 0, to: CGFloat(batteryFrac ?? 0))
                                .stroke(Color(hex: "22C55E"), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: 44).rotationEffect(.degrees(-90))
                            if let frac = batteryFrac {
                                Text("\(Int(frac * 100))%").font(.system(size: 11, weight: .bold)).foregroundColor(Color(hex: "22C55E"))
                            } else {
                                Text("—").font(.system(size: 11, weight: .bold)).foregroundColor(Color(hex: "22C55E"))
                            }
                        }
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }.padding(8)
        }.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

        if #available(iOS 17.0, *) {
            content.containerBackground(bgColor, for: .widget)
        } else {
            content
        }
    }
}

// MARK: - 12. GALAXY
// 4 orbit rings (day, battery, speed, minutes) + tiny clock center
struct GalaxyView: View {
    let e: DriveEntry
    var body: some View {
        let bgColor = Color(hex: "020508")
        let batteryFrac: Double? = e.batteryLevel.map { max(0.0, min(1.0, $0)) }
        let speedFrac: Double? = e.speed.map { max(0.0, min(1.0, $0 / 200.0)) }

        let content = ZStack {
            bgColor
            GeometryReader { g in
                let s = min(g.size.width, g.size.height), cx = g.size.width/2, cy = g.size.height/2
                let orbits: [(Double, String, Double, Double)] = [
                    (e.date.dayFraction, "7C3AED", 66, 5),
                    (batteryFrac ?? 0, "06B6D4", 55, 5),
                    (speedFrac ?? 0, "F59E0B", 44, 5),
                    (e.date.minuteFraction, "10B981", 33, 4)
                ]
                ZStack {
                    ForEach(Array(orbits.enumerated()), id: \.offset) { pair in
                        let (frac, c, r, lw) = pair.element
                        let R = s*r/100
                        let ringColor = Color(hex: c) ?? .purple
                        Circle().stroke(ringColor.opacity(0.15), lineWidth: lw).frame(width: R*2).position(x: cx, y: cy)
                        Circle().trim(from: 0, to: CGFloat(frac))
                            .stroke(ringColor, style: StrokeStyle(lineWidth: lw, lineCap: .round))
                            .frame(width: R*2).rotationEffect(.degrees(-90)).position(x: cx, y: cy)

                        let dotA = frac*Double.pi*2 - Double.pi/2
                        Circle().fill(ringColor).frame(width: lw+2).position(x: cx+cos(dotA)*R, y: cy+sin(dotA)*R)
                    }

                    Circle().fill(bgColor).frame(width: s*0.28).position(x: cx, y: cy)
                    Text(e.date.timeString).font(.system(size: s*0.10, weight: .black, design: .rounded)).foregroundColor(.white).position(x: cx, y: cy-s*0.015)
                    if let kmh = e.speed {
                        Text("\(Int(kmh))km").font(.system(size: s*0.055)).foregroundColor((Color(hex: "7C3AED")).opacity(0.6)).position(x: cx, y: cy+s*0.07)
                    } else {
                        Text("--km").font(.system(size: s*0.055)).foregroundColor((Color(hex: "7C3AED")).opacity(0.6)).position(x: cx, y: cy+s*0.07)
                    }
                }
            }
        }.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

        if #available(iOS 17.0, *) {
            content.containerBackground(bgColor, for: .widget)
        } else {
            content
        }
    }
}

// MARK: - Widget Configurations (12 Mixed Widgets)

struct CommandCenterWidget: Widget {
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: "CommandCenter", provider: DriveProvider()) { e in
            MinuteClockView(data: e) { displayDate, captured in
                var liveEntry = captured
                liveEntry.date = displayDate
                return CommandCenterView(e: liveEntry)
            }
        }
        .configurationDisplayName("Command Center")
        .description("Speed · Clock · Battery")
        .supportedFamilies([.systemSmall, .systemMedium])

        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

struct VortexDriveWidget: Widget {
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: "VortexDrive", provider: DriveProvider()) { e in
            MinuteClockView(data: e) { displayDate, captured in
                var liveEntry = captured
                liveEntry.date = displayDate
                return VortexDriveView(e: liveEntry)
            }
        }
        .configurationDisplayName("Vortex Drive")
        .description("Speed ring · Clock · Minutes ring")
        .supportedFamilies([.systemSmall, .systemMedium])

        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

struct GridHUDWidget: Widget {
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: "GridHUD", provider: DriveProvider()) { e in
            MinuteClockView(data: e) { displayDate, captured in
                var liveEntry = captured
                liveEntry.date = displayDate
                return GridHUDView(e: liveEntry)
            }
        }
        .configurationDisplayName("Grid HUD")
        .description("Speed · Battery · Clock · Date")
        .supportedFamilies([.systemSmall, .systemMedium])

        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

struct CockpitWidget: Widget {
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: "Cockpit", provider: DriveProvider()) { e in
            MinuteClockView(data: e) { displayDate, captured in
                var liveEntry = captured
                liveEntry.date = displayDate
                return CockpitView(e: liveEntry)
            }
        }
        .configurationDisplayName("Cockpit")
        .description("Analog clock · Speed · Battery")
        .supportedFamilies([.systemSmall, .systemMedium])

        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

struct PhantomWidget: Widget {
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: "Phantom", provider: DriveProvider()) { e in
            MinuteClockView(data: e) { displayDate, captured in
                var liveEntry = captured
                liveEntry.date = displayDate
                return PhantomView(e: liveEntry)
            }
        }
        .configurationDisplayName("Phantom")
        .description("Clock · Vehicle name · Battery")
        .supportedFamilies([.systemSmall, .systemMedium])

        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

struct SplitPanelWidget: Widget {
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: "SplitPanel", provider: DriveProvider()) { e in
            MinuteClockView(data: e) { displayDate, captured in
                var liveEntry = captured
                liveEntry.date = displayDate
                return SplitPanelView(e: liveEntry)
            }
        }
        .configurationDisplayName("Split Panel")
        .description("Clock · Speed · Battery bar")
        .supportedFamilies([.systemSmall, .systemMedium])

        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

struct SolarDashWidget: Widget {
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: "SolarDash", provider: DriveProvider()) { e in
            MinuteClockView(data: e) { displayDate, captured in
                var liveEntry = captured
                liveEntry.date = displayDate
                return SolarDashView(e: liveEntry)
            }
        }
        .configurationDisplayName("Solar Dash")
        .description("3 orbit rings · Clock · Date")
        .supportedFamilies([.systemSmall, .systemMedium])

        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

struct NeonStripWidget: Widget {
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: "NeonStrip", provider: DriveProvider()) { e in
            MinuteClockView(data: e) { displayDate, captured in
                var liveEntry = captured
                liveEntry.date = displayDate
                return NeonStripView(e: liveEntry)
            }
        }
        .configurationDisplayName("Neon Strip")
        .description("Speed · Clock · Battery neon bars")
        .supportedFamilies([.systemSmall, .systemMedium])

        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

struct CarbonWidget: Widget {
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: "Carbon", provider: DriveProvider()) { e in
            MinuteClockView(data: e) { displayDate, captured in
                var liveEntry = captured
                liveEntry.date = displayDate
                return CarbonView(e: liveEntry)
            }
        }
        .configurationDisplayName("Carbon")
        .description("Analog · Battery bar · Date")
        .supportedFamilies([.systemSmall, .systemMedium])

        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

struct RadarWidget: Widget {
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: "Radar", provider: DriveProvider()) { e in
            MinuteClockView(data: e) { displayDate, captured in
                var liveEntry = captured
                liveEntry.date = displayDate
                return RadarView(e: liveEntry)
            }
        }
        .configurationDisplayName("Radar")
        .description("Speed arc · Clock · Battery")
        .supportedFamilies([.systemSmall, .systemMedium])

        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

struct TriZoneWidget: Widget {
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: "TriZone", provider: DriveProvider()) { e in
            MinuteClockView(data: e) { displayDate, captured in
                var liveEntry = captured
                liveEntry.date = displayDate
                return TriZoneView(e: liveEntry)
            }
        }
        .configurationDisplayName("Tri-Zone")
        .description("Clock · Speed · Battery · Date")
        .supportedFamilies([.systemSmall, .systemMedium])

        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

struct GalaxyWidget: Widget {
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: "Galaxy", provider: DriveProvider()) { e in
            MinuteClockView(data: e) { displayDate, captured in
                var liveEntry = captured
                liveEntry.date = displayDate
                return GalaxyView(e: liveEntry)
            }
        }
        .configurationDisplayName("Galaxy")
        .description("4 orbit rings · Clock · Speed")
        .supportedFamilies([.systemSmall, .systemMedium])
        
        if #available(iOS 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}
