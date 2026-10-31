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
                Text("Tap a chip to move it between boxes")
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextSecondary)
                ForEach([1, 2, 3], id: \.self) { tier in
                    ConceptTierBox(tier: tier, tiers: tiers) { tiers.place($0, in: $1) }
                }
                ConceptTierBox(tier: nil, tiers: tiers) { tiers.place($0, in: $1) }

                VStack(alignment: .leading, spacing: DNASpacing.xs) {
                    Text("Anything to avoid? · Optional")
                        .dnaFont(.sectionTitle)
                        .foregroundStyle(Color.dnaTextPrimary)
                    TextField("e.g. Long travel, crowded places", text: Binding(
                        get: { tiers.avoidNote ?? "" },
                        set: { tiers.avoidNote = $0 }
                    ), axis: .vertical)
                        .lineLimit(2...5)
                        .padding(DNASpacing.md)
                        .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
                }
                Text("Boxes aren't filled from your past trips")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
                if saveFailed {
                    Text("Couldn't save. Please try again.")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaError)
                }
            }
            .padding(.horizontal, DNASpacing.gutter)
            .padding(.vertical, DNASpacing.md)
        }
        .background(Color.dnaCanvas.ignoresSafeArea())
        .navigationTitle("Wanted Trips")
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

/// 지금 앱이 저장하는 기억은 "Wanted Trips"의 피하고 싶은 것 하나뿐이다.
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
                        Text("Things to avoid")
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextSecondary)
                        Text(note)
                            .dnaFont(.body)
                            .foregroundStyle(Color.dnaTextPrimary)
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) { Task { await forget() } }
                    }
                } footer: {
                    Text("Swipe left to delete. To edit it, change it in Wanted Trips.")
                }
                .listRowBackground(Color.dnaSurface1)
            } else {
                Section {
                    Text("Anything you write under things to avoid in Wanted Trips shows up here")
                        .dnaFont(.body)
                        .foregroundStyle(Color.dnaTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, DNASpacing.sm)
                }
                .listRowBackground(Color.dnaSurface1)
            }
        }
        .settingsListStyle()
        .navigationTitle("Remembered Tastes")
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
            await dependencies.track(.memoryForgotten)
        } catch {
            toast = SettingsToast(message: String(localized: "Couldn't delete"))
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
                    Text("Nothing excluded")
                        .dnaFont(.body)
                        .foregroundStyle(Color.dnaTextSecondary)
                        .padding(.vertical, DNASpacing.sm)
                }
                .listRowBackground(Color.dnaSurface1)
            } else {
                if !cities.isEmpty {
                    Section("Cities") {
                        ForEach(cities) { city in cityRow(city) }
                    }
                    .listRowBackground(Color.dnaSurface1)
                }
                if !items.isEmpty {
                    Section("Countries") {
                        ForEach(items) { item in row(item) }
                    }
                    .listRowBackground(Color.dnaSurface1)
                }
                Section {} footer: {
                    Text("Removing a country exclusion keeps any separate city exclusions. Opening or saving a city doesn't remove its exclusion.")
                }
            }
        }
        .settingsListStyle()
        .navigationTitle("Excluded from Recommendations")
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
                Text("City excluded · \(CountryCatalog.name(for: city.country)) · \(city.excludedAt.formatted(.dateTime.year().month().day()))")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            Spacer(minLength: 0)
            Button("Allow Again") { Task { await releaseCity(city) } }
                .dnaFont(.button)
                .foregroundStyle(Color.dnaActionText)
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Remove exclusion for \(city.cityName)")
        }
    }

    private func releaseCity(_ city: ExcludedCity) async {
        do {
            cities = try await dependencies.store.updateCityState { $0.release(cityID: city.cityID) }.excluded
        } catch {
            toast = SettingsToast(message: String(localized: "Couldn't save. Please try again."))
            return
        }
        let store = dependencies.store
        toast = SettingsToast(message: String(localized: "\(city.cityName) is no longer excluded"), undo: {
            _ = try? await store.updateCityState { state in
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
            Button("Allow Again") { Task { await release(item) } }
                .dnaFont(.button)
                .foregroundStyle(Color.dnaActionText)
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Remove exclusion for \(CountryCatalog.name(for: item.countryCode))")
        }
    }

    /// 저장돼 있는 것만 보여준다: 범위는 나라 단위뿐이고, 이유는 고른 경우에만 있다.
    private func detail(_ item: CardFeedback) -> String {
        var parts = [String(localized: "Country excluded"), item.createdAt.formatted(.dateTime.year().month().day()) ]
        if let reason = item.reason { parts.append(reason.label) }
        return parts.joined(separator: " · ")
    }

    private func reload() async {
        items = (try? await dependencies.recommendationService.activeDislikes()) ?? []
        cities = (try? await dependencies.store.cityState().excluded) ?? []
    }

    private func release(_ item: CardFeedback) async {
        do {
            try await dependencies.recommendationService.revokeDislike(countryCode: item.countryCode)
        } catch {
            toast = SettingsToast(message: String(localized: "Couldn't remove the exclusion"))
            return
        }
        await reload()
        let service = dependencies.recommendationService
        toast = SettingsToast(message: String(localized: "\(CountryCatalog.name(for: item.countryCode)) is no longer excluded"), undo: {
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
            Text("Fills in departure airport suggestions and leaves this country's cities out of recommendations by default. You can turn that on or off each time you request one.")
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextSecondary)
                .padding(.horizontal, DNASpacing.lg)
            HStack(spacing: DNASpacing.xs) {
                if let region = deviceRegion, region != code {
                    Button("Device region · \(CountryCatalog.name(for: region))") { choose(region) }
                        .buttonStyle(.dnaSecondary)
                }
                if dependencies.homeCountryCode != nil {
                    Button("Don't Set") { clear() }
                        .buttonStyle(.dnaSecondary)
                }
            }
            .padding(.horizontal, DNASpacing.lg)
            CountrySelectionList(selectedCode: $code)
        }
        .padding(.top, DNASpacing.sm)
        .background(Color.dnaCanvas.ignoresSafeArea())
        .navigationTitle("Home Country")
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

nonisolated enum AirportCatalog {
    /// 작은 정적 목록. 나라가 없으면 목록이 비어 있고, 사는 나라를 먼저 보여준다.
    static let airports: [(countryCode: String, airports: [(code: String, name: String)])] = [
        ("KR", [("ICN", String(localized: "Incheon")), ("GMP", String(localized: "Gimpo")), ("PUS", String(localized: "Gimhae (Busan)")), ("CJU", String(localized: "Jeju"))]),
        ("JP", [("NRT", String(localized: "Narita")), ("HND", String(localized: "Haneda")), ("KIX", String(localized: "Kansai"))]),
        ("US", [("JFK", String(localized: "New York JFK")), ("LAX", String(localized: "Los Angeles")), ("SFO", String(localized: "San Francisco"))]),
        ("GB", [("LHR", String(localized: "London Heathrow"))]),
        ("SG", [("SIN", String(localized: "Singapore Changi"))]),
        ("AU", [("SYD", String(localized: "Sydney"))])
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
                Toggle("Direct Flights Only", isOn: $directOnly)
            } footer: {
                Text(directOnly ? String(localized: "Direct flights only.") : String(localized: "Layovers are fine."))
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
                    Text("Couldn't save. Please try again.").foregroundStyle(Color.dnaError)
                }
                Text("Airports not on the list can't be chosen yet. Tap the selected airport again to unset it.")
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            .listRowBackground(Color.clear)
        }
        .settingsListStyle()
        .navigationTitle("Default Departure Airport")
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
