import SwiftUI

@Observable
final class FingerprintDetailViewModel {
    var trips: [Trip] = []
    var fingerprint: ConceptFingerprint?
    var obligationCount = 0
    var tiers: WantedConceptTiers?
    var isLoading = true

    func load(_ dependencies: AppDependencies) async {
        defer { isLoading = false }
        trips = await dependencies.allTrips()
        fingerprint = ConceptFingerprint(trips: trips)
        obligationCount = ConceptFingerprint.obligationCount(in: trips)
        tiers = try? await dependencies.store.loadWantedTiers()
    }

    func trip(id: String) -> Trip? { trips.first { $0.id == id } }

    /// "다녀온 여행 6번 · 출장 1번은 빼고 셌어요"
    var scopeLineKo: String {
        guard let fingerprint else { return "" }
        var line = String(localized: "\(fingerprint.total) completed trips")
        if obligationCount > 0 { line += " · " + String(localized: "\(obligationCount) business trips not counted") }
        return line
    }
}

/// 내 여행 지문. 다녀온 여행의 주 컨셉을 센 기록이며 성향을 추정하지 않는다.
/// 사용자가 "원한다고 한 것"은 따로 둔다.
struct FingerprintDetailView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppDependencies.self) private var dependencies
    @State private var viewModel = FingerprintDetailViewModel()
    @State private var showingShare = false
    @State private var showingMismatch = false
    @State private var showingRegistration = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNASpacing.lg) {
                if let fingerprint = viewModel.fingerprint {
                    fingerprintCard(fingerprint)
                } else if viewModel.isLoading {
                    LoadingView().frame(height: 240)
                } else {
                    emptyCard
                }
                wantedCard
                Button {
                    showingMismatch = true
                } label: {
                    HStack {
                        Text("Doesn't match my taste")
                        Image(systemName: "chevron.right").dnaFont(size: 12, weight: .semibold)
                    }
                    .dnaFont(.button)
                    .foregroundStyle(Color.dnaTextSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityIdentifier("fingerprint.mismatch")
            }
            .padding(.horizontal, DNASpacing.gutter)
            .padding(.vertical, DNASpacing.md)
        }
        .dnaBackground()
        .navigationTitle("My Travel Fingerprint")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if viewModel.fingerprint != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingShare = true } label: { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("Share fingerprint")
                        .accessibilityIdentifier("fingerprint.sharePreview")
                }
            }
        }
        .sheet(isPresented: $showingShare) {
            if let fingerprint = viewModel.fingerprint {
                ShareCardSheet(
                    kind: .fingerprint,
                    title: String(localized: "Share Preview"),
                    disclosure: String(localized: "Included: trip count, count per concept · Left out: dates, cities, companions, photos")
                ) { _ in
                    FingerprintShareCard(fingerprint: fingerprint)
                }
            }
        }
        .sheet(isPresented: $showingMismatch) {
            MismatchSheet { showingMismatch = false; router.selectedTab = .trips }
        }
        .sheet(isPresented: $showingRegistration, onDismiss: { Task { await viewModel.load(dependencies) } }) {
            NavigationStack { TripRegistrationView(prefilledCountryCode: nil) }
        }
        .task { await viewModel.load(dependencies) }
    }

    // MARK: 지문

    private func fingerprintCard(_ fingerprint: ConceptFingerprint) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.scopeLineKo)
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
                Text(fingerprint.detailHeadlineKo)
                    .dnaFont(.screenTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                Text("Main concept chosen for each trip")
                    .dnaFont(.sectionTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                ForEach(Array(fingerprint.entries.enumerated()), id: \.element.concept) { rank, entry in
                    conceptRow(entry, rank: rank, ids: fingerprint.tripIDs[entry.concept] ?? [])
                }
                Text("Tap a block to open that trip")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
        }
        .padding(DNASpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
    }

    /// 칸 하나가 여행 하나이고, 칸은 그 여행의 대표 사진이다.
    private func conceptRow(_ entry: ConceptFingerprint.Entry, rank: Int, ids: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.concept.label)
                    .dnaFont(.cardTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Spacer()
                Text("in \(entry.count) trips")
                    .dnaFont(.cardTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                    .monospacedDigit()
            }
            DNAFlowLayout(spacing: 6) {
                ForEach(ids, id: \.self) { id in
                    if let trip = viewModel.trip(id: id) {
                        NavigationLink {
                            TripDetailView(tripID: id)
                        } label: {
                            block(for: trip, rank: rank)
                        }
                        .accessibilityLabel("View \(trip.placeTitleKo) trip")
                    }
                }
            }
        }
    }

    private func block(for trip: Trip, rank: Int) -> some View {
        ZStack {
            ConceptBlockRows.color(rank: rank)
            if let path = trip.coverPhotoStoragePath, LocalPhotoStore.image(at: path) != nil {
                TripPhotoImage(storagePath: path)
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            Text("Your fingerprint is empty")
                .dnaFont(.screenTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            Text("Register trips you've taken and each one adds a block.")
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextSecondary)
            Button("Register a Trip") { showingRegistration = true }
                .buttonStyle(.dnaPrimary)
                .padding(.top, DNASpacing.xs)
                .accessibilityIdentifier("fingerprint.register")
        }
        .padding(DNASpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
    }

    // MARK: 원한다고 한 것

    private var wantedCard: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            HStack {
                Text("What you said you want")
                    .dnaFont(.sectionTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Spacer()
                NavigationLink("Edit") { WantedTripsSettingsView() }
                    .dnaFont(.button)
                    .foregroundStyle(Color.dnaActionText)
                    .accessibilityIdentifier("fingerprint.editWanted")
            }
            let rows = [1, 2, 3].filter { !(viewModel.tiers?.concepts(in: $0).isEmpty ?? true) }
            if rows.isEmpty {
                Text("Nothing chosen yet")
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextSecondary)
            } else {
                ForEach(rows, id: \.self) { tier in
                    HStack(alignment: .firstTextBaseline, spacing: DNASpacing.sm) {
                        Text(WantedConceptTiers.screenName(of: tier))
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextSecondary)
                            .frame(width: 92, alignment: .leading)
                        Text((viewModel.tiers?.concepts(in: tier) ?? []).map(\.label).joined(separator: ", "))
                            .dnaFont(.cardTitle)
                            .foregroundStyle(Color.dnaTextPrimary)
                    }
                }
            }
        }
        .padding(DNASpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
    }
}

