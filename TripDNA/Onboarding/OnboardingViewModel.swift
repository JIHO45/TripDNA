import Foundation
import CoreLocation
import Photos
import PhotosUI
import SwiftUI

/// 사진첩에서 찾은 여행 후보. 사용자가 "기록하기"를 누른 것만 여행으로 저장된다.
struct TripCandidate: Identifiable {
    enum State { case pending, recorded, removed }

    /// 한 나라에 머문 구간.
    struct Leg: Equatable {
        var countryCode: String
        /// 들른 순서대로. 도시를 모르면 비어 있다. 추측해서 채우지 않는다.
        var cities: [String]
        var startDate: Date
        var endDate: Date
    }

    /// 스캔에 쓰는 사진 한 장. `countryCode`가 nil이면 집(출발 나라)에서 찍은 사진이다.
    struct Photo {
        let countryCode: String?
        let city: String?
        let date: Date
        let assetID: String
        /// 촬영 장소의 시간대. 머문 날짜를 현지 날짜로 센다.
        var timeZone: TimeZone = .current
    }

    let id = UUID()
    /// 날짜순이며 비어 있지 않다. 이웃한 구간은 나라가 다르다.
    var legs: [Leg]
    /// `PHAsset.localIdentifier` (촬영순). 카드 표시 전용이며 저장·업로드하지 않는다.
    var photoAssetIDs: [String]
    var state: State = .pending

    var startDate: Date { legs[0].startDate }
    var endDate: Date { legs.map(\.endDate).max() ?? legs[0].endDate }
    var isCityUnknown: Bool { legs.contains { $0.cities.isEmpty } }
    var title: String {
        PlaceTitle.compact(legs.flatMap { $0.cities.isEmpty ? [CountryCatalog.name(for: $0.countryCode)] : $0.cities }, separator: "·")
    }

    /// 사진 사이가 이 간격보다 벌어지면 다른 여행으로 본다.
    static let maxGap: TimeInterval = 3 * 24 * 60 * 60

    /// 해외 사진을 날짜가 이어지는 묶음으로 나눠 여행 후보를 만든다(최신순, 최대 12개).
    /// 집에서 찍은 사진이 끼거나 간격이 `maxGap`을 넘으면 끊는다. 묶음 안에서는 나라가 바뀔 때마다 구간을 나누고 도시는 경유지로 쌓는다.
    /// 경유지는 사진이 현지 날짜로 이틀 이상 있는 도시만 남긴다. 그런 도시가 없는 구간은 사진이 가장 많은 도시 하나를 남긴다.
    /// ponytail: 사진 날짜 수는 숙박 증거가 아니다. 당일치기 도시는 빠지고, 출국·귀국 때 찍은 공항 도시는 남을 수 있다.
    static func group(_ photos: [Photo]) -> [TripCandidate] {
        var runs: [[Photo]] = [[]]
        for photo in photos.sorted(by: { $0.date < $1.date }) {
            guard photo.countryCode != nil else {
                runs.append([])
                continue
            }
            if let last = runs[runs.count - 1].last, photo.date.timeIntervalSince(last.date) > maxGap {
                runs.append([])
            }
            runs[runs.count - 1].append(photo)
        }
        let calendar = Calendar.current
        return runs.filter { $0.count >= 2 }.reversed().prefix(12).map { run in
            var legs: [Leg] = []
            var stats: [[String: (count: Int, days: Set<DateComponents>)]] = []
            for photo in run {
                let code = photo.countryCode ?? ""
                let day = calendar.startOfDay(for: photo.date)
                if legs.last?.countryCode == code {
                    legs[legs.count - 1].endDate = day
                } else {
                    legs.append(Leg(countryCode: code, cities: [], startDate: day, endDate: day))
                    stats.append([:])
                }
                if let city = photo.city {
                    if !legs[legs.count - 1].cities.contains(city) { legs[legs.count - 1].cities.append(city) }
                    var local = calendar
                    local.timeZone = photo.timeZone
                    var stat = stats[stats.count - 1][city] ?? (0, [])
                    stat.count += 1
                    stat.days.insert(local.dateComponents([.year, .month, .day], from: photo.date))
                    stats[stats.count - 1][city] = stat
                }
            }
            for index in legs.indices where !legs[index].cities.isEmpty {
                let stat = stats[index]
                let stayed = legs[index].cities.filter { (stat[$0]?.days.count ?? 0) >= 2 }
                legs[index].cities = stayed.isEmpty
                    ? [legs[index].cities.max { (stat[$0]?.count ?? 0) < (stat[$1]?.count ?? 0) }!]
                    : stayed
            }
            return TripCandidate(legs: legs, photoAssetIDs: run.map(\.assetID))
        }
    }

