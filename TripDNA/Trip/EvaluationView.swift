import SwiftUI

/// 여행 평가: 방문 도시마다 한 페이지에서 별점과 메모를 받고, 저장하면 기록한 내용만 보여준다.
/// 별점·메모·컨셉은 모두 선택이다. 완료 시간이나 취향 변화를 약속하지 않는다.
struct EvaluationView: View {
    let tripID: String
    @Environment(AppDependencies.self) private var dependencies
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = EvaluationViewModel()
    @State private var showingConceptSheet = false
    @State private var showingCoverPicker = false
    @State private var showingShare = false
    @State private var loaded = false

    var body: some View {
        ZStack {
            AppCanvas()
            switch viewModel.step {
            case .cityReview(let index):
                if viewModel.cityReviews.indices.contains(index) {
                    cityReviewStep(index)
                } else if loaded {
                    // 지운 여행의 알림을 누른 경우 등. 닫을 길 없이 빈 화면에 갇히지 않게 한다.
                    EmptyStateView(
                        systemImage: "suitcase",
                        title: String(localized: "Trip Not Found"),
                        message: String(localized: "This trip may have been deleted."),
                        actionTitle: String(localized: "Close"),
                        action: { dismiss() }
                    )
                    .padding(DNASpacing.gutter)
                }
            case .processing:
                processingStep
            case .result:
                resultStep
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .sensoryFeedback(.success, trigger: viewModel.didSubmit) { _, submitted in submitted }
        .task {
            await viewModel.load(tripID: tripID, dependencies: dependencies)
            loaded = true
        }
        .sheet(isPresented: $showingConceptSheet) {
            TripConceptEditSheet(
                primary: $viewModel.primaryConcept,
                secondary: $viewModel.secondaryConcepts,
                secondaryTitle: String(localized: "Also Did")
            )
        }
        .sheet(isPresented: $showingCoverPicker) {
            CoverPhotoPickerSheet(trip: viewModel.trip, photos: viewModel.photos) { path in
                Task {
                    if let updated = try? await dependencies.tripService.setCoverPhoto(tripID: tripID, storagePath: path) {
                        viewModel.trip = updated
                    }
                }
            }
        }
        .sheet(isPresented: $showingShare) {
            if let trip = viewModel.trip {
                ShareCardSheet(kind: .trip, title: String(localized: "Share Preview"), disclosure: String(localized: "Included: trip concepts, duration, my ranking · Not included: dates, cities, companions, photos"), allowsDestinationNames: true) { showsDestinationNames in
                    TripShareCard(summary: TripShareSummary(trip: trip), showsDestinationNames: showsDestinationNames)
                }
            }
        }
    }

    // MARK: - 도시별 기록

    private func cityReviewStep(_ index: Int) -> some View {
        let review = viewModel.cityReviews[index]
        let total = viewModel.cityReviews.count
        return VStack(spacing: 0) {
            topBar(index: index, total: total)
            ScrollView {
                VStack(alignment: .leading, spacing: DNASpacing.lg) {
                    VStack(alignment: .leading, spacing: DNASpacing.xxs) {
                        Text("How was \(cityName(review))?")
                            .dnaFont(.screenTitle)
                            .foregroundStyle(Color.dnaTextPrimary)
                        if let range = dateRange(for: review) {
                            Text(range)
                                .dnaFont(.caption)
                                .foregroundStyle(Color.dnaTextSecondary)
                        }
                    }
                    Text("Ratings and notes are optional. Leave them blank and only the visit is recorded.")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)

                    HStack(spacing: DNASpacing.xs) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                // 같은 별을 다시 누르면 별점을 지운다.
                                viewModel.cityReviews[index].rating = review.rating == star ? nil : star
                            } label: {
                                Image(systemName: star <= (review.rating ?? 0) ? "star.fill" : "star")
                                    .font(.title)
                                    .foregroundStyle(star <= (review.rating ?? 0) ? Color.dnaWarning : Color.dnaTextTertiary)
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(star) stars")
                            .accessibilityAddTraits(review.rating == star ? .isSelected : [])
                        }
                    }
                    .sensoryFeedback(.selection, trigger: review.rating)

                    memoField(String(localized: "What you liked"), text: memoBinding(index, \.liked))
                    memoField(String(localized: "What fell short"), text: memoBinding(index, \.disliked))

                    if viewModel.isLeisure {
                        conceptRow
                    }

                    if let message = viewModel.errorMessage {
                        Text(message)
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaError)
                    }
                }
                .padding(.horizontal, DNASpacing.gutter)
                .padding(.vertical, DNASpacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            DNABottomCTA {
                Text("Notes help improve your next recommendations")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
                HStack(spacing: DNASpacing.xs) {
                    Button("Skip") {
                        viewModel.clearCurrentCity()
                        if viewModel.isLastStep {
                            Task { await viewModel.submit(dependencies: dependencies, session: session) }
                        } else {
                            viewModel.advance()
                        }
                    }
                    .buttonStyle(.dnaSecondary)
                    .disabled(viewModel.isSubmitting)

                    if viewModel.isLastStep {
                        Button {
                            Task { await viewModel.submit(dependencies: dependencies, session: session) }
                        } label: {
                            if viewModel.isSubmitting {
                                ProgressView().tint(.white)
                            } else {
                                Text(viewModel.isRevising ? String(localized: "Finish Editing") : String(localized: "Finish Rating"))
                            }
                        }
                        .buttonStyle(.dnaPrimary(isDisabled: viewModel.isSubmitting))
                        .disabled(viewModel.isSubmitting)
                    } else {
                        Button("Next City") { viewModel.advance() }
                            .buttonStyle(.dnaPrimary)
                    }
                }
            }
        }
    }

