import SwiftUI

/// 대표 사진 고르기. 하루 한 장에서 고르거나 사진첩에서 한 장을 가져온다. 고르면 `onPick`을 부르고 닫는다.
struct CoverPhotoPickerSheet: View {
    let photos: [DailyPhoto]
    let onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                if !photos.isEmpty {
                    Text("하루 한 장에서 고르기")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DNASpacing.xs) {
                            ForEach(photos.sorted { $0.tripDayIndex < $1.tripDayIndex }) { photo in
                                Button {
                                    onPick(photo.storagePath)
                                    dismiss()
                                } label: {
                                    TripPhotoImage(storagePath: photo.storagePath)
                                        .frame(width: 72, height: 96)
                                        .clipShape(RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Divider().overlay(Color.dnaDivider)
                }
                Text("사진첩에서 고르기")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
                AnyPhotoLibraryPickerButton(title: "사진 선택") { path in
                    onPick(path)
                    dismiss()
                }
                Spacer(minLength: 0)
            }
            .padding(DNASpacing.lg)
            .background(Color.dnaSheet)
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
    }
}
