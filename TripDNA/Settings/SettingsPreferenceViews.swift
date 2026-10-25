import SwiftUI

// MARK: - 원하는 여행

struct WantedTripsSettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var tiers = WantedConceptTiers()
    @State private var isLoaded = false
    @State private var saveFailed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNASpacing.md) {
                Text("칩을 눌러 칸을 옮겨요")
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextSecondary)
                ForEach([1, 2, 3], id: \.self) { tier in
                    ConceptTierBox(tier: tier, tiers: tiers) { tiers.place($0, in: $1) }
                }
                ConceptTierBox(tier: nil, tiers: tiers) { tiers.place($0, in: $1) }

                VStack(alignment: .leading, spacing: DNASpacing.xs) {
                    Text("피하고 싶은 게 있다면 · 선택")
                        .dnaFont(.sectionTitle)
                        .foregroundStyle(Color.dnaTextPrimary)
                    TextField("예: 긴 이동, 사람 많은 곳", text: Binding(
                        get: { tiers.avoidNote ?? "" },
                        set: { tiers.avoidNote = $0 }
                    ), axis: .vertical)
                        .lineLimit(2...5)
                        .padding(DNASpacing.md)
                        .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
                }
                Text("다녀온 여행 기록으로 칸을 채우지 않아요")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
                if saveFailed {
                    Text("저장하지 못했어요. 다시 시도해 주세요.")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaError)
                }
            }
            .padding(.horizontal, DNASpacing.gutter)
            .padding(.vertical, DNASpacing.md)
        }
        .background(Color.dnaCanvas.ignoresSafeArea())
        .navigationTitle("원하는 여행")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            tiers = (try? await dependencies.store.loadWantedTiers()) ?? WantedConceptTiers()
            isLoaded = true
        }
        .onChange(of: tiers) {
            guard isLoaded else { return }
            Task {
                var stored = tiers
                if stored.avoidNote?.isEmpty == true { stored.avoidNote = nil }
                do {
                    try await dependencies.store.saveWantedTiers(stored)
                    saveFailed = false
                } catch {
                    saveFailed = true
                }
            }
        }
    }
}

// MARK: - 기억하는 취향

/// 지금 앱이 저장하는 기억은 "원하는 여행"의 피하고 싶은 것 하나뿐이다.
struct MemorySettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var tiers: WantedConceptTiers?
    @State private var toast: SettingsToast?

    private var avoidNote: String? {
        tiers?.avoidNote.flatMap { $0.isEmpty ? nil : $0 }
    }

    var body: some View {
        List {
            if let note = avoidNote {
                Section {
                    VStack(alignment: .leading, spacing: DNASpacing.xxs) {
                        Text("피하고 싶은 것")
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextSecondary)
                        Text(note)
                            .dnaFont(.body)
                            .foregroundStyle(Color.dnaTextPrimary)
                    }
                    .swipeActions {
                        Button("지우기", role: .destructive) { Task { await forget() } }
                    }
                } footer: {
                    Text("왼쪽으로 밀면 지울 수 있어요. 고치려면 원하는 여행에서 바꿔요.")
                }
                .listRowBackground(Color.dnaSurface1)
            } else {
                Section {
                    Text("추천에서 아쉬운 점을 알려주면 여기에 모여요")
                        .dnaFont(.body)
                        .foregroundStyle(Color.dnaTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, DNASpacing.sm)
                }
                .listRowBackground(Color.dnaSurface1)
            }
        }
        .settingsListStyle()
        .navigationTitle("기억하는 취향")
        .navigationBarTitleDisplayMode(.inline)
        .settingsToast($toast)
        .task { tiers = try? await dependencies.store.loadWantedTiers() }
    }

    private func forget() async {
        guard var updated = tiers else { return }
        updated.avoidNote = nil
        do {
            try await dependencies.store.saveWantedTiers(updated)
            tiers = updated
        } catch {
            toast = SettingsToast(message: "지우지 못했어요")
        }
    }
}

// MARK: - 추천에서 제외한 곳

