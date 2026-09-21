import SwiftUI

/// UI-4C. 목적지 상세: 왜 추천하나요 / 현실 적합 / 알아둘 점.
/// Match Score와 현실 적합도(물가 배지)는 하나의 숫자로 합치지 않고 분리해서 보여준다.
struct RecommendationDetailView: View {
    let recommendation: Recommendation
    let viewModel: RecommendationViewModel

    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var showingDislikeSheet = false

    private var isSaved: Bool {
        viewModel.reaction(for: recommendation.slot) == .save
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNASpacing.lg) {
                hero
                whySection
                realityFitSection
                noticesSection
            }
            .padding(DNASpacing.lg)
            .padding(.bottom, 120)
        }
        .dnaBackground()
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) { bottomCTA }
        .sheet(isPresented: $showingDislikeSheet) {
            RecommendationDislikeSheet(
                countryName: CountryCatalog.name(for: recommendation.countryCode)
            ) { reason in
                Task {
                    await viewModel.dislike(recommendation, reason: reason, dependencies: dependencies)
                    dismiss()
                }
            }
        }
    }

    // MARK: 히어로

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            RecommendationHeroView(
                countryCode: recommendation.countryCode,
                slot: recommendation.slot,
                height: 220
            )

            VStack(alignment: .leading, spacing: DNASpacing.xs) {
                HStack(spacing: DNASpacing.xs) {
                    ScoreBadge(score: recommendation.matchScore)
                    Spacer(minLength: 0)
                }
                Text("\(recommendation.slot.labelKo) 슬롯의 추천이에요")
                    .font(.caption)
                    .foregroundStyle(Color.dnaSlate)
            }
            .padding(DNASpacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .fill(Color.dnaSurface)
        )
        .clipShape(RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .strokeBorder(Color.dnaHairline, lineWidth: 1)
        )
        .shadow(color: recommendation.slot.accentColor.opacity(0.16), radius: 24, y: 10)
    }

    // MARK: 섹션

    private var whySection: some View {
        SectionCard(title: "왜 추천하나요") {
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                Text(viewModel.reasonText(for: recommendation))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)

                if !recommendation.explanationTagIDs.isEmpty {
                    DNAFlowLayout(spacing: 6) {
                        ForEach(recommendation.explanationTagIDs, id: \.self) { tagID in
                            RecommendationTagPill(tagID: tagID)
                        }
                    }
                }
            }
        }
    }

    /// 검증된 데이터(물가 지수)만 배지로 보여주고, 예산·비행시간처럼
    /// 검증되지 않은 항목은 숫자나 적합 배지를 추정해서 표시하지 않는다.
    private var realityFitSection: some View {
        SectionCard(title: "현실 적합") {
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                FitBadgesRow(badges: recommendation.fitBadges)

                Text("물가 배지는 참고용이에요. 취향 매치 점수와 합쳐서 계산하지 않아요.")
                    .font(.caption)
                    .foregroundStyle(Color.dnaSlate)
                    .fixedSize(horizontal: false, vertical: true)

                Text("예산·비행시간은 검증된 데이터가 준비되면 보여드릴게요.")
                    .font(.caption)
                    .foregroundStyle(Color.dnaSlate)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var noticesSection: some View {
        SectionCard(title: "알아둘 점") {
            if recommendation.notices.isEmpty {
                Text("지금 알려드릴 주의 사항이 없어요.")
                    .font(.subheadline)
                    .foregroundStyle(Color.dnaSlate)
            } else {
                VStack(alignment: .leading, spacing: DNASpacing.xs) {
                    ForEach(recommendation.notices, id: \.self) { notice in
                        Label {
                            Text(notice)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundStyle(Color.dnaAmber)
                        }
                    }
                }
            }
        }
    }

    // MARK: CTA

    private var bottomCTA: some View {
        DNABottomCTA {
            Button {
                Task { await viewModel.save(recommendation, dependencies: dependencies) }
            } label: {
                Label(isSaved ? "저장했어요" : "저장하기", systemImage: isSaved ? "checkmark" : "bookmark")
            }
            .buttonStyle(.dnaPrimary(isDisabled: isSaved))
            .disabled(isSaved)

            Button {
                showingDislikeSheet = true
            } label: {
                Text("관심 없어요")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.dnaGhost)
        }
    }
}

#Preview("RecommendationDetailView") {
    NavigationStack {
        RecommendationDetailView(
            recommendation: PreviewSample.recommendation,
            viewModel: RecommendationViewModel()
        )
    }
    .previewWithAppEnvironment()
}