// MARK: - 내 취향과 달라요

/// 지문 자체를 손으로 바꾸지 않고, 고칠 수 있는 곳으로 안내한다.
private struct MismatchSheet: View {
    let onOpenTrips: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DNASpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("What's different?")
                        .dnaFont(.screenTitle)
                        .foregroundStyle(Color.dnaTextPrimary)
                    Text("Your fingerprint counts the concept chosen for each trip. We'll take you to where you can fix it.")
                        .dnaFont(.body)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                Button(action: onOpenTrips) {
                    route(String(localized: "A trip's concept is wrong"), String(localized: "Fix concepts in the trip list"))
                }
                .buttonStyle(.plain)
                NavigationLink { WantedTripsSettingsView() } label: {
                    route(String(localized: "The trips I want have changed"), String(localized: "Edit wanted trips"))
                }
                .buttonStyle(.plain)
                NavigationLink { MemorySettingsView() } label: {
                    route(String(localized: "What recommendations remember is off"), String(localized: "See remembered tastes"))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(DNASpacing.gutter)
            .background(Color.dnaCanvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .presentationDetents([.large])
    }

    private func route(_ title: String, _ subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).dnaFont(.cardTitle).foregroundStyle(Color.dnaTextPrimary)
                Text(subtitle).dnaFont(.caption).foregroundStyle(Color.dnaTextSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .dnaFont(size: 13, weight: .semibold)
                .foregroundStyle(Color.dnaTextTertiary)
        }
        .padding(DNASpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
    }
}

#Preview("FingerprintDetailView") {
    NavigationStack {
        FingerprintDetailView()
    }
    .previewWithAppEnvironment()
}
