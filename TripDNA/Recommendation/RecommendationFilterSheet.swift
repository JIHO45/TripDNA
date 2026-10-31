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
                    Text("Fit your budget")
                        .font(.title.weight(.regular))
                        .foregroundStyle(Color.dnaTextPrimary)
                    filterSection(
                        title: String(localized: "Budget Range"),
                        caption: String(localized: "Countries with prices above your budget are left out. A higher budget doesn't mean only expensive places.")
                    ) {
                        DNAFlowLayout(spacing: 8) {
                            ForEach(BudgetLevel.allCases) { budget in
                                DNATagChip(
                                    title: budget.label,
                                    isSelected: viewModel.filter.budget == budget
                                ) {
                                    toggleOptional(\.budget, to: budget)
                                }
                            }
                        }
                    }

                    if dependencies.canIncludeHomeCountry {
                        filterSection(
                            title: String(localized: "Home Country"),
                            caption: String(localized: "Your home country is left out by default. Turn this on to include it this time.")
                        ) {
                            Toggle("Include Home Country", isOn: $viewModel.filter.includeHomeCountry)
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
            .navigationTitle("Recommendation Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
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
                    .accessibilityLabel("Close")
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
                        Text("Update Recommendations")
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
        filterSection(title: String(localized: "Departure"), caption: String(localized: "Based on the country of residence in your profile. You can change it in Home settings.")) {
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
                    Text("Country of residence isn't set yet")
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
