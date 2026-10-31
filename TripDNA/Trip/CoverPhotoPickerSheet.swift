import SwiftUI

/// 대표 사진 고르기. 하루 한 장, 여행 기간에 찍은 위치 있는 사진, 사진첩 전체(더 보기) 순으로 고른다.
/// 고르면 `onPick`을 부르고 닫는다.
struct CoverPhotoPickerSheet: View {
    let trip: Trip?
    let photos: [DailyPhoto]
    let onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                if !photos.isEmpty {
                    Text("Choose from One Photo a Day")
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
                if let trip, let first = trip.legs.map(\.startDate).min(), let last = trip.legs.map(\.endDate).max() {
                    DailyPhotoLibraryPicker(day: first, lastDay: last) { path in
                        onPick(path)
                        dismiss()
                    }
                    .padding(.horizontal, -DNASpacing.lg)
                } else {
                    Text("Choose from Photo Library")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                    AnyPhotoLibraryPickerButton(title: String(localized: "Choose Photo")) { path in
                        onPick(path)
                        dismiss()
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(DNASpacing.lg)
            .background(Color.dnaSheet)
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
    }
}
