import SwiftUI

// MARK: - 추천 탭 전용 공용 컴포넌트
//
// SharedComponents는 수정하지 않고, 추천 화면들(메인·상세·저장 목록)에서만
// 함께 쓰는 컴포넌트를 이 파일에 모아 둔다.

/// 목적지 사진이 없는 MVP 단계의 히어로 영역.
/// 슬롯 액센트 그라디언트 + 국기 워터마크 + 국가명 큰 타이포로 프리미엄한 첫인상을 만든다.
struct RecommendationHeroView: View {
    let countryCode: String
    let slot: RecommendationSlot
    var height: CGFloat = 168
    var showsSlotChip = true

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    slot.accentColor.opacity(0.58),
                    slot.accentColor.opacity(0.22),
                    Color.dnaSurface2
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.white.opacity(0.14), .clear],
                center: UnitPoint(x: 0.85, y: 0.1),
                startRadius: 4,
                endRadius: 180
            )

            Text(CountryFlag.emoji(for: countryCode))
                .font(.system(size: height * 0.72))
                .opacity(0.22)
                .rotationEffect(.degrees(-10))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 14, y: -8)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DNASpacing.xs) {
                HStack(spacing: DNASpacing.xs) {
                    Text(CountryFlag.emoji(for: countryCode))
                        .font(.title2)
                    Text(CountryCatalog.name(for: countryCode))
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .padding(DNASpacing.md)

            if showsSlotChip {
                SlotChip(slot: slot)
                    .padding(DNASpacing.md)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(height: height)
        .clipped()
    }
}

/// 싫어요 이유 바텀시트 (UI-4E). 이유 선택은 선택 사항이며, "건너뛰고 숨기기"로 생략할 수 있다.
struct RecommendationDislikeSheet: View {
    let countryName: String
    let onSelect: (FeedbackReason?) -> Void
    @Environment(\.dismiss) private var dismiss

    private let reasons: [FeedbackReason] = [.tooExpensive, .tooFar, .safety, .notMyTaste]

    var body: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            VStack(alignment: .leading, spacing: DNASpacing.xs) {
                Text("Mind telling us why?")
                    .font(.title3.bold())
                    .foregroundStyle(Color.dnaTextPrimary)
                Text("\(particled(countryName, .eunNeun)) won't appear in your recommendations anymore. You can undo this anytime from your saved list.")
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            .padding(.top, DNASpacing.lg)

            VStack(spacing: DNASpacing.sm) {
                ForEach(reasons, id: \.self) { reason in
                    Button {
                        onSelect(reason)
                        dismiss()
                    } label: {
                        Text(reason.label)
                    }
                    .buttonStyle(.dnaSecondary)
                }
            }

            Button {
                onSelect(nil)
                dismiss()
            } label: {
                Text("Skip and Hide")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.dnaGhost)
            .padding(.bottom, DNASpacing.md)
        }
        .padding(.horizontal, DNASpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.dnaSurface1)
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
    }
}

/// 저장 등 짧은 확인 피드백 토스트.
struct RecommendationToast: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .dnaFont(.cardTitle)
            .foregroundStyle(Color.dnaTextPrimary)
            .padding(.horizontal, DNASpacing.md)
            .padding(.vertical, DNASpacing.sm)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.dnaSurface2)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.dnaData.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
    }
}

/// 설명 태그를 인용 스타일로 보여주는 정적 칩.
struct RecommendationTagPill: View {
    let tagID: String

    var body: some View {
        Text("'\(TagCatalog.label(for: tagID))'")
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.dnaTextPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.dnaTextPrimary.opacity(0.07), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.dnaDivider, lineWidth: 1))
    }
}

#Preview("RecommendationHeroView") {
    VStack(spacing: 16) {
        RecommendationHeroView(countryCode: "JP", slot: .bestMatch)
        RecommendationHeroView(countryCode: "PT", slot: .freshStretch)
        RecommendationHeroView(countryCode: "GE", slot: .underratedFit)
    }
    .padding()
    .background(AppCanvas())
    .preferredColorScheme(.dark)
}

#Preview("RecommendationDislikeSheet") {
    RecommendationDislikeSheet(countryName: "Japan") { _ in }
        .preferredColorScheme(.dark)
}

#Preview("RecommendationToast") {
    RecommendationToast(message: "Saved")
        .padding()
        .background(AppCanvas())
        .preferredColorScheme(.dark)
}