    private func topBar(index: Int, total: Int) -> some View {
        HStack(spacing: DNASpacing.xs) {
            if index > 0 {
                Button { viewModel.goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.dnaTextPrimary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Previous City")
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("\(viewModel.headerTitle) Rating")
                    .dnaFont(.cardTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                    .lineLimit(1)
                Text("City \(index + 1) of \(total)")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            Spacer(minLength: 0)
            Button("Later") { dismiss() }
                .dnaFont(.button)
                .foregroundStyle(Color.dnaTextSecondary)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, DNASpacing.gutter)
        .padding(.top, DNASpacing.xs)
    }

    private var conceptRow: some View {
        Button { showingConceptSheet = true } label: {
            HStack {
                Text("Trip Concepts")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
                Spacer()
                Text(viewModel.conceptsLabelKo ?? String(localized: "Choose"))
                    .dnaFont(.cardTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Image(systemName: "chevron.right")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextTertiary)
            }
            .padding(DNASpacing.md)
            .frame(minHeight: 52)
            .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func memoField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.xs) {
            Text(title)
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
            TextField("Write freely", text: text, axis: .vertical)
                .dnaFont(.body)
                .lineLimit(3...8)
                .padding(DNASpacing.md)
                .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
                .foregroundStyle(Color.dnaTextPrimary)
        }
    }

    private func memoBinding(_ index: Int, _ keyPath: WritableKeyPath<CityReview, String?>) -> Binding<String> {
        Binding(
            get: { viewModel.cityReviews[index][keyPath: keyPath] ?? "" },
            set: { viewModel.cityReviews[index][keyPath: keyPath] = $0 }
        )
    }

    private func cityName(_ review: CityReview) -> String {
        review.city ?? CountryCatalog.name(for: review.countryCode)
    }

    private func dateRange(for review: CityReview) -> String? {
        guard let leg = viewModel.trip?.legs.first(where: {
            $0.countryCode == review.countryCode && ($0.cities.contains(review.city ?? "") || review.city == nil)
        }) else { return nil }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return "\(formatter.string(from: leg.startDate)) – \(formatter.string(from: leg.endDate))"
    }

    // MARK: - 저장 후

    private var processingStep: some View {
        VStack(spacing: DNASpacing.md) {
            ProgressView().tint(Color.dnaTextSecondary)
            Text("Saving")
                .dnaFont(.sectionTitle)
                .foregroundStyle(Color.dnaTextPrimary)
        }
    }

    /// 저장한 내용만 보여준다. 취향이 바뀌었다는 말은 하지 않는다.
    private var resultStep: some View {
        let saved = viewModel.trip?.evaluation?.cityReviews ?? []
        let hasMemo = saved.contains { $0.liked != nil || $0.disliked != nil }
        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DNASpacing.lg) {
                    VStack(alignment: .leading, spacing: DNASpacing.xxs) {
                        Text("\(viewModel.headerTitle) Rating")
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextSecondary)
                        Text(viewModel.isRevising ? String(localized: "Here’s what you changed") : String(localized: "Here’s what you recorded"))
                            .dnaFont(.screenTitle)
                            .foregroundStyle(Color.dnaTextPrimary)
                    }

                    VStack(spacing: DNASpacing.xs) {
                        ForEach(viewModel.cityReviews.indices, id: \.self) { index in
                            savedRow(viewModel.cityReviews[index], saved: saved)
                        }
                    }

                    if hasMemo {
                        Text("We’ll use these notes the next time you get recommendations. The results screen shows what we used.")
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextSecondary)
                    }

                    VStack(alignment: .leading, spacing: DNASpacing.xs) {
                        Text("Options")
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextTertiary)
                        optionRow(String(localized: "Choose Cover Photo"), systemImage: "photo") { showingCoverPicker = true }
                        optionRow(String(localized: "Create Share Card"), systemImage: "square.and.arrow.up") { showingShare = true }
                    }
                }
                .padding(.horizontal, DNASpacing.gutter)
                .padding(.vertical, DNASpacing.lg)
            }
            DNABottomCTA {
                Button("Done") { dismiss() }
                    .buttonStyle(.dnaPrimary)
            }
        }
    }

    private func savedRow(_ review: CityReview, saved: [CityReview]) -> some View {
        let match = saved.first { $0.countryCode == review.countryCode && $0.city == review.city }
        let memoCount = [match?.liked, match?.disliked].compactMap { $0 }.count
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(cityName(review))
                    .dnaFont(.cardTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                if match != nil {
                    if memoCount > 0 {
                        Text("\(memoCount) notes on likes and dislikes")
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextSecondary)
                    }
                } else {
                    Text("Only the visit was recorded. You can rate it later.")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
            }
            Spacer(minLength: 0)
            if let rating = match?.rating {
                Text("★ \(rating)").dnaFont(.cardTitle).foregroundStyle(Color.dnaTextPrimary)
            } else if match == nil {
                Text("Skipped").dnaFont(.caption).foregroundStyle(Color.dnaTextTertiary)
            }
        }
        .padding(DNASpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
    }

    private func optionRow(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .dnaFont(.cardTitle)
                .foregroundStyle(Color.dnaTextPrimary)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .padding(.horizontal, DNASpacing.md)
                .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview("EvaluationView") {
    EvaluationView(tripID: "preview-trip")
        .previewWithAppEnvironment { session in
            session.onboardingPhase = .completed
        }
}
