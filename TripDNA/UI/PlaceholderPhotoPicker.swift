import SwiftUI

struct PlaceholderPhotoOption: Identifiable {
    let id = UUID()
    let symbol: String
    let color: Color
}

struct PlaceholderPhotoPicker: View {
    let onSelect: (String) -> Void

    private let options: [PlaceholderPhotoOption] = [
        PlaceholderPhotoOption(symbol: "sun.max.fill", color: .orange),
        PlaceholderPhotoOption(symbol: "water.waves", color: .blue),
        PlaceholderPhotoOption(symbol: "mountain.2.fill", color: .green),
        PlaceholderPhotoOption(symbol: "building.2.fill", color: .gray),
        PlaceholderPhotoOption(symbol: "fork.knife", color: .red),
        PlaceholderPhotoOption(symbol: "moon.stars.fill", color: .indigo),
        PlaceholderPhotoOption(symbol: "leaf.fill", color: .mint),
        PlaceholderPhotoOption(symbol: "camera.fill", color: .purple)
    ]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 10)], spacing: 10) {
            ForEach(options) { option in
                Button {
                    onSelect("local://placeholder/\(option.symbol)")
                } label: {
                    Image(systemName: option.symbol)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 70, height: 70)
                        .background(option.color.gradient, in: RoundedRectangle(cornerRadius: DNARadius.control - 2))
                        .overlay(
                            RoundedRectangle(cornerRadius: DNARadius.control - 2)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

extension String {
    var placeholderPhotoSymbol: String? {
        guard hasPrefix("local://placeholder/") else { return nil }
        return String(dropFirst("local://placeholder/".count))
    }
}

#Preview("PlaceholderPhotoPicker") {
    PlaceholderPhotoPicker { _ in }
        .padding()
}
