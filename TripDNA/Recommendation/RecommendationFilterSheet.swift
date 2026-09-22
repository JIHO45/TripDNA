import SwiftUI

/// UI-4B. 상황 필터 시트: 시기·동행·예산(선택)·출발지(읽기 전용).
/// 비행시간 필터는 노선 데이터 도입 전이라 노출하지 않는다.
struct RecommendationFilterSheet: View {
    @Bindable var viewModel: RecommendationViewModel
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DNASpacing.xl) {
                    Text("이번 여행에 맞춰")
                        .font(.title.weight(.regular))
                        .foregroundStyle(Color.dnaTextPrimary)
                    filterSection(
                        title: "여행 시기",
                        caption: "여러 계절을 고를 수 있어요. 시즌 적합 데이터가 준비되면 후보에 반영돼요."
                    ) {
                        DNAFlowLayout(spacing: 8) {
                            ForEach(TravelSeason.allCases) { season in
                                DNATagChip(
                                    title: season.labelKo,
                                    isSelected: viewModel.filter.seasons.contains(season)
                                ) {
                                    toggleSeason(season)
                                }
                            }
                        }
                    }

                    filterSection(
                        title: "동행",
                        caption: "이번 여행의 동행이에요. 동행 유형에 맞는 나라만 고르지는 않아요."
                    ) {
                        DNAFlowLayout(spacing: 8) {
                            ForEach(Companion.allCases, id: \.self) { companion in
                                DNATagChip(
                                    title: companion.labelKo,
                                    isSelected: viewModel.filter.companion == companion
                                ) {
                                    toggleOptional(\.companion, to: companion)
                                }
                            }
                        }
                    }

                    filterSection(
                        title: "예산 범위",
                        caption: "예산을 넘는 물가의 나라를 후보에서 제외해요. 예산이 높다고 비싼 곳만 나오지 않아요."
                    ) {
                        DNAFlowLayout(spacing: 8) {
                            ForEach(BudgetLevel.allCases) { budget in
                                DNATagChip(
                                    title: budget.labelKo,
                                    isSelected: viewModel.filter.budget == budget
                                ) {
                                    toggleOptional(\.budget, to: budget)
                                }
                            }
                        }
                    }

                    departureSection
                }
                .padding(DNASpacing.lg)
                .padding(.bottom, DNASpacing.sm)
            }
            .dnaBackground()
            .navigationTitle("추천 조건")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("초기화") {
                        viewModel.resetFilter()
                    }
                    .foregroundStyle(Color.dnaSlate)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.dnaSlate)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("닫기")
                }
            }
            .safeAreaInset(edge: .bottom) {
                DNABottomCTA {
                    Button {
                        Task {
                            await viewModel.applyFilter(dependencies)
                            dismiss()
                        }
                    } label: {
                        Text("추천 다시 보기")
                    }
                    .buttonStyle(.dnaPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    // MARK: 출발지 (프로필 거주국, 읽기 전용)

    private var departureSection: some View {
        filterSection(title: "출발지", caption: "프로필의 거주 국가 기준이에요. 홈 설정에서 바꿀 수 있어요.") {
            HStack(spacing: DNASpacing.sm) {
                if let code = dependencies.homeCountryCode {
                    Text(CountryFlag.emoji(for: code))
                        .font(.title3)
                    Text(CountryCatalog.name(for: code))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dnaTextPrimary)
                } else {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(Color.dnaSlate)
                    Text("거주 국가가 아직 설정되지 않았어요")
                        .font(.subheadline)
                        .foregroundStyle(Color.dnaSlate)
                }
                Spacer(minLength: 0)
                Image(systemName: "lock")
                    .font(.caption)
                    .foregroundStyle(Color.dnaSlate)
            }
            .padding(DNASpacing.md)
            .background(
                RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                    .fill(Color.dnaSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                    .strokeBorder(Color.dnaHairline, lineWidth: 1)
            )
        }
    }

    // MARK: 공통

    private func filterSection(
        title: String,
        caption: String?,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.dnaTextPrimary)
            content()
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(Color.dnaSlate)
            }
        }
    }

    /// 같은 칩을 다시 탭하면 선택 해제되는 단일 선택 토글.
    private func toggleOptional<Value: Equatable>(
        _ keyPath: WritableKeyPath<RecommendationFilter, Value?>,
        to value: Value
    ) {
        if viewModel.filter[keyPath: keyPath] == value {
            viewModel.filter[keyPath: keyPath] = nil
        } else {
            viewModel.filter[keyPath: keyPath] = value
        }
    }

    /// 여행 시기 복수 선택. 같은 칩을 다시 탭하면 해제.
    private func toggleSeason(_ season: TravelSeason) {
        if viewModel.filter.seasons.contains(season) {
            viewModel.filter.seasons.remove(season)
        } else {
            viewModel.filter.seasons.insert(season)
        }
    }
}

#Preview("RecommendationFilterSheet") {
    Color.dnaBackground
        .sheet(isPresented: .constant(true)) {
            RecommendationFilterSheet(viewModel: RecommendationViewModel())
        }
        .previewWithAppEnvironment()
}
