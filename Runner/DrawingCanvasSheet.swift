import SwiftUI
import UIKit

struct LinePath: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var color: Color
    var hexColor: String
    var lineWidth: CGFloat
}

struct DrawingCanvasSheet: View {
    let onSaveDrawing: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var lines: [LinePath] = []
    @State private var currentLine: LinePath? = nil
    @State private var selectedColorHex: String = "00FFFF"
    @State private var strokeWidth: CGFloat = 6.0
    @State private var isGlowEnabled: Bool = true

    private let colors = [
        ("00FFFF", "Cyan"),
        ("FF2D6B", "Neon Pink"),
        ("22C55E", "Acid Green"),
        ("F59E0B", "Amber"),
        ("FFD700", "Gold"),
        ("FFFFFF", "White"),
        ("FF3B30", "Red")
    ]

    var body: some View {
        ZStack {
            DriveColors.background.ignoresSafeArea()

            VStack(spacing: 16) {
                // ── Top Header ──────────────────────────────────────────
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DriveColors.mutedFg)

                    Spacer()

                    Text("Freehand Draw")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(DriveColors.foreground)

                    Spacer()

                    Button(action: saveDrawing) {
                        Text("Done")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color(hex: selectedColorHex) ?? DriveColors.primary)
                            .cornerRadius(999)
                    }
                    .disabled(lines.isEmpty && currentLine == nil)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // ── Interactive Drawing Canvas Area ────────────────────
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(DriveColors.carbon)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(DriveColors.border, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 4)

                    Canvas { context, size in
                        for line in lines {
                            var path = Path()
                            if let first = line.points.first {
                                path.move(to: first)
                                for p in line.points.dropFirst() {
                                    path.addLine(to: p)
                                }
                            }
                            let col = line.color
                            if isGlowEnabled {
                                context.drawLayer { ctx in
                                    ctx.addFilter(.blur(radius: 4))
                                    ctx.stroke(path, with: .color(col.opacity(0.8)), lineWidth: line.lineWidth + 4)
                                }
                            }
                            context.stroke(path, with: .color(col), style: StrokeStyle(lineWidth: line.lineWidth, lineCap: .round, lineJoin: .round))
                        }

                        if let line = currentLine {
                            var path = Path()
                            if let first = line.points.first {
                                path.move(to: first)
                                for p in line.points.dropFirst() {
                                    path.addLine(to: p)
                                }
                            }
                            let col = line.color
                            if isGlowEnabled {
                                context.drawLayer { ctx in
                                    ctx.addFilter(.blur(radius: 4))
                                    ctx.stroke(path, with: .color(col.opacity(0.8)), lineWidth: line.lineWidth + 4)
                                }
                            }
                            context.stroke(path, with: .color(col), style: StrokeStyle(lineWidth: line.lineWidth, lineCap: .round, lineJoin: .round))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let newPoint = value.location
                                if currentLine == nil {
                                    let col = Color(hex: selectedColorHex) ?? .cyan
                                    currentLine = LinePath(points: [newPoint], color: col, hexColor: selectedColorHex, lineWidth: strokeWidth)
                                } else {
                                    currentLine?.points.append(newPoint)
                                }
                            }
                            .onEnded { _ in
                                if let line = currentLine {
                                    lines.append(line)
                                    currentLine = nil
                                }
                            }
                    )
                }
                .frame(width: 320, height: 320)

                // ── Controls: Color Palette, Stroke Size & Clear ────────
                VStack(spacing: 14) {
                    // Color selection
                    HStack(spacing: 14) {
                        ForEach(colors, id: \.0) { hex, _ in
                            Circle()
                                .fill(Color(hex: hex) ?? .white)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedColorHex == hex ? 3 : 0)
                                )
                                .scaleEffect(selectedColorHex == hex ? 1.15 : 1.0)
                                .onTapGesture {
                                    selectedColorHex = hex
                                }
                        }
                    }

                    // Stroke Width & Action Buttons
                    HStack(spacing: 16) {
                        Button(action: {
                            if !lines.isEmpty { lines.removeLast() }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward")
                                Text("Undo")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(DriveColors.foreground)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(DriveColors.secondary)
                            .cornerRadius(10)
                        }
                        .disabled(lines.isEmpty)

                        Button(action: {
                            lines.removeAll()
                            currentLine = nil
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                Text("Clear")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(DriveColors.destructive)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(DriveColors.destructive.opacity(0.12))
                            .cornerRadius(10)
                        }
                        .disabled(lines.isEmpty && currentLine == nil)

                        Spacer()

                        // Thickness selector
                        HStack(spacing: 8) {
                            Text("Size")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(DriveColors.mutedFg)
                            Slider(value: $strokeWidth, in: 2...20)
                                .frame(width: 100)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }

    @MainActor
    private func saveDrawing() {
        let renderer = ImageRenderer(content:
            ZStack {
                Color.clear
                Canvas { context, _ in
                    for line in lines {
                        var path = Path()
                        if let first = line.points.first {
                            path.move(to: first)
                            for p in line.points.dropFirst() {
                                path.addLine(to: p)
                            }
                        }
                        let col = line.color
                        if isGlowEnabled {
                            context.drawLayer { ctx in
                                ctx.addFilter(.blur(radius: 4))
                                ctx.stroke(path, with: .color(col.opacity(0.8)), lineWidth: line.lineWidth + 4)
                            }
                        }
                        context.stroke(path, with: .color(col), style: StrokeStyle(lineWidth: line.lineWidth, lineCap: .round, lineJoin: .round))
                    }
                }
            }
            .frame(width: 320, height: 320)
        )
        renderer.scale = UIScreen.main.scale

        if let uiImage = renderer.uiImage {
            onSaveDrawing(uiImage)
            dismiss()
        }
    }
}
