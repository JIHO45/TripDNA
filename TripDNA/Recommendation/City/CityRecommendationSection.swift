import SwiftUI

@Observable
final class CityRecommendationViewModel {
    enum State: Equatable {
        case idle
        case loading
        case done(CityRecommendationRecord)
        case failed(String)
    }

    private(set) var state = State.idle

    var isConfigured: Bool { CityLLMConfiguration.makeClient() != nil }

    func run(request: RecommendationRequest, dependencies: AppDependencies) async {
        guard let catalog = CityCatalog.load() else {
            state = .failed("도시 자료를 읽지 못했어요.")
            return
        }
        state = .loading
        let tiers = (try? await dependencies.store.loadWantedTiers()) ?? WantedConceptTiers()
        var excluded = Set<String>()
        if !request.includeVisited {
            excluded.formUnion(await dependencies.allTrips().flatMap { $0.legs.map(\.countryCode) })
        }
        excluded.formUnion((try? await dependencies.recommendationService.activeDislikes())?.map(\.countryCode) ?? [])
        let homeExcluded = dependencies.homeCountryCode != nil && !request.includeHomeCountry
        if homeExcluded, let home = dependencies.homeCountryCode { excluded.insert(home) }

        let service = CityRecommendationService(
            catalog: catalog, client: CityLLMConfiguration.makeClient(), log: .standard
        )
        do {
            let record = try await service.recommend(
                request: request, tiers: tiers, excludedCountries: excluded, homeCountryExcluded: homeExcluded
            )
            state = .done(record)
        } catch CityRecommendationError.notConfigured {
            state = .failed("LLM 연결이 아직 준비되지 않았어요. 프록시 주소(CityLLMProxyURL) 또는 개발용 키가 필요해요.")
        } catch CityRecommendationError.noneWithinBudget {
            state = .failed("예상 비용이 예산을 넘는 도시뿐이에요. 예산이나 기간을 조정해 보세요.")
        } catch CityRecommendationError.noCandidates {
            state = .failed("조건에 맞는 도시를 찾지 못했어요.")
        } catch {
            state = .failed("추천을 받지 못했어요. 다시 시도해 주세요. (\(error))")
        }
    }
}

/// 도시 단위 추천(새 자료·LLM 흐름). 아래의 나라 단위 카드는 기존 경로다.
struct CityRecommendationSection: View {
    let model: CityRecommendationViewModel
    let retry: () -> Void
    @State private var showingKeyEntry = false

    var body: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            Text("도시 추천")
                .dnaFont(.sectionTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            switch model.state {
            case .idle:
                EmptyView()
            case .loading:
                LoadingView().frame(height: 160)
            case .failed(let message):
                VStack(alignment: .leading, spacing: DNASpacing.sm) {
                    Text(message)
                        .dnaFont(.body)
                        .foregroundStyle(Color.dnaTextSecondary)
                    Button("다시 시도", action: retry)
                    #if DEBUG
                    Button("개발용 키 입력") { showingKeyEntry = true }
                    #endif
                }
            case .done(let record):
                if let understanding = record.understanding {
                    Text(understanding)
                        .dnaFont(.body)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                ForEach(record.cards, id: \.cityID) { card in
                    cityCard(card)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        #if DEBUG
        .sheet(isPresented: $showingKeyEntry) { DevKeySheet() }
        #endif
    }

    private static func won(_ amount: Int) -> String {
        "\(amount / 10_000)만원"
    }

    private func cityCard(_ card: CityRecommendationRecord.Card) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.xs) {
            Text("\(CountryFlag.emoji(for: card.country)) \(card.cityName)")
                .dnaFont(.cardTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            if card.isExploration {
                Text("다른 장점이 있는 후보")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.dnaData)
            }
            Text(card.reason)
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextPrimary.opacity(0.88))
            if !card.caveat.isEmpty {
                Text(card.caveat)
                    .font(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            if let cost = card.cost {
                Text("예상 비용 \(Self.won(cost.low))~\(Self.won(cost.high)) (추정, 가격 확인 필요)")
                    .font(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            if card.seasonCheckNeeded {
                Text("선택한 시기에 가능한지 확인이 필요해요")
                    .font(.caption)
                    .foregroundStyle(Color.dnaWarning)
            }
        }
        .padding(DNASpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
    }
}

#if DEBUG
/// 개발용 API 키를 Keychain에만 저장한다. 소스·번들·로그에는 남지 않는다. 설정 화면의 "개발용" 항목과 추천 화면에서 연다.
struct DevKeyForm: View {
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var saved = DevAPIKeyStore.read().map { !$0.isEmpty } ?? false

    var body: some View {
        Form {
            Section {
                SecureField("Anthropic API 키", text: $key)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("저장") {
                    DevAPIKeyStore.save(key)
                    key = ""
                    saved = DevAPIKeyStore.read() != nil
                    dismiss()
                }
                .disabled(key.isEmpty)
                if saved {
                    Button("저장된 키 지우기", role: .destructive) {
                        DevAPIKeyStore.save("")
                        saved = false
                    }
                }
            } header: {
                Text(saved ? "저장된 키가 있어요" : "저장된 키가 없어요")
            } footer: {
                Text("이 기기의 Keychain에만 저장돼요. 디버그 빌드에서만 쓰여요.")
            }
        }
        .navigationTitle("개발용 API 키")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DevKeySheet: View {
    var body: some View {
        NavigationStack { DevKeyForm() }
    }
}
#endif