    /// 날짜순으로 정렬하고 이웃한 같은 나라 구간을 하나로 합친다.
    static func joined(_ legs: [Leg]) -> [Leg] {
        var result: [Leg] = []
        for leg in legs.sorted(by: { $0.startDate < $1.startDate }) {
            if let last = result.last, last.countryCode == leg.countryCode {
                result[result.count - 1].cities += leg.cities.filter { !last.cities.contains($0) }
                result[result.count - 1].endDate = max(last.endDate, leg.endDate)
            } else {
                result.append(leg)
            }
        }
        return result
    }
}

/// 기록을 마친 여행의 요약. 컨셉 단계와 확인 화면이 쓴다.
struct OnboardingTripSummary: Identifiable, Equatable {
    let id: String
    let title: String
    let period: String
    var concepts: TripConcepts?
}

/// 온보딩 화면들이 공유하는 표기 유틸리티 (Onboarding 폴더 전용).
enum OnboardingFormat {
    static func flagEmoji(for countryCode: String) -> String {
        let base: UInt32 = 127397
        var flag = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            guard let flagScalar = UnicodeScalar(base + scalar.value) else { continue }
            flag.unicodeScalars.append(flagScalar)
        }
        return flag.isEmpty ? "🌍" : flag
    }

    /// 예: "2026년 4월 7–9일", 달이 다르면 "2026년 4월 28일–5월 2일".
    static func dateRangeText(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일"
        let first = formatter.string(from: start)
        guard !Calendar.current.isDate(start, inSameDayAs: end) else { return first }
        let sameMonth = Calendar.current.isDate(start, equalTo: end, toGranularity: .month)
        formatter.dateFormat = sameMonth ? "d일" : "M월 d일"
        return "\(first)–\(formatter.string(from: end))"
    }
}

/// 앱이 꺼져도 온보딩을 이어가기 위해 저장하는 진행 상태. 사진 후보와 사진 id는 담지 않는다.
nonisolated struct OnboardingDraft: Codable, Equatable, Sendable {
    var stage: String
    var entryMode: String?
    var homeCountryCode: String?
    var recordedTripIDs: [String]
    var conceptQueue: [String]
    var conceptIndex: Int
    var tiers: WantedConceptTiers
}

@Observable
final class OnboardingViewModel {
    enum Stage: String, Equatable {
        case hook
        case homeCountry
        case entryModeSelection
        case photoPriming
        case photoScanning
        /// 후보가 없거나 권한을 거부했을 때. 다시 묻지 않고 다른 경로만 안내한다.
        case noCandidates
        case candidates
        case concepts
        case tiers
        case summary
    }

    enum EntryMode: String {
        case photoScan
        case manual
        case preferencesOnly
    }

    var stage: Stage = .hook
    var entryMode: EntryMode?
    /// 홈의 "사진첩에서 찾기"에서 재사용 중인지. 온보딩 전용 "취향부터" 선택지를 숨기는 데 쓴다.
    var isFromHome = false
    /// 사용자가 온보딩에서 명시적으로 고른 거주 국가. 건너뛰면 nil.
    var homeCountryCode: String?
    var showsManualRegistration = false
    var errorMessage: String?
    var isWorking = false

    // MARK: 사진첩 스캔

    var candidates: [TripCandidate] = []
    var scanStatusText = ""
    var scanWasDenied = false
    /// 사용자가 "사진 선택…"(제한된 접근)을 골라 일부 사진만 스캔된 상태.
    var isPhotoAccessLimited = false
    private var scanTask: Task<Void, Never>?

    // MARK: 기록한 여행 · 컨셉 · 티어

    var recordedTrips: [OnboardingTripSummary] = []
    /// 컨셉 단계에서 물을 여행 id와 현재 위치.
    var conceptQueue: [String] = []
    var conceptIndex = 0
    var tiers = WantedConceptTiers()

    // MARK: 퀴즈 상태 (온보딩 경로에서는 쓰지 않지만 기존 테스트가 다루는 평가 로직이 의존한다)

