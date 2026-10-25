import SwiftUI

/// 추천 탭: 도시 추천 결과(마지막 결과 복원) 또는 받은 추천이 없을 때의 안내.
/// 나라 단위 카드 목록은 탭에서 뺐다. 나라 저장·제외 기록은 그대로 두고 설정에서 쓴다.
struct RecommendationView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppRouter.self) private var router
    @State private var cityModel = CityRecommendationViewModel()
    @State private var showingInput = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNASpacing.lg) {
                VStack(alignment: .leading, spacing: DNASpacing.sm) {
                    header
                    DNAHeaderDivider()
                }
                CityRecommendationSection(
                    model: cityModel,
                    onNewRequest: { showingInput = true },
                    retry: {
                        guard let request = cityModel.lastRequest else { return }
                        cityModel.begin(request: request, dependencies: dependencies)
                    }
                )
                if cityModel.state == .idle { introView }
            }
            .padding(DNASpacing.lg)
        }
        .dnaTopScrollBlur()
        .dnaBackground()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { Task { await cityModel.restore(dependencies: dependencies) } }
        .fullScreenCover(isPresented: $showingInput) {
            RecommendationInputSheet { request in
                cityModel.begin(request: request, dependencies: dependencies)
            }
        }
        .onChange(of: router.recommendationInputRequested, initial: true) {
            guard router.recommendationInputRequested else { return }
            router.recommendationInputRequested = false
            showingInput = true
        }
        .sheet(isPresented: Binding(
            get: { cityModel.pendingConsentRequest != nil },
            set: { _ in }
        )) {
            CityConsentSheet(model: cityModel)
        }
    }

    // MARK: 상단

    private var header: some View {
        DNAScreenHeader(title: "추천") {
            HStack(spacing: DNASpacing.sm) {
                Button { showingInput = true } label: {
                    DNACircleIcon(systemImage: "plus", isEmphasized: false)
                }
                .accessibilityLabel("새 여행 추천")
                NavigationLink {
                    SavedRecommendationsView(viewModel: RecommendationViewModel())
                } label: {
                    DNACircleIcon(systemImage: "bookmark", isEmphasized: false)
                }
                .accessibilityLabel("저장한 도시")
            }
        }
    }

    // MARK: 본문

    /// 입력 시트로 추천을 받은 적이 없을 때의 안내. 입력은 시트에서 받는다.
    private var introView: some View {
        VStack(spacing: DNASpacing.md) {
            VStack(spacing: DNASpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(Color.dnaActionText)
                    .frame(width: 56, height: 56)
                    .background(Color.dnaSurface2, in: Circle())
                Text("아직 받은 추천이 없어요")
                    .dnaFont(.sectionTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Text("여행 컨셉을 고르면 조건에 맞는 도시를 골라 이유와 함께 보여줘요.")
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextSecondary)
                    .multilineTextAlignment(.center)
                Button { showingInput = true } label: { Text("새 여행 추천 받기") }
                    .buttonStyle(.dnaPrimary)
                    .accessibilityIdentifier("recommendation.new")
            }
            .padding(DNASpacing.gutter)
            .frame(maxWidth: .infinity)
            .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))

            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                Text("이렇게 추천해요")
                    .dnaFont(.cardTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                ForEach(Array([
                    "여행 컨셉과, 정해졌다면 시기·기간·예산을 골라요",
                    "최대 3곳을 맞는 이유, 안 맞을 수 있는 점과 함께 보여줘요",
                    "마음에 드는 곳은 저장하거나 여행으로 등록해요"
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