struct ExclusionsSettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var items: [CardFeedback] = []
    @State private var cities: [ExcludedCity] = []
    @State private var toast: SettingsToast?

    var body: some View {
        List {
            if items.isEmpty && cities.isEmpty {
                Section {
                    Text("제외한 곳이 없어요")
                        .dnaFont(.body)
                        .foregroundStyle(Color.dnaTextSecondary)
                        .padding(.vertical, DNASpacing.sm)
                }
                .listRowBackground(Color.dnaSurface1)
            } else {
                if !cities.isEmpty {
                    Section("도시") {
                        ForEach(cities) { city in cityRow(city) }
                    }
                    .listRowBackground(Color.dnaSurface1)
                }
                if !items.isEmpty {
                    Section("나라") {
                        ForEach(items) { item in row(item) }
                    }
                    .listRowBackground(Color.dnaSurface1)
                }
                Section {} footer: {
                    Text("나라 제외를 풀어도 따로 정한 도시 제외는 남아요. 도시를 열어보거나 저장해도 제외가 풀리지 않아요.")
                }
            }
        }
        .settingsListStyle()
        .navigationTitle("추천에서 제외한 곳")
        .navigationBarTitleDisplayMode(.inline)
        .settingsToast($toast)
        .task { await reload() }
    }

    private func cityRow(_ city: ExcludedCity) -> some View {
        HStack(spacing: DNASpacing.sm) {
            Text(CountryFlag.emoji(for: city.country)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(city.cityName)
                    .dnaFont(.cardTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Text("도시 제외 · \(CountryCatalog.name(for: city.country)) · \(city.excludedAt.formatted(.dateTime.year().month().day()))")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            Spacer(minLength: 0)
            Button("해제") { Task { await releaseCity(city) } }
                .dnaFont(.button)
                .foregroundStyle(Color.dnaActionText)
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("\(city.cityName) 제외 해제")
        }
    }

    private func releaseCity(_ city: ExcludedCity) async {
        cities = await dependencies.store.updateCityState { $0.release(cityID: city.cityID) }.excluded
        let store = dependencies.store
        toast = SettingsToast(message: "\(city.cityName) 제외를 풀었어요", undo: {
            _ = await store.updateCityState { state in
                state.excluded.removeAll { $0.cityID == city.cityID }
                state.excluded.insert(city, at: 0)
            }
            await reload()
        })
    }

    private func row(_ item: CardFeedback) -> some View {
        HStack(spacing: DNASpacing.sm) {
            Text(CountryFlag.emoji(for: item.countryCode)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(CountryCatalog.name(for: item.countryCode))
                    .dnaFont(.cardTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Text(detail(item))
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            Spacer(minLength: 0)
            Button("해제") { Task { await release(item) } }
                .dnaFont(.button)
                .foregroundStyle(Color.dnaActionText)
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("\(CountryCatalog.name(for: item.countryCode)) 제외 해제")
        }
    }

    /// 저장돼 있는 것만 보여준다: 범위는 나라 단위뿐이고, 이유는 고른 경우에만 있다.
    private func detail(_ item: CardFeedback) -> String {
        var parts = ["나라 제외", item.createdAt.formatted(.dateTime.year().month().day()) ]
        if let reason = item.reason { parts.append(reason.labelKo) }
        return parts.joined(separator: " · ")
    }

    private func reload() async {
        items = (try? await dependencies.recommendationService.activeDislikes()) ?? []
        cities = await dependencies.store.cityState().excluded
    }

    private func release(_ item: CardFeedback) async {
        do {
            try await dependencies.recommendationService.revokeDislike(countryCode: item.countryCode)
        } catch {
            toast = SettingsToast(message: "제외를 풀지 못했어요")
            return
        }
        await reload()
        let service = dependencies.recommendationService
        toast = SettingsToast(message: "\(CountryCatalog.name(for: item.countryCode)) 제외를 풀었어요", undo: {
            _ = try? await service.applyFeedback(
                countryCode: item.countryCode, slot: item.slot, action: .dislike, reason: item.reason
            )
            await reload()
        })
    }
}

// MARK: - 사는 나라

struct HomeCountrySettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var code = ""

    private var deviceRegion: String? { Locale.current.region?.identifier.uppercased() }

    var body: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            Text("출발 공항 후보를 채우고, 이 나라의 도시는 추천에서 기본으로 빼요. 추천을 요청할 때마다 켜고 끌 수 있어요.")
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextSecondary)
                .padding(.horizontal, DNASpacing.lg)
            HStack(spacing: DNASpacing.xs) {
                if let region = deviceRegion, region != code {
                    Button("기기 지역 · \(CountryCatalog.name(for: region))") { choose(region) }
                        .buttonStyle(.dnaSecondary)
                }
                if dependencies.homeCountryCode != nil {
                    Button("정하지 않기") { clear() }
                        .buttonStyle(.dnaSecondary)
                }
            }
            .padding(.horizontal, DNASpacing.lg)
            CountrySelectionList(selectedCode: $code)
        }
        .padding(.top, DNASpacing.sm)
        .background(Color.dnaCanvas.ignoresSafeArea())
        .navigationTitle("사는 나라")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { code = dependencies.homeCountryCode ?? "" }
        .onChange(of: code) {
            guard !code.isEmpty, code != dependencies.homeCountryCode else { return }
            Task { await dependencies.setHomeCountryCode(code) }
        }
    }

    private func choose(_ region: String) { code = region }

    private func clear() {
        code = ""
        Task { await dependencies.clearHomeCountryCode() }
    }
}