    var quizQuestions: [QuizQuestion] = QuizQuestionCatalog.allQuestions
    var quizQuestionIndex = 0
    var quizAnswers: [QuizAnswer] = []

    /// 기기 지역 설정에서 가져온 국가 코드. 단정하지 않고 미리 제안만 한다.
    static var deviceRegionCode: String? {
        Locale.current.region?.identifier
    }

    /// 상단 세그먼트 진행 바에 쓰이는 시각용 값.
    var progress: Double {
        switch stage {
        case .hook: 0
        case .homeCountry: 0.12
        case .entryModeSelection: 0.25
        case .photoPriming: 0.35
        case .photoScanning: 0.42
        case .noCandidates: 0.45
        case .candidates: 0.55
        case .concepts:
            conceptQueue.isEmpty ? 0.7 : 0.65 + 0.15 * Double(conceptIndex) / Double(conceptQueue.count)
        case .tiers: 0.88
        case .summary: 1
        }
    }

    var hasTierAnswers: Bool { !tiers.isEmpty }

    // MARK: 진행 상태 저장·복원

    /// 복원이 끝나기 전에는 저장하지 않아 저장된 진행 상태를 덮어쓰지 않는다.
    private(set) var isRestored = false

    var draft: OnboardingDraft {
        OnboardingDraft(
            stage: stage.rawValue, entryMode: entryMode?.rawValue, homeCountryCode: homeCountryCode,
            recordedTripIDs: recordedTrips.map(\.id), conceptQueue: conceptQueue,
            conceptIndex: conceptIndex, tiers: tiers
        )
    }

    func saveDraft(_ dependencies: AppDependencies) async {
        guard isRestored else { return }
        try? await dependencies.store.saveOnboardingDraft(draft)
    }

    /// 저장된 진행 상태로 돌아간다. 사진 후보는 저장하지 않으므로 후보 검토 중이었다면
    /// 입력 경로 선택으로 돌아가고, 사진 권한은 자동으로 다시 요청하지 않는다.
    func restore(_ dependencies: AppDependencies) async {
        defer { isRestored = true }
        guard !isRestored, stage == .hook,
              let saved = try? await dependencies.store.loadOnboardingDraft(),
              let savedStage = Stage(rawValue: saved.stage) else { return }
        var trips: [OnboardingTripSummary] = []
        for id in saved.recordedTripIDs {
            if let trip = try? await dependencies.store.trip(id: id) { trips.append(Self.summary(of: trip)) }
        }
        recordedTrips = trips
        homeCountryCode = saved.homeCountryCode
        entryMode = saved.entryMode.flatMap(EntryMode.init(rawValue:))
        conceptQueue = saved.conceptQueue
        conceptIndex = saved.conceptIndex
        tiers = saved.tiers
        switch savedStage {
        case .photoPriming, .photoScanning, .noCandidates, .candidates: stage = .entryModeSelection
        default: stage = savedStage
        }
    }

    // MARK: 스테이지 전환

    func goBack() {
        switch stage {
        case .homeCountry: stage = .hook
        case .entryModeSelection: stage = .homeCountry
        case .photoPriming, .noCandidates, .candidates: scanTask?.cancel(); stage = .entryModeSelection
        case .photoScanning: cancelPhotoScan()
        case .tiers:
            if entryMode != .preferencesOnly, !conceptQueue.isEmpty {
                conceptIndex = conceptQueue.count - 1
                stage = .concepts
            } else {
                stage = .entryModeSelection
            }
        case .hook, .concepts, .summary: break
        }
    }

    func confirmHomeCountry(_ code: String?, dependencies: AppDependencies, session: SessionStore) async {
        homeCountryCode = code
        if let code {
            session.userID = await dependencies.setHomeCountryCode(code)
        }
        stage = .entryModeSelection
    }

    func selectEntryMode(_ mode: EntryMode) {
        entryMode = mode
        errorMessage = nil
        switch mode {
        case .photoScan: stage = .photoPriming
        case .manual: showsManualRegistration = true
        case .preferencesOnly: stage = .tiers
        }
    }

    /// "직접 등록"(여행 등록 화면)에서 저장된 여행을 기록한 여행으로 가져오고 다음 단계로 간다.
    func finishManualRegistration(dependencies: AppDependencies) async {
        let known = Set(recordedTrips.map(\.id))
        let trips = await dependencies.allTrips()
        recordedTrips += trips.filter { !known.contains($0.id) }.map(Self.summary(of:))
        beginConcepts()
    }

