import SwiftUI

@Observable
final class FingerprintDetailViewModel {
    struct TagCount: Identifiable {
        let id: String
        let labelKo: String
        let count: Int
    }

    var vector: UserTasteVector?
    var evidenceTrips: [Trip] = []
    var frequentTags: [TagCount] = []
    var isLoading = false

    /// 축 바텀시트 근거용 — 만족도가 높은 evaluated 여행 상위 3개.
    var topSatisfactionTrips: [Trip] {
        Array(
            evidenceTrips
                .sorted { ($0.evaluation?.satisfaction ?? 0) > ($1.evaluation?.satisfaction ?? 0) }
                .prefix(3)
        )
    }

    func load(_ dependencies: AppDependencies) async {
        isLoading = true
        defer { isLoading = false }
        vector = try? await dependencies.store.currentUTV()
        let trips = await dependencies.allTrips()
        evidenceTrips = trips
            .filter { $0.status == .evaluated }
            .sorted { ($0.evaluatedAt ?? .distantPast) > ($1.evaluatedAt ?? .distantPast) }

        let definitions = (try? await dependencies.store.definitions()) ?? []
        let labels = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0.labelKo) })
        var counts: [String: Int] = [:]
        for trip in evidenceTrips {
            for tagID in trip.evaluation?.positiveTagIDs ?? [] {
                counts[tagID, default: 0] += 1
            }
        }
        frequentTags = counts
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { TagCount(id: $0.key, labelKo: labels[$0.key] ?? $0.key, count: $0.value) }
    }
}

/// `.sheet(item:)`용 래퍼. TasteAxis에 직접 Identifiable을 붙이지 않기 위한 것.
private struct AxisSelection: Identifiable {
    let axis: TasteAxis
    var id: String { axis.rawValue }
}

