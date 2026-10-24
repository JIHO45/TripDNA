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
        var line = "다녀온 여행 \(fingerprint.total)번"
        if obligationCount > 0 { line += " · 출장 \(obligationCount)번은 빼고 셌어요" }
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
                        Text("내 취향과 달라요")
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
        .navigationTitle("내 여행 지문")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if viewModel.fingerprint != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingShare = true } label: { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("지문 공유")
                        .accessibilityIdentifier("fingerprint.sharePreview")
                }
            }
        }
        .sheet(isPresented: $showingShare) {
            if let fingerprint = viewModel.fingerprint {
                ShareCardSheet(
                    kind: .fingerprint,
                    title: "공유 미리보기",
                    disclosure: "포함: 여행 수, 컨셉별 횟수 · 빠짐: 날짜, 도시, 동행, 사진"
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
                Text("여행마다 고른 주 컨셉")
                    .dnaFont(.sectionTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                ForEach(Array(fingerprint.entries.enumerated()), id: \.element.concept) { rank, entry in
                    conceptRow(entry, rank: rank, ids: fingerprint.tripIDs[entry.concept] ?? [])
                }
                Text("칸을 누르면 그 여행으로 가요")
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
                Text(entry.concept.labelKo)
                    .dnaFont(.cardTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Spacer()
                Text("\(entry.count)번")
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
                        .accessibilityLabel("\(trip.placeTitleKo) 여행 보기")
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
            Text("아직 지문이 비어 있어요")
                .dnaFont(.screenTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            Text("다녀온 여행을 등록하면 여행마다 한 칸씩 쌓여요.")
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextSecondary)
            Button("여행 등록하기") { showingRegistration = true }
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
                Text("원한다고 한 것")
                    .dnaFont(.sectionTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Spacer()
                NavigationLink("수정") { WantedTripsSettingsView() }
                    .dnaFont(.button)
                    .foregroundStyle(Color.dnaActionText)
                    .accessibilityIdentifier("fingerprint.editWanted")
            }
            let rows = [1, 2, 3].filter { !(viewModel.tiers?.concepts(in: $0).isEmpty ?? true) }
            if rows.isEmpty {
                Text("아직 고르지 않았어요")
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextSecondary)
            } else {
                ForEach(rows, id: \.self) { tier in
                    HStack(alignment: .firstTextBaseline, spacing: DNASpacing.sm) {
                        Text(WantedConceptTiers.screenName(of: tier))
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextSecondary)
                            .frame(width: 92, alignment: .leading)
                        Text((viewModel.tiers?.concepts(in: tier) ?? []).map(\.labelKo).joined(separator: ", "))
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
                    Text("어떤 게 다른가요?")
                        .dnaFont(.screenTitle)
                        .foregroundStyle(Color.dnaTextPrimary)
                    Text("지문은 여행마다 고른 컨셉을 센 거예요. 고치고 싶은 곳으로 안내할게요.")
                        .dnaFont(.body)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                Button(action: onOpenTrips) {
                    route("여행의 컨셉이 틀렸어요", "여행 목록에서 컨셉 고치기")
                }
                .buttonStyle(.plain)
                NavigationLink { WantedTripsSettingsView() } label: {
                    route("원하는 여행이 바뀌었어요", "원하는 여행 수정")
                }
                .buttonStyle(.plain)
                NavigationLink { MemorySettingsView() } label: {
                    route("추천이 기억하는 내용이 달라요", "기억하는 취향 보기")
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(DNASpacing.gutter)
            .background(Color.dnaCanvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
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