    // MARK: 사진첩 스캔

    func startPhotoScan() {
        errorMessage = nil
        scanWasDenied = false
        scanStatusText = "사진 위치 확인 중"
        stage = .photoScanning
        scanTask?.cancel()
        scanTask = Task { [weak self] in
            guard let self else { return }
            do {
                self.candidates = try await PhotoTripScanner.scan(excluding: self.homeCountryCode ?? "") {
                    self.scanStatusText = "여행별로 묶는 중"
                }
                try Task.checkCancellation()
                self.isPhotoAccessLimited = PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited
                self.stage = self.candidates.isEmpty ? .noCandidates : .candidates
            } catch is CancellationError {
                return
            } catch {
                self.scanWasDenied = (error as? PhotoTripScanError) == .accessDenied
                self.candidates = []
                self.stage = .noCandidates
            }
        }
    }

    func cancelPhotoScan() {
        scanTask?.cancel()
        stage = .photoPriming
    }

    /// 제한된 접근에서 시스템 사진 선택 창을 띄우고, 선택을 마치면 다시 스캔한다.
    func presentLimitedPhotoPicker() {
        guard isPhotoAccessLimited, let presenter = UIApplication.shared.topMostViewController else { return }
        Task {
            _ = await PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: presenter)
            startPhotoScan()
        }
    }

    /// 설정 앱에서 "모든 사진"으로 바꾸고 돌아온 경우 전체 사진첩으로 다시 스캔한다.
    func refreshPhotoAccessAfterReturning() {
        guard isPhotoAccessLimited,
              stage == .candidates || stage == .noCandidates,
              PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else { return }
        isPhotoAccessLimited = false
        startPhotoScan()
    }

    // MARK: 후보 확인

    var recordedCandidateCount: Int { candidates.filter { $0.state == .recorded }.count }

    func setState(_ state: TripCandidate.State, for id: UUID) {
        guard let index = candidates.firstIndex(where: { $0.id == id }) else { return }
        candidates[index].state = state
    }

    func setCity(_ city: String, for id: UUID) {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = candidates.firstIndex(where: { $0.id == id }),
              let legIndex = candidates[index].legs.firstIndex(where: { $0.cities.isEmpty }) else { return }
        candidates[index].legs[legIndex].cities = [trimmed]
    }

    /// 날짜가 7일 안으로 가까운, 아직 정하지 않은 다른 후보. 나라는 달라도 된다.
    func mergeSuggestion(for id: UUID) -> TripCandidate? {
        guard let candidate = candidates.first(where: { $0.id == id && $0.state == .pending }) else { return nil }
        return candidates.first { other in
            guard other.id != id, other.state == .pending else { return false }
            let gap = max(
                other.startDate.timeIntervalSince(candidate.endDate),
                candidate.startDate.timeIntervalSince(other.endDate)
            )
            return gap <= 7 * 24 * 60 * 60
        }
    }

    func merge(_ id: UUID, with otherID: UUID) {
        guard let index = candidates.firstIndex(where: { $0.id == id }),
              let otherIndex = candidates.firstIndex(where: { $0.id == otherID }) else { return }
        let other = candidates[otherIndex]
        let otherFirst = other.startDate < candidates[index].startDate
        candidates[index].legs = TripCandidate.joined(candidates[index].legs + other.legs)
        candidates[index].photoAssetIDs = otherFirst
            ? other.photoAssetIDs + candidates[index].photoAssetIDs
            : candidates[index].photoAssetIDs + other.photoAssetIDs
        candidates.remove(at: otherIndex)
    }

    /// 기록하기를 누른 후보만 여행으로 저장하고 컨셉 단계로 넘어간다. 나머지는 저장하지 않는다.
    func commitCandidates(_ dependencies: AppDependencies) async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            for candidate in candidates where candidate.state == .recorded {
                let legs = try candidate.legs.map {
                    try TripLeg(countryCode: $0.countryCode, cities: $0.cities, startDate: $0.startDate, endDate: $0.endDate)
                }
                let created = try await dependencies.tripService.createTrip(
                    legs: legs, companion: .unknown, purpose: .leisure, now: candidate.startDate
                )
                // 사진첩에서 찾은 여행은 다녀온 여행이다. 평가를 기다리는 여행으로 둔다.
                let trip = try await dependencies.tripService.endTrip(id: created.id, at: candidate.endDate)
                recordedTrips.append(Self.summary(of: trip))
            }
            candidates = candidates.filter { $0.state == .pending }
            beginConcepts()
        } catch {
            errorMessage = "여행을 기록하지 못했어요. 다시 시도해 주세요."
        }
    }

    // MARK: 여행별 컨셉

    private func beginConcepts() {
        conceptQueue = recordedTrips.filter { $0.concepts == nil }.map(\.id)
        conceptIndex = 0
        stage = conceptQueue.isEmpty ? .tiers : .concepts
    }

    var currentConceptTrip: OnboardingTripSummary? {
        guard conceptQueue.indices.contains(conceptIndex) else { return nil }
        return recordedTrips.first { $0.id == conceptQueue[conceptIndex] }
    }

    /// 현재 여행의 컨셉을 저장하고(nil이면 건너뛰고) 다음 여행으로 간다.
    func finishConcept(_ concepts: TripConcepts?, dependencies: AppDependencies) async {
        if let concepts, let trip = currentConceptTrip {
            do {
                guard let stored = try await dependencies.store.trip(id: trip.id) else { throw RepositoryError.notFound }
                _ = try await dependencies.tripService.updateTrip(
                    id: trip.id, legs: stored.legs, companion: stored.companion,
                    purpose: stored.purpose, concepts: concepts
                )
                if let index = recordedTrips.firstIndex(where: { $0.id == trip.id }) {
                    recordedTrips[index].concepts = concepts
                }
            } catch {
                errorMessage = "컨셉을 저장하지 못했어요. 여행 탭에서 다시 고를 수 있어요."
            }
        }
        conceptIndex += 1
        if conceptIndex >= conceptQueue.count { stage = .tiers }
    }

    func skipRemainingConcepts() {
        stage = .tiers
    }

    // MARK: 원하는 여행 (티어)

    func placeConcept(_ concept: TripConcept, in tier: Int?) {
        tiers.place(concept, in: tier)
    }

    /// 지난 여행 참고용. 미리 채우지 않고 보여주기만 한다.
    var pastConceptReference: [(concept: TripConcept, count: Int)] {
        var counts: [TripConcept: Int] = [:]
        for primary in recordedTrips.compactMap({ $0.concepts?.primary }) { counts[primary, default: 0] += 1 }
        return TripConcept.allCases.compactMap { concept in counts[concept].map { (concept, $0) } }
            .sorted { $0.count > $1.count }
    }

    func finishTiers(skipped: Bool, dependencies: AppDependencies) async {
        if skipped {
            tiers = WantedConceptTiers()
        } else {
            tiers.avoidNote = tiers.avoidNote?.trimmingCharacters(in: .whitespacesAndNewlines)
            if tiers.avoidNote?.isEmpty == true { tiers.avoidNote = nil }
            if !tiers.isEmpty { try? await dependencies.store.saveWantedTiers(tiers) }
        }
        stage = .summary
    }

    // MARK: 완료

    func finish(dependencies: AppDependencies, session: SessionStore, router: AppRouter, openRecommendation: Bool) {
        router.selectedTab = openRecommendation ? .recommendation : .home
        session.onboardingPhase = .completed
        Task {
            try? await dependencies.store.saveOnboardingDraft(nil)
            await dependencies.markOnboardingCompleted()
        }
    }

    private static func summary(of trip: Trip) -> OnboardingTripSummary {
        let cities = trip.legs.flatMap(\.cities)
        let title = cities.isEmpty
            ? trip.legs.map { CountryCatalog.name(for: $0.countryCode) }.joined(separator: "·")
            : PlaceTitle.compact(cities, separator: "·")
        let start = trip.legs.map(\.startDate).min() ?? trip.createdAt
        let end = trip.legs.map(\.endDate).max() ?? start
        return OnboardingTripSummary(
            id: trip.id, title: title,
            period: OnboardingFormat.dateRangeText(start: start, end: end),
            concepts: trip.purpose == .leisure ? trip.concepts : nil
        )
    }

    // MARK: 퀴즈 응답 (온보딩에서는 더 이상 화면으로 연결하지 않는다)

    func answerQuiz(option: QuizOption?) {
        if let question = currentQuizQuestion {
            quizAnswers.append(QuizAnswer(questionID: question.id, signatures: option?.signature ?? [:]))
        }
        quizQuestionIndex += 1
    }

    func answerQuizAcceptingBoth() {
        guard let question = currentQuizQuestion else { return }
        quizAnswers.append(QuizAnswer(
            questionID: question.id,
            signatures: [:],
            acceptedAxes: Set(question.options.flatMap { $0.signature.keys })
        ))
        quizQuestionIndex += 1
    }

    /// 첫 문항 이전이면 false.
    func goBackInQuiz() -> Bool {
        guard quizQuestionIndex > 0 else { return false }
        quizQuestionIndex -= 1
        if !quizAnswers.isEmpty { quizAnswers.removeLast() }
        return true
    }

    private var currentQuizQuestion: QuizQuestion? {
        quizQuestionIndex < quizQuestions.count ? quizQuestions[quizQuestionIndex] : nil
    }
}