struct FingerprintDetailView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppDependencies.self) private var dependencies
    @State private var viewModel = FingerprintDetailViewModel()
    @State private var selectedAxis: AxisSelection?
    @State private var showingShare = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNASpacing.lg) {
                if let vector = viewModel.vector {
                    hero(vector)
                    axisRowsCard(vector)
                    evidenceTripsCard
                    frequentTagsCard
                    blurryAxesCard(vector)
                } else if viewModel.isLoading {
                    LoadingView().frame(height: 280)
                } else {
                    EmptyStateView(
                        systemImage: "touchid",
                        title: "아직 지문이 없어요",
                        message: "여행을 등록하고 평가하면 지문이 생성돼요.",
                        actionTitle: "여행 등록하러 가기",
                        action: { router.selectedTab = .trips }
                    )
                    .frame(height: 280)
                }
            }
            .padding(DNASpacing.lg)
        }
        .dnaBackground()
        .safeAreaInset(edge: .bottom) {
            if viewModel.vector != nil {
                DNABottomCTA {
                    NavigationLink {
                        RankingBoardView()
                    } label: {
                        Text("내 여행 랭킹 확인")
                    }
                    .buttonStyle(.dnaPrimary)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if viewModel.vector != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("지문 공유") { showingShare = true }
                        .accessibilityIdentifier("fingerprint.sharePreview")
                }
            }
        }
        .sheet(isPresented: $showingShare) {
            if let vector = viewModel.vector {
                ShareCardSheet(kind: .fingerprint, title: "지문 공유", disclosure: "5축 취향 지문과 취향 설명이 포함돼요. 개별 여행 이력은 표시하지 않아요.") { _ in
                    FingerprintShareCard(axes: vector.axes, confidence: vector.confidence)
                }
            }
        }
        .sheet(item: $selectedAxis) { selection in
            if let vector = viewModel.vector {
                AxisDetailSheet(
                    axis: selection.axis,
                    value: vector.axes[selection.axis],
                    confidence: vector.confidence[selection.axis],
                    evidenceTrips: viewModel.topSatisfactionTrips
                )
            }
        }
        .task { await viewModel.load(dependencies) }
    }

    // MARK: - 히어로 (3B)

    private func hero(_ vector: UserTasteVector) -> some View {
        VStack(spacing: DNASpacing.sm) {
            FingerprintRadarView(axes: vector.axes, confidence: vector.confidence)
            Text(AxisNarrative.representativeSentenceKo(axes: vector.axes, confidence: vector.confidence))
                .font(.title3.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 5축 행 (3B, 탭 → 3C 바텀시트)

    private func axisRowsCard(_ vector: UserTasteVector) -> some View {
        SectionCard(title: "5축 취향") {
            VStack(spacing: DNASpacing.md) {
                ForEach(TasteAxis.allCases, id: \.self) { axis in
                    AxisRow(
                        axis: axis,
                        value: vector.axes[axis],
                        confidence: vector.confidence[axis]
                    ) {
                        selectedAxis = AxisSelection(axis: axis)
                    }
                }
                Text("ⓘ 표시된 축은 현재 추천 점수에는 반영하지 않아요")
                    .font(.caption2)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
        }
    }

    // MARK: - 내 취향을 만든 여행 (3B)

    private var evidenceTripsCard: some View {
        SectionCard(title: "내 취향을 만든 여행") {
            if viewModel.evidenceTrips.isEmpty {
                Text("아직 평가된 여행이 없어요. 여행을 평가하면 여기에 쌓여요.")
                    .font(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            } else {
                VStack(spacing: DNASpacing.sm) {
                    ForEach(viewModel.evidenceTrips.prefix(5)) { trip in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trip.titleKo)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white)
                                Text(trip.dateRangeKo)
                                    .font(.caption2)
                                    .foregroundStyle(Color.dnaTextSecondary)
                            }
                            Spacer()
                            if let satisfaction = trip.evaluation?.satisfaction {
                                Text("만족도 \(satisfaction)/5")
                                    .font(.caption)
                                    .foregroundStyle(Color.dnaData)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 자주 고른 태그 (3B)

    private var frequentTagsCard: some View {
        SectionCard(title: "자주 고른 태그") {
            if viewModel.frequentTags.isEmpty {
                Text("여행을 평가할 때 고른 좋았던 태그가 여기에 모여요.")
                    .font(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            } else {
                DNAFlowLayout(spacing: 8) {
                    ForEach(viewModel.frequentTags) { tag in
                        frequencyChip(tag)
                    }
                }
            }
        }
    }

    private func frequencyChip(_ tag: FingerprintDetailViewModel.TagCount) -> some View {
        HStack(spacing: 4) {
            Text(tag.labelKo)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
            if tag.count > 1 {
                Text("×\(tag.count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.dnaData)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Capsule(style: .continuous).fill(Color.white.opacity(0.05)))
        .overlay(Capsule(style: .continuous).strokeBorder(Color.dnaDivider, lineWidth: 1))
    }

    // MARK: - 아직 흐린 축 (3B)

    private func blurryAxesCard(_ vector: UserTasteVector) -> some View {
        let blurryAxes = TasteAxis.allCases.filter { vector.confidence[$0] < 0.4 }
        return SectionCard(title: "아직 흐린 축") {
            if blurryAxes.isEmpty {
                Text("모든 축이 충분히 선명해요.")
                    .font(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            } else {
                VStack(alignment: .leading, spacing: DNASpacing.xs) {
                    ForEach(blurryAxes, id: \.self) { axis in
                        HStack(spacing: 6) {
                            Image(systemName: "circle.dotted")
                                .font(.caption)
                                .foregroundStyle(Color.dnaWarning)
                            Text(axis.labelKo)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Spacer()
                            Text("데이터 적음")
                                .font(.caption2)
                                .foregroundStyle(Color.dnaTextSecondary)
                        }
                    }
                    Text("여행 평가가 쌓이면 선명해져요.")
                        .font(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                        .padding(.top, 2)
                }
            }
        }
    }
}

// MARK: - 축 행

private struct AxisRow: View {
    let axis: TasteAxis
    let value: Double
    let confidence: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 5) {
                    Text(axis.labelKo)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    if axis != .natureUrban {
                        // 조건부축: 현재 추천 점수 미반영 안내 (카드 하단 각주 참조).
                        Image(systemName: "info.circle")
                            .font(.caption2)
                            .foregroundStyle(Color.dnaTextSecondary)
                    }
                    Spacer()
                    if confidence < 0.4 {
                        Text("데이터 적음")
                            .font(.caption2)
                            .foregroundStyle(Color.dnaWarning)
                    } else {
                        Text("신뢰도 \(Int((confidence * 100).rounded()))%")
                            .font(.caption2)
                            .foregroundStyle(Color.dnaTextSecondary)
                            .monospacedDigit()
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                BipolarAxisBar(value: value, confidence: confidence)
                HStack {
                    Text(AxisNarrative.negativePoleKo(axis))
                        .font(.caption2)
                        .foregroundStyle(Color.dnaTextSecondary)
                    Spacer()
                    Text(AxisNarrative.positivePoleKo(axis))
                        .font(.caption2)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 중앙 눈금 + 위치 마커로 -1…+1 값을 보여주는 양극 바.
private struct BipolarAxisBar: View {
    let value: Double
    let confidence: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let position = CGFloat((value + 1) / 2)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 6)
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 1.5, height: 12)
                    .offset(x: width / 2 - 0.75)
                Circle()
                    .fill(Color.dnaData)
                    .frame(width: 14, height: 14)
                    .shadow(color: Color.dnaData.opacity(0.7), radius: 6)
                    .opacity(max(0.35, confidence))
                    .offset(x: (width - 14) * position)
            }
        }
        .frame(height: 14)
    }
}

// MARK: - 축 상세 바텀시트 (3C)

private struct AxisDetailSheet: View {
    let axis: TasteAxis
    let value: Double
    let confidence: Double
    let evidenceTrips: [Trip]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNASpacing.md) {
                Text(axis.labelKo)
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text(AxisNarrative.poleMeaningKo(axis))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 6) {
                    HStack {
                        Text("현재 위치")
                            .font(.caption)
                            .foregroundStyle(Color.dnaTextSecondary)
                        Spacer()
                        Text("\(AxisNarrative.leaningPhraseKo(axis: axis, value: value)) 쪽")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.dnaData)
                    }
                    BipolarAxisBar(value: value, confidence: confidence)
                    HStack {
                        Text(AxisNarrative.negativePoleKo(axis))
                            .font(.caption2)
                            .foregroundStyle(Color.dnaTextSecondary)
                        Spacer()
                        Text(AxisNarrative.positivePoleKo(axis))
                            .font(.caption2)
                            .foregroundStyle(Color.dnaTextSecondary)
                    }
                }
                .padding(DNASpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                        .fill(Color.dnaSurface1)
                )

                if confidence < 0.4 {
                    Label("여행 평가가 쌓이면 선명해져요", systemImage: "sparkles")
                        .font(.subheadline)
                        .foregroundStyle(Color.dnaWarning)
                } else {
                    Label("신뢰도 \(Int((confidence * 100).rounded()))% · 평가한 여행이 반영됐어요", systemImage: "checkmark.seal")
                        .font(.subheadline)
                        .foregroundStyle(Color.dnaData)
                }

                if axis != .natureUrban {
                    Label("현재 추천 점수에는 반영하지 않아요", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }

                if !evidenceTrips.isEmpty {
                    Text("근거가 된 여행")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.top, DNASpacing.xs)
                    VStack(spacing: DNASpacing.sm) {
                        ForEach(evidenceTrips) { trip in
                            HStack {
                                Text(trip.titleKo)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                Spacer()
                                if let satisfaction = trip.evaluation?.satisfaction {
                                    Text("만족도 \(satisfaction)/5")
                                        .font(.caption)
                                        .foregroundStyle(Color.dnaTextSecondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(DNASpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.dnaCanvas)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.dnaCanvas)
    }
}

#Preview("FingerprintDetailView") {
    NavigationStack {
        FingerprintDetailView()
    }
    .previewWithAppEnvironment()
}
