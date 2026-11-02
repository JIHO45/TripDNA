import SwiftUI

/// 추천 탭: 도시 추천 결과(마지막 결과 복원) 또는 받은 추천이 없을 때의 안내.
/// 나라 단위 카드 목록은 탭에서 뺐다. 나라 저장·제외 기록은 그대로 두고 설정에서 쓴다.
struct RecommendationView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppRouter.self) private var router
    @State private var cityModel = CityRecommendationViewModel()
    /// 입력 시트를 연다. 채워서 열 조건(`initial`)은 "사는 나라 포함하기"처럼 지난 요청을 고쳐 다시 받을 때 쓴다.
    @State private var inputRequest: InputRequest?

    private struct InputRequest: Identifiable {
        let id = UUID()
        let initial: RecommendationRequest
    }
    @State private var showingEdit = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNASpacing.section) {
                VStack(alignment: .leading, spacing: DNASpacing.sm) {
                    header
                    DNAHeaderDivider()
                }
                CityRecommendationSection(
                    model: cityModel,
                    retry: {
                        guard let request = cityModel.lastRequest else { return }
                        cityModel.begin(request: request, dependencies: dependencies)
                    },
                    editConditions: { showingEdit = true },
                    newRequest: { openInput($0) }
                )
                if cityModel.state == .idle { introView }
            }
            .padding(DNASpacing.lg)
        }
        .dnaTopScrollBlur()
        .dnaBackground()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { Task { await cityModel.restore(dependencies: dependencies) } }
        .fullScreenCover(item: $inputRequest) { input in
            RecommendationInputSheet(initial: input.initial) { request in
                cityModel.begin(request: request, dependencies: dependencies)
            }
        }
        .onChange(of: router.recommendationInputRequested, initial: true) {
            guard router.recommendationInputRequested else { return }
            router.recommendationInputRequested = false
            openInput()
        }
        .sheet(isPresented: $cityModel.showsSubscription) { SubscriptionView() }
        .sheet(isPresented: $showingEdit) {
            CityConditionEditSheet(model: cityModel, onNewRequest: { openInput() })
        }
        .sheet(isPresented: Binding(
            get: { cityModel.pendingConsentRequest != nil },
            set: { _ in }
        )) {
            CityConsentSheet(model: cityModel)
        }
    }

    private func openInput(_ initial: RecommendationRequest? = nil) {
        inputRequest = InputRequest(initial: initial ?? RecommendationRequest())
    }

    // MARK: 상단

    /// 결과가 있을 때만 "조건 수정"·"새 여행 추천"을 둔다. 저장한 도시는 설정과 홈에서 연다.
    private var header: some View {
        DNAScreenHeader(title: String(localized: "Recommendations")) {
            if cityModel.lastRecord != nil {
                HStack(spacing: DNASpacing.xxs) {
                    headerButton(String(localized: "Edit Filters"), isPrimary: false) { showingEdit = true }
                    headerButton(String(localized: "New Trip Recommendation"), isPrimary: true) { openInput() }
                }
            }
        }
    }

    @ViewBuilder
    private func headerButton(_ title: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        if isPrimary {
            Button(title, action: action).buttonStyle(.dnaDark)
        } else {
            Button(title, action: action).buttonStyle(.dnaSecondary(fullWidth: false))
        }
    }

    // MARK: 본문

    /// 입력 시트로 추천을 받은 적이 없을 때의 안내. 입력은 시트에서 받는다.
    private var introView: some View {
        VStack(spacing: DNASpacing.md) {
            VStack(spacing: DNASpacing.sm) {
                Image(systemName: "sparkles")
                    .dnaFont(size: 22)
                    .foregroundStyle(Color.dnaActionText)
                    .frame(width: 56, height: 56)
                    .background(Color.dnaSurface2, in: Circle())
                Text("No recommendations yet")
                    .dnaFont(.sectionTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Text("Pick a trip concept and we'll choose matching cities and tell you why.")
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextSecondary)
                    .multilineTextAlignment(.center)
                Button { openInput() } label: { Text("Get a New Trip Recommendation") }
                    .buttonStyle(.dnaPrimary)
                    .accessibilityIdentifier("recommendation.new")
            }
            .padding(DNASpacing.gutter)
            .frame(maxWidth: .infinity)
            .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))

            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                Text("How it works")
                    .dnaFont(.cardTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                ForEach(Array([
                    String(localized: "Choose a trip concept, plus timing, length, and budget if you know them"),
                    String(localized: "See up to 3 places, with why they fit and what might not"),
                    String(localized: "Save the ones you like or register them as trips")
                ].enumerated()), id: \.offset) { index, text in
                    HStack(alignment: .top, spacing: DNASpacing.sm) {
                        Text("\(index + 1)")
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextPrimary)
                            .frame(width: 24, height: 24)
                            .background(Color.dnaSurface2, in: Circle())
                        Text(text)
                            .dnaFont(.body)
                            .foregroundStyle(Color.dnaTextSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DNASpacing.gutter)
        }
    }
}

#Preview("RecommendationView") {
    NavigationStack {
        RecommendationView()
    }
    .previewWithAppEnvironment()
}