private extension UIApplication {
    /// UIKit 전용 API(`presentLimitedLibraryPicker`)를 띄울 최상단 뷰 컨트롤러.
    var topMostViewController: UIViewController? {
        let scenes = connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

enum PhotoTripScanError: LocalizedError {
    case accessDenied

    var errorDescription: String? {
        "사진 접근을 허용해야 위치가 있는 여행 사진을 찾을 수 있어요. 설정에서 사진 접근을 허용하거나 직접 등록해 주세요."
    }
}

/// 사진의 위치·촬영 시각·식별자만 읽는다. 사진 원본은 스캔 결과에 보관하지 않는다.
@MainActor
private enum PhotoTripScanner {
    private struct DatedAsset {
        let date: Date
        let assetID: String
        let location: CLLocation
    }

    /// 칸의 위도·경도 중앙값에 가장 가까운 실제 사진 위치. 공항 사진 한 장이 칸 이름을 정하지 않게 한다.
    /// 사진이 공항·외곽에 몰렸다면 여전히 그쪽 이름이 나온다.
    private static func representativeLocation(of photos: [DatedAsset]) -> CLLocation {
        func median(_ values: [Double]) -> Double { values.sorted()[values.count / 2] }
        let lat = median(photos.map(\.location.coordinate.latitude))
        let lon = median(photos.map(\.location.coordinate.longitude))
        return photos.min {
            pow($0.location.coordinate.latitude - lat, 2) + pow($0.location.coordinate.longitude - lon, 2)
                < pow($1.location.coordinate.latitude - lat, 2) + pow($1.location.coordinate.longitude - lon, 2)
        }!.location
    }

    static func scan(excluding homeCountryCode: String, onGrouping: () -> Void) async throws -> [TripCandidate] {
        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        guard status == .authorized || status == .limited else {
            throw PhotoTripScanError.accessDenied
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 1000
        let assets = PHAsset.fetchAssets(with: .image, options: options)
        var buckets: [String: [DatedAsset]] = [:]
        assets.enumerateObjects { asset, _, _ in
            guard let location = asset.location, let date = asset.creationDate else { return }
            let key = "\(Int(location.coordinate.latitude.rounded())):\(Int(location.coordinate.longitude.rounded()))"
            buckets[key, default: []].append(DatedAsset(date: date, assetID: asset.localIdentifier, location: location))
        }
        onGrouping()

        var located: [TripCandidate.Photo] = []
        let geocoder = CLGeocoder()
        for photos in buckets.values.sorted(by: { $0.count > $1.count }).prefix(24) {
            try Task.checkCancellation()
            guard let place = try? await geocoder.reverseGeocodeLocation(representativeLocation(of: photos)).first,
                  let code = place.isoCountryCode?.uppercased() else { continue }
            // 집에서 찍은 사진은 여행을 끊는 데만 쓴다.
            let isHome = code == homeCountryCode.uppercased()
            guard isHome || CountryCatalog.profiles[code] != nil else { continue }
            located += photos.map {
                TripCandidate.Photo(
                    countryCode: isHome ? nil : code, city: place.locality, date: $0.date, assetID: $0.assetID,
                    timeZone: place.timeZone ?? .current
                )
            }
        }
        return TripCandidate.group(located)
    }
}

// MARK: - 공용 유틸

enum TagCatalog {
    nonisolated(unsafe) static var definitions: [String: TagDefinition] = [:]

    nonisolated static func labelKo(for id: String) -> String {
        definitions[id]?.labelKo ?? id
    }
}
