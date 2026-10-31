import SwiftUI

/// 저장한 도시 목록. 누르면 추천 상세와 같은 화면이 열리고, 저장 당시 조건 기준임을 밝힌다.
/// 도시 추천 이전에 저장한 나라 기록과 "관심 없어요"로 뺀 나라는 "이전 기록(나라)"로 남겨 둔다.
struct SavedRecommendationsView: View {
    let viewModel: RecommendationViewModel
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var cities: [SavedCity] = []
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if cities.isEmpty && viewModel.savedFeedback.isEmpty && viewModel.dislikedFeedback.isEmpty {
                EmptyStateView(
                    systemImage: "bookmark",
                    title: String(localized: "No saved cities"),
                    message: String(localized: "Bookmark city cards you like\nand they'll show up here."),
                    actionTitle: String(localized: "See Recommendations"),
                    action: { dismiss() }
                )
            } else {
                ScrollView {
                    VStack(spacing: DNASpacing.md) {
                        if let errorMessage {
                            Text(errorMessage)
                                .dnaFont(.caption)
                                .foregroundStyle(Color.dnaError)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        ForEach(cities) { city in
                            cityCard(city)
                        }
                        if !viewModel.savedFeedback.isEmpty || !viewModel.dislikedFeedback.isEmpty {
                            Text("Earlier Records (Countries)")
                                .dnaFont(.sectionTitle)
                                .foregroundStyle(Color.dnaTextPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, DNASpacing.sm)
                        }
                        ForEach(viewModel.savedFeedback) { feedback in
                            savedCard(feedback)
                        }
                        if !viewModel.dislikedFeedback.isEmpty {
                            dislikedSection
                        }
                    }
                    .padding(DNASpacing.lg)
                }
            }
        }
        .dnaBackground()
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle("Saved Cities")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            cities = (try? await dependencies.store.cityState().saved) ?? []
            await viewModel.refreshSavedList(dependencies)
            await viewModel.refreshDislikedList(dependencies)
        }
        .animation(.easeOut(duration: 0.25), value: cities)
        .animation(.easeOut(duration: 0.25), value: viewModel.savedFeedback)
        .animation(.easeOut(duration: 0.25), value: viewModel.dislikedFeedback)
    }

    private func cityCard(_ item: SavedCity) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            NavigationLink {
                CityDetailView(card: item.card, conditionSummary: item.conditionSummary, request: item.request, savedAt: item.savedAt)
            } label: {
                VStack(alignment: .leading, spacing: DNASpacing.xs) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(CountryFlag.emoji(for: item.card.country)) \(item.card.cityName)")
                            .dnaFont(.sectionTitle)
                            .foregroundStyle(Color.dnaTextPrimary)
                        Spacer(minLength: 0)
                        Text(savedDateText(item.savedAt))
                            .font(.caption2)
                            .foregroundStyle(Color.dnaTextSecondary)
                    }
                    Text(CountryCatalog.name(for: item.card.country))
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                    Text(item.card.reason)
                        .dnaFont(.body)
                        .foregroundStyle(Color.dnaTextPrimary.opacity(0.85))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if !item.summary.isEmpty {
                        Text("Conditions when saved: \(item.summary)")
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button {
                Task {
                    do {
                        cities = try await dependencies.store.updateCityState { $0.unsave(cityID: item.id) }.saved
                        errorMessage = nil
                    } catch {
                        errorMessage = CityRecommendationViewModel.saveFailure
                    }
                }
            } label: {
                Label("Remove Save", systemImage: "bookmark.slash")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.dnaSurface2, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.dnaDivider, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(DNASpacing.md)
        .background(RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous).fill(Color.dnaSurface1))
        .overlay(RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous).strokeBorder(Color.dnaDivider, lineWidth: 1))
    }

    private var dislikedSection: some View {
        SectionCard(title: String(localized: "Countries You Skipped")) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Undo to put them back in your recommendations.")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
                    .padding(.bottom, DNASpacing.xs)
                ForEach(viewModel.dislikedFeedback) { feedback in
                    HStack(spacing: DNASpacing.sm) {
                        Text(CountryFlag.emoji(for: feedback.countryCode))
                            .accessibilityHidden(true)
                        Text(CountryCatalog.name(for: feedback.countryCode))
                            .dnaFont(.body)
                            .foregroundStyle(Color.dnaTextPrimary)
                        Spacer(minLength: 0)
                        Button("Undo") {
                            Task { await viewModel.revokeDislike(feedback, dependencies: dependencies) }
                        }
                        .dnaFont(.cardTitle)
                        .foregroundStyle(Color.dnaTextPrimary)
                        .buttonStyle(.plain)
                        .accessibilityLabel("Undo \(CountryCatalog.name(for: feedback.countryCode))")
                    }
                    .frame(minHeight: 44)
                }
            }
        }
    }

    private func savedCard(_ feedback: CardFeedback) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            HStack(alignment: .top, spacing: DNASpacing.sm) {
                Text(CountryFlag.emoji(for: feedback.countryCode))
                    .font(.system(size: 34))

                VStack(alignment: .leading, spacing: 4) {
                    Text(CountryCatalog.name(for: feedback.countryCode))
                        .dnaFont(.sectionTitle)
                        .foregroundStyle(Color.dnaTextPrimary)
                    SlotChip(slot: feedback.slot)
                    if isExcluded(feedback) {
                        Text("Excluded from recommendations")
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaUnverifiedText)
                            .padding(.horizontal, DNASpacing.xs)
                            .padding(.vertical, 2)
                            .background(Color.dnaUnverifiedBackground, in: Capsule())
                    }
                }

                Spacer(minLength: 0)

                Text(savedDateText(feedback.createdAt))
                    .font(.caption2)
                    .foregroundStyle(Color.dnaTextSecondary)
            }

            Text(viewModel.savedReasonText(for: feedback))
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextPrimary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DNASpacing.sm) {
                NavigationLink {
                    TripRegistrationView(prefilledCountryCode: feedback.countryCode)
                } label: {
                    Label("Register as Trip", systemImage: "airplane")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaData)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color.dnaData.opacity(0.12), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.dnaData.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)

                if isExcluded(feedback) {
                    Button {
                        Task { await viewModel.revokeDislike(feedback, dependencies: dependencies) }
                    } label: {
                        Label("Include Again", systemImage: "arrow.uturn.backward")
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaActionText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color.dnaSurface2, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    Task { await viewModel.unsave(feedback, dependencies: dependencies) }
                } label: {
                    Label("Remove Save", systemImage: "bookmark.slash")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color.dnaSurface2, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.dnaDivider, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DNASpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .fill(Color.dnaSurface1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .strokeBorder(Color.dnaDivider, lineWidth: 1)
        )
    }

    /// 저장을 풀어도 제외는 그대로이므로, 제외 여부는 저장과 따로 본다.
    private func isExcluded(_ feedback: CardFeedback) -> Bool {
        viewModel.dislikedFeedback.contains { $0.countryCode == feedback.countryCode }
    }

    private func savedDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return String(localized: "Saved \(formatter.string(from: date))")
    }
}

#Preview("SavedRecommendationsView") {
    NavigationStack {
        SavedRecommendationsView(viewModel: RecommendationViewModel())
    }
    .previewWithAppEnvironment()
}
