import SwiftUI

/// Neutral placeholder rendered for symbolic editor guides
/// (`template_car`). Used by both the in-app editor canvas and the
/// home-screen widget so the user sees the same dashed "CAR PHOTO"
/// box on both surfaces.
///
/// Important product truth: `template_car` is NOT a real image
/// filename. It is an intentional visual guide showing the user
/// where to insert their own car/photo image inside a widget
/// design. We never substitute a fake, stock, scraped, generated,
/// or unlicensed car image.
struct VehiclePositionGuideBox: View {
    var primary: Color = Color.cyan
    var label: String = "CAR PHOTO"

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                .foregroundColor(primary.opacity(0.7))

            VStack(spacing: 2) {
                Image(systemName: "car.side.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(primary)
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(primary)
            }
        }
        .padding(2)
    }
}