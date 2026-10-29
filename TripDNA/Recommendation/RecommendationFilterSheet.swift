import SwiftUI

/// UI-4B. 근거 데이터가 있는 예산 조건과 출발지(읽기 전용).
/// 비행시간 필터는 노선 데이터 도입 전이라 노출하지 않는다.
struct RecommendationFilterSheet: View {
    @Bindable var viewModel: RecommendationViewModel
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DNASpacing.xl) {
                    Text("예산에 맞춰")
                        .font(.title.weight(.regular))
                        .foregroundStyle(Color.dnaTextPrimary)
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

                    if dependencies.canIncludeHomeCountry {
                        filterSection(
                            title: "사는 나라",
                            caption: "사는 나라는 기본으로 추천에서 빼요. 켜면 이번 추천에 넣어요."
                        ) {
                            Toggle("사는 나라도 포함", isOn: $viewModel.filter.includeHomeCountry)
                                .foregroundStyle(Color.dnaTextPrimary)
                                .accessibilityIdentifier("recommendationFilter.includeHomeCountry")
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
                    .foregroundStyle(Color.dnaTextSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .dnaFont(.cardTitle)
                            .foregroundStyle(Color.dnaTextSecondary)
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
    }

    // MARK: 출발지 (프로필 거주국, 읽기 전용)

    private var departureSection: some View {
        filterSection(title: "출발지", caption: "프로필의 거주 국가 기준이에요. 홈 설정에서 바꿀 수 있어요.") {
            HStack(spacing: DNASpacing.sm) {
                if let code = dependencies.homeCountryCode {
                    Text(CountryFlag.emoji(for: code))
                        .font(.title3)
                    Text(CountryCatalog.name(for: code))
                        .dnaFont(.cardTitle)
                        .foregroundStyle(Color.dnaTextPrimary)
                } else {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(Color.dnaTextSecondary)
                    Text("거주 국가가 아직 설정되지 않았어요")
                        .dnaFont(.body)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "lock")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            .padding(DNASpacing.md)
            .background(
                RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                    .fill(Color.dnaSurface1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                    .strokeBorder(Color.dnaDivider, lineWidth: 1)
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
                .dnaFont(.sectionTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            content()
            if let caption {
                Text(caption)
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
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

}

#Preview("RecommendationFilterSheet") {
    Color.dnaCanvas
        .sheet(isPresented: .constant(true)) {
            RecommendationFilterSheet(viewModel: RecommendationViewModel())
        }
        .previewWithAppEnvironment()
}
