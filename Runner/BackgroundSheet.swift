import SwiftUI

struct BackgroundSheet: View {
    @Environment(\.dismiss) var dismiss
    var onSelect: (WidgetBackground) -> Void
    
    let solidColors = [
        "18181A", "000000", "FFFFFF", "EF4444", "F59E0B", "84CC16", "3B82F6", "8B5CF6", "EC4899"
    ]
    
    let gradients: [(String, String)] = [
        ("1A1A1A", "000000"),
        ("1E1E1E", "0A0A0A"),
        ("0F2027", "203A43"),
        ("2C3E50", "3498DB"),
        ("ED4264", "FFEDBC"),
        ("8E2DE2", "4A00E0")
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    SectionView(title: "Solid Colors") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                            ForEach(solidColors, id: \.self) { hex in
                                Button {
                                    onSelect(WidgetBackground(type: "solid", from: hex, to: nil, imageSrc: nil))
                                    dismiss()
                                } label: {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(height: 60)
                                        .overlay(Circle().stroke(DriveColors.border, lineWidth: 1))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    SectionView(title: "Gradients") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                            ForEach(gradients, id: \.0) { grad in
                                Button {
                                    onSelect(WidgetBackground(type: "gradient", from: grad.0, to: grad.1, imageSrc: nil))
                                    dismiss()
                                } label: {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(LinearGradient(
                                            gradient: Gradient(colors: [Color(hex: grad.0), Color(hex: grad.1)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .frame(height: 80)
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(DriveColors.border, lineWidth: 1))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 24)
            }
            .background(DriveColors.background)
            .navigationTitle("Backgrounds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // Helper view for sections
    struct SectionView<Content: View>: View {
        let title: String
        @ViewBuilder let content: Content
        
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                
                content
            }
        }
    }
}
