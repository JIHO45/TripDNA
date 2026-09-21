import SwiftUI

/// UI-4D. 저장 목록: 저장 시점의 추천 이유 유지 + 여행 등록 + 저장 해제.
struct SavedRecommendationsView: View {
    let viewModel: RecommendationViewModel
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        Group {
            if viewModel.savedFeedback.isEmpty {
                EmptyStateView(
                    systemImage: "bookmark",
                    title: "저장한 추천이 없어요",
                    message: "마음에 드는 추천 카드를 북마크로 저장하면\n여기에 모여요."
                )
            } else {
                ScrollView {
                    VStack(spacing: DNASpacing.md) {
                        ForEach(viewModel.savedFeedback) { feedback in
                            savedCard(feedback)
                        }
                    }
                    .padding(DNASpacing.lg)
                }
            }
        }
        .dnaBackground()
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await viewModel.refreshSavedList(dependencies) }
        .animation(.easeOut(duration: 0.25), value: viewModel.savedFeedback)
    }

    private func savedCard(_ feedback: CardFeedback) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            HStack(alignment: .top, spacing: DNASpacing.sm) {
                Text(CountryFlag.emoji(for: feedback.countryCode))
                    .font(.system(size: 34))

                VStack(alignment: .leading, spacing: 4) {
                    Text(CountryCatalog.name(for: feedback.countryCode))
                        .font(.headline)
                        .foregroundStyle(.white)
                    SlotChip(slot: feedback.slot)
                }

                Spacer(minLength: 0)

                Text(savedDateText(feedback.createdAt))
                    .font(.caption2)
                    .foregroundStyle(Color.dnaSlate)
            }

            Text(viewModel.savedReasonText(for: feedback))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DNASpacing.sm) {
                NavigationLink {
                    TripRegistrationView(prefilledCountryCode: feedback.countryCode)
                } label: {
                    Label("여행으로 등록", systemImage: "airplane")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.dnaTeal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color.dnaTeal.opacity(0.12), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.dnaTeal.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await viewModel.unsave(feedback, dependencies: dependencies) }
                } label: {
                    Label("저장 해제", systemImage: "bookmark.slash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.dnaSlate)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.05), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.dnaHairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DNASpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .fill(Color.dnaSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .strokeBorder(Color.dnaHairline, lineWidth: 1)
        )
    }

    private func savedDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return "\(formatter.string(from: date)) 저장"
    }
}

#Preview("SavedRecommendationsView") {
    NavigationStack {
        SavedRecommendationsView(viewModel: RecommendationViewModel())
    }
    .previewWithAppEnvironment()
}