// MARK: - 출발 공항 기본값

enum AirportCatalog {
    /// 작은 정적 목록. 나라가 없으면 목록이 비어 있고, 사는 나라를 먼저 보여준다.
    static let airports: [(countryCode: String, airports: [(code: String, name: String)])] = [
        ("KR", [("ICN", "인천"), ("GMP", "김포"), ("PUS", "김해(부산)"), ("CJU", "제주")]),
        ("JP", [("NRT", "나리타"), ("HND", "하네다"), ("KIX", "간사이")]),
        ("US", [("JFK", "뉴욕 JFK"), ("LAX", "로스앤젤레스"), ("SFO", "샌프란시스코")]),
        ("GB", [("LHR", "런던 히스로")]),
        ("SG", [("SIN", "싱가포르 창이")]),
        ("AU", [("SYD", "시드니")])
    ]

    static func label(for code: String) -> String {
        for group in airports {
            if let found = group.airports.first(where: { $0.code == code }) { return "\(found.name) \(code)" }
        }
        return code
    }
}

struct DepartureAirportSettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var airport: String?
    @State private var directOnly = false
    @State private var isLoaded = false
    @State private var saveFailed = false

    private var groups: [(countryCode: String, airports: [(code: String, name: String)])] {
        let home = dependencies.homeCountryCode
        return AirportCatalog.airports.sorted { ($0.countryCode == home ? 0 : 1) < ($1.countryCode == home ? 0 : 1) }
    }

    var body: some View {
        List {
            Section {
                Toggle("직항만", isOn: $directOnly)
            } footer: {
                Text(directOnly ? "직항만 볼게요." : "경유도 괜찮아요.")
            }
            .listRowBackground(Color.dnaSurface1)

            ForEach(groups, id: \.countryCode) { group in
                Section(CountryCatalog.name(for: group.countryCode)) {
                    ForEach(group.airports, id: \.code) { item in
                        Button {
                            airport = (airport == item.code) ? nil : item.code
                        } label: {
                            HStack {
                                Text("\(item.name) \(item.code)")
                                Spacer()
                                if airport == item.code {
                                    Image(systemName: "checkmark").foregroundStyle(Color.dnaData)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.dnaTextPrimary)
                    }
                }
                .listRowBackground(Color.dnaSurface1)
            }
            Section {
                if saveFailed {
                    Text("저장하지 못했어요. 다시 시도해 주세요.").foregroundStyle(Color.dnaError)
                }
                Text("목록에 없는 공항은 아직 고를 수 없어요. 고른 공항을 다시 누르면 정하지 않은 상태로 돌아가요.")
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            .listRowBackground(Color.clear)
        }
        .settingsListStyle()
        .navigationTitle("출발 공항 기본값")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let profile = try? await dependencies.store.loadProfile()
            airport = profile?.departureAirportCode
            directOnly = profile?.prefersDirectFlights ?? false
            isLoaded = true
        }
        .onChange(of: airport) { save() }
        .onChange(of: directOnly) { save() }
    }

    private func save() {
        guard isLoaded else { return }
        Task {
            do {
                try await dependencies.setDepartureDefaults(
                    airportCode: airport, prefersDirectFlights: directOnly ? true : nil
                )
                saveFailed = false
            } catch {
                saveFailed = true
            }
        }
    }
}
