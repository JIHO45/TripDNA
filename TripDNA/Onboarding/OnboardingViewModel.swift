import Foundation
import CoreLocation
import Photos
import PhotosUI
import SwiftUI

/// 사진첩에서 찾은 여행 후보. 사용자가 "기록하기"를 누른 것만 여행으로 저장된다.
struct TripCandidate: Identifiable {
    enum State { case pending, recorded, removed }

    let id = UUID()
    var countryCode: String
    /// 도시를 모르면 비어 있다. 추측해서 채우지 않는다.
    var cities: [String]
    var startDate: Date
    var endDate: Date
    /// `PHAsset.localIdentifier` (촬영순). 카드 표시 전용이며 저장·업로드하지 않는다.
    var photoAssetIDs: [String]
    var state: State = .pending

    var isCityUnknown: Bool { cities.isEmpty }
    var title: String { cities.isEmpty ? CountryCatalog.name(for: countryCode) : cities.joined(separator: "·") }
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

@Observable
final class OnboardingViewModel {
    enum Stage: Equatable {
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

    enum EntryMode {
        case photoScan
        case manual
        case preferencesOnly
    }

    var stage: Stage = .hook
    var entryMode: EntryMode?
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

    // MARK: 스테이지 전환

    func goBack() {
        switch stage {
        case .homeCountry: stage = .hook
        case .entryModeSelection: stage = .homeCountry
        case .photoPriming, .noCandidates, .candidates: scanTask?.cancel(); stage = .entryModeSelection
        case .photoScanning: cancelPhotoScan()
        case .hook, .concepts, .tiers, .summary: break
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
        guard !trimmed.isEmpty, let index = candidates.firstIndex(where: { $0.id == id }) else { return }
        candidates[index].cities = [trimmed]
    }

    /// 같은 나라이고 날짜가 3일 안으로 이어지는, 아직 정하지 않은 다른 후보.
    func mergeSuggestion(for id: UUID) -> TripCandidate? {
        guard let candidate = candidates.first(where: { $0.id == id && $0.state == .pending }) else { return nil }
        return candidates.first { other in
            guard other.id != id, other.state == .pending, other.countryCode == candidate.countryCode else { return false }
            let gap = max(
                other.startDate.timeIntervalSince(candidate.endDate),
                candidate.startDate.timeIntervalSince(other.endDate)
            )
            return gap <= 3 * 24 * 60 * 60
        }
    }

    func merge(_ id: UUID, with otherID: UUID) {
        guard let index = candidates.firstIndex(where: { $0.id == id }),
              let otherIndex = candidates.firstIndex(where: { $0.id == otherID }) else { return }
        let other = candidates[otherIndex]
        candidates[index].cities += other.cities.filter { !candidates[index].cities.contains($0) }
        candidates[index].startDate = min(candidates[index].startDate, other.startDate)
        candidates[index].endDate = max(candidates[index].endDate, other.endDate)
        candidates[index].photoAssetIDs += other.photoAssetIDs
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
                let leg = try TripLeg(
                    countryCode: candidate.countryCode,
                    cities: candidate.cities,
                    startDate: candidate.startDate,
                    endDate: candidate.endDate
                )
                let trip = try await dependencies.tripService.createTrip(
                    legs: [leg], companion: .unknown, purpose: .leisure, now: candidate.startDate
                )
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
        Task { await dependencies.markOnboardingCompleted() }
    }

    private static func summary(of trip: Trip) -> OnboardingTripSummary {
        let cities = trip.legs.flatMap(\.cities)
        let title = cities.isEmpty
            ? trip.legs.map { CountryCatalog.name(for: $0.countryCode) }.joined(separator: "·")
            : cities.joined(separator: "·")
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
    }

    private struct LocatedPhoto {
        let countryCode: String
        /// 역지오코딩이 알려준 도시(locality). 모르면 nil.
        let city: String?
        let date: Date
        let assetID: String
    }

    private struct GroupKey: Hashable {
        let countryCode: String
        let city: String?
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
        var buckets: [String: (location: CLLocation, photos: [DatedAsset])] = [:]
        assets.enumerateObjects { asset, _, _ in
            guard let location = asset.location, let date = asset.creationDate else { return }
            let key = "\(Int(location.coordinate.latitude.rounded())):\(Int(location.coordinate.longitude.rounded()))"
            if buckets[key] == nil { buckets[key] = (location, []) }
            buckets[key]?.photos.append(DatedAsset(date: date, assetID: asset.localIdentifier))
        }
        onGrouping()

        var located: [LocatedPhoto] = []
        let geocoder = CLGeocoder()
        for bucket in buckets.values.sorted(by: { $0.photos.count > $1.photos.count }).prefix(24) {
            try Task.checkCancellation()
            guard let place = try? await geocoder.reverseGeocodeLocation(bucket.location).first,
                  let code = place.isoCountryCode?.uppercased(),
                  code != homeCountryCode.uppercased(),
                  CountryCatalog.profiles[code] != nil else { continue }
            let city = place.locality
            located += bucket.photos.map { LocatedPhoto(countryCode: code, city: city, date: $0.date, assetID: $0.assetID) }
        }

        let calendar = Calendar.current
        var groups: [(key: GroupKey, photos: [LocatedPhoto])] = []
        let keys = Set(located.map { GroupKey(countryCode: $0.countryCode, city: $0.city) })
        for key in keys.sorted(by: { ($0.countryCode, $0.city ?? "") < ($1.countryCode, $1.city ?? "") }) {
            let photos = located.filter { $0.countryCode == key.countryCode && $0.city == key.city }.sorted { $0.date < $1.date }
            for photo in photos {
                if let last = groups.indices.last,
                   groups[last].key == key,
                   let previous = groups[last].photos.last,
                   photo.date.timeIntervalSince(previous.date) <= 14 * 24 * 60 * 60 {
                    groups[last].photos.append(photo)
                } else {
                    groups.append((key, [photo]))
                }
            }
        }
        return groups.filter { $0.photos.count >= 2 }.sorted { $0.photos[0].date > $1.photos[0].date }.prefix(12).map { group in
            TripCandidate(
                countryCode: group.key.countryCode,
                cities: group.key.city.map { [$0] } ?? [],
                startDate: calendar.startOfDay(for: group.photos.first!.date),
                endDate: calendar.startOfDay(for: group.photos.last!.date),
                photoAssetIDs: group.photos.map(\.assetID)
            )
        }
    }
}

// MARK: - 공용 유틸

enum TagCatalog {
    nonisolated(unsafe) static var definitions: [String: TagDefinition] = [:]

    nonisolated static func labelKo(for id: String) -> String {
        definitions[id]?.labelKo ?? id
    }
}
