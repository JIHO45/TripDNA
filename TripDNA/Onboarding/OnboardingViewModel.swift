import Foundation
import CoreLocation
import Photos
import PhotosUI
import SwiftUI

struct ManualTripDraft: Identifiable {
    let id = UUID()
    var countryCode: String = ""
    var startDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    var endDate: Date = Calendar.current.date(byAdding: .day, value: -25, to: Date()) ?? Date()
    var companion: Companion = .alone
    var purpose: TripPurpose = .leisure
    var satisfaction: Int = 4
    var wouldRepeat: Bool = true
    var positiveTagIDs: Set<String> = []
    /// 스캔 카드 루프의 서열 비교 응답. 직전에 확정한 여행이 비교 앵커가 된다.
    var comparison: ComparisonResult?
    /// 사진첩 스캔으로 묶인 사진의 `PHAsset.localIdentifier` (촬영순). 카드 표시 전용이며 저장·업로드하지 않는다.
    var photoAssetIDs: [String] = []
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

    static func periodText(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월"
        let days = max(1, (Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
        return "\(formatter.string(from: start)) · \(days)일"
    }

    static let satisfactionEmojis = ["😞", "😕", "😐", "😊", "🤩"]
}

@Observable
final class OnboardingViewModel {
    enum Stage: Equatable {
        case hook               // 1A-1 가치 선언
        case hookExpectation    // 1A-2 기대 설정
        case homeCountry
        case entryModeSelection // 1B-1
        case photoPriming       // 1B-2
        case photoScanning      // 1B-4 (0건 결과 화면 포함)
        case photoScanReview    // 1B-5 카드 루프
        case manualEntry        // 1B 직접 입력
        case quiz               // 1C
        case analyzing          // 1D-1 지문 합성 연출
        case result             // 1D-2·1D-3
        case appleSignIn        // 2A (온보딩 페이오프 후 계정 연결)
    }

    enum EntryMode {
        case photoScan
        case manual
        case quiz
    }

    var stage: Stage = .hook
    var entryMode: EntryMode?
    /// 사용자가 온보딩에서 명시적으로 선택한 거주 국가 코드.
    var homeCountryCode = ""

    var manualDrafts: [ManualTripDraft] = []
    var photoScanDrafts: [ManualTripDraft] = []

    // MARK: 사진첩 스캔 연출 상태

    var scanStatusText = ""
    /// 스캔이 끝났지만 여행이 0건(또는 전부 제거됨)일 때 대체 경로를 보여준다.
    var scanFoundNothing = false
    var scanCardIndex = 0
    /// 사용자가 "사진 선택…"(제한된 접근)을 골라 일부 사진만 스캔된 상태.
    var isPhotoAccessLimited = false
    private var scanTask: Task<Void, Never>?

    // MARK: 퀴즈 상태

    /// 출제 문항 풀. 미니 퀴즈(축 신뢰도 게이트)에서는 부족한 축 문항만 담긴다.
    var quizQuestions: [QuizQuestion] = QuizQuestionCatalog.allQuestions
    var isMiniQuiz = false
    /// 미니 퀴즈를 마친 뒤 추천 후보에서 뺄 여행 국가. 여행 경로에서 넘어올 때만 채워진다.
    private var miniQuizVisitedCountryCodes: Set<String> = []
    var quizQuestionIndex = 0
    var quizAnswers: [QuizAnswer] = []
    var selectedInterestTagIDs: Set<String> = []

    // MARK: 결과 상태

    var isSubmitting = false
    var errorMessage: String?
    var resultVector: UserTasteVector?
    var recommendations: [Recommendation] = []
    var exposure: RecommendationExposure?
    var firstRecommendation: Recommendation? { recommendations.first }
    private var analysisStartedAt: Date?

    var currentQuizQuestion: QuizQuestion? {
        guard quizQuestionIndex < quizQuestions.count else { return nil }
        return quizQuestions[quizQuestionIndex]
    }

    var isQuizAnswering: Bool {
        currentQuizQuestion != nil
    }

    /// 상단 세그먼트 진행 바에 쓰이는 시각용 값. 실제 제출·분기 로직에는 영향을 주지 않는다.
    var progress: Double {
        switch stage {
        case .hook: return 0
        case .hookExpectation: return 0.08
        case .homeCountry: return 0.18
        case .entryModeSelection: return 0.3
        case .photoPriming: return 0.4
        case .photoScanning: return 0.48
        case .photoScanReview:
            guard !photoScanDrafts.isEmpty else { return 0.55 }
            return 0.5 + 0.4 * Double(scanCardIndex) / Double(photoScanDrafts.count)
        case .manualEntry:
            return 0.5 + 0.4 * min(1, Double(manualDrafts.count) / 3)
        case .quiz:
            let total = Double(quizQuestions.count + 1)
            return total > 0 ? Double(min(quizQuestionIndex, quizQuestions.count)) / total : 0
        case .analyzing: return 0.95
        case .result, .appleSignIn: return 1
        }
    }

    // MARK: 스테이지 전환

    func advanceFromHook() {
        stage = .hookExpectation
    }

    func advanceToHomeCountry() {
        stage = .homeCountry
    }

    /// 훅 이후 모든 화면의 상단 뒤로가기. 카드 루프·퀴즈 내부 이동은 각 화면이 먼저 처리한다.
    func goBack() {
        switch stage {
        case .hook:
            break
        case .hookExpectation:
            stage = .hook
        case .homeCountry:
            stage = .hookExpectation
        case .entryModeSelection:
            stage = .homeCountry
        case .photoPriming:
            stage = .entryModeSelection
        case .photoScanning:
            cancelPhotoScan()
        case .photoScanReview:
            scanTask?.cancel()
            stage = .photoPriming
        case .manualEntry, .quiz:
            stage = .entryModeSelection
        case .analyzing:
            break
        case .result:
            break
        case .appleSignIn:
            stage = .result
        }
    }

    func confirmHomeCountry(_ code: String, dependencies: AppDependencies, session: SessionStore) async {
        homeCountryCode = code
        session.userID = await dependencies.setHomeCountryCode(code)
        stage = .entryModeSelection
    }

    func selectEntryMode(_ mode: EntryMode) {
        entryMode = mode
        errorMessage = nil
        switch mode {
        case .photoScan:
            scanFoundNothing = false
            stage = .photoPriming
        case .manual:
            manualDrafts = []
            stage = .manualEntry
        case .quiz:
            quizQuestions = QuizQuestionCatalog.allQuestions
            isMiniQuiz = false
            quizQuestionIndex = 0
            quizAnswers = []
            selectedInterestTagIDs = []
            stage = .quiz
        }
    }

    // MARK: 사진첩 스캔

    func startPhotoScan() {
        errorMessage = nil
        scanFoundNothing = false
        scanStatusText = "사진 위치 확인 중"
        stage = .photoScanning
        scanTask?.cancel()
        scanTask = Task { [weak self] in
            guard let self else { return }
            do {
                self.photoScanDrafts = try await PhotoTripScanner.scan(excluding: self.homeCountryCode) {
                    self.scanStatusText = "여행별로 묶는 중"
                }
                try Task.checkCancellation()
                self.isPhotoAccessLimited = PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited
                self.scanCardIndex = 0
                self.scanFoundNothing = self.photoScanDrafts.isEmpty
                if !self.scanFoundNothing { self.stage = .photoScanReview }
            } catch is CancellationError {
                return
            } catch {
                self.errorMessage = error.localizedDescription
                self.scanFoundNothing = true
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
              stage == .photoScanReview || (stage == .photoScanning && scanFoundNothing),
              PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else { return }
        isPhotoAccessLimited = false
        startPhotoScan()
    }

    // MARK: 스캔 카드 루프

    var currentScanDraft: ManualTripDraft? {
        photoScanDrafts.indices.contains(scanCardIndex) ? photoScanDrafts[scanCardIndex] : nil
    }

    /// 서열 비교의 앵커 = 직전에 확정한 카드.
    var scanAnchorDraft: ManualTripDraft? {
        let anchorIndex = scanCardIndex - 1
        return photoScanDrafts.indices.contains(anchorIndex) ? photoScanDrafts[anchorIndex] : nil
    }

    var canFinishScanEarly: Bool {
        scanCardIndex >= 3
    }

    func setScanSatisfaction(_ value: Int) {
        guard photoScanDrafts.indices.contains(scanCardIndex) else { return }
        photoScanDrafts[scanCardIndex].satisfaction = value
    }

    func setScanComparison(_ result: ComparisonResult) {
        guard photoScanDrafts.indices.contains(scanCardIndex) else { return }
        photoScanDrafts[scanCardIndex].comparison = result
    }

    /// 현재 카드 응답 완료 → 다음 카드 또는 제출.
    func advanceScanCard(_ dependencies: AppDependencies, session: SessionStore) async {
        if scanCardIndex + 1 < photoScanDrafts.count {
            scanCardIndex += 1
        } else {
            await submitBackfill(dependencies, session: session)
        }
    }

    /// "이 여행 아니에요" — 핀 오탐 제거.
    func removeCurrentScanDraft(_ dependencies: AppDependencies, session: SessionStore) async {
        guard photoScanDrafts.indices.contains(scanCardIndex) else { return }
        photoScanDrafts.remove(at: scanCardIndex)
        if photoScanDrafts.isEmpty {
            scanFoundNothing = true
            stage = .photoScanning
        } else if scanCardIndex >= photoScanDrafts.count {
            await submitBackfill(dependencies, session: session)
        }
    }

    /// "나머지는 나중에" — 확정한 카드까지만 제출하고 조기 페이오프.
    func finishScanEarly(_ dependencies: AppDependencies, session: SessionStore) async {
        guard canFinishScanEarly else { return }
        photoScanDrafts = Array(photoScanDrafts.prefix(scanCardIndex))
        await submitBackfill(dependencies, session: session)
    }

    // MARK: 퀴즈

    func answerQuiz(option: QuizOption?) {
        if let question = currentQuizQuestion {
            quizAnswers.append(QuizAnswer(
                questionID: question.id,
                signatures: option?.signature ?? [:]
            ))
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

    /// 퀴즈 내부 뒤로가기. 첫 문항 이전이면 false를 돌려주고 화면이 스테이지 이동을 맡는다.
    func goBackInQuiz() -> Bool {
        guard quizQuestionIndex > 0 else { return false }
        quizQuestionIndex -= 1
        if !quizAnswers.isEmpty {
            quizAnswers.removeLast()
        }
        return true
    }

    func toggleInterestTag(_ tagID: String) {
        if selectedInterestTagIDs.contains(tagID) {
            selectedInterestTagIDs.remove(tagID)
        } else if selectedInterestTagIDs.count < 3 {
            selectedInterestTagIDs.insert(tagID)
        }
    }

    // MARK: 직접 입력

    func registerManualDraft(_ draft: ManualTripDraft) {
        manualDrafts.append(draft)
    }

    func removeManualDraft(id: UUID) {
        manualDrafts.removeAll { $0.id == id }
    }

    // MARK: 제출

    func submitBackfill(_ dependencies: AppDependencies, session: SessionStore) async {
        let drafts = entryMode == .photoScan ? photoScanDrafts : manualDrafts
        let validDrafts = drafts.filter { $0.countryCode.trimmingCharacters(in: .whitespaces).count == 2 }
        guard !validDrafts.isEmpty else {
            errorMessage = "등록된 여행이 없어요. 여행을 하나 이상 등록해주세요."
            return
        }

        let previousStage = stage
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            var visitedCountryCodes: Set<String> = []
            var previousTripID: String?
            for draft in validDrafts {
                let leg = try TripLeg(
                    countryCode: draft.countryCode,
                    startDate: draft.startDate,
                    endDate: draft.endDate
                )
                visitedCountryCodes.insert(leg.countryCode)
                var trip = try await dependencies.tripService.createTrip(
                    legs: [leg],
                    companion: draft.companion,
                    purpose: draft.purpose,
                    now: draft.startDate
                )
                trip = try await dependencies.tripService.endTrip(id: trip.id, at: draft.endDate)
                let comparison: TripComparison? = draft.comparison.map {
                    TripComparison(versusTripID: previousTripID, result: $0)
                }
                let evaluation = try TripEvaluation(
                    satisfaction: draft.satisfaction,
                    wouldRepeat: draft.wouldRepeat,
                    comparison: comparison,
                    positiveTagIDs: Array(draft.positiveTagIDs),
                    source: .onboardingBackfill
                )
                _ = try await dependencies.evaluationService.submit(
                    tripID: trip.id,
                    evaluation: evaluation,
                    userID: session.userID,
                    at: draft.endDate
                )
                previousTripID = trip.id
            }

            let vector = try await dependencies.store.currentUTV()
            try await dependencies.setInterestTagIDs(Set(validDrafts.flatMap(\.positiveTagIDs)))

            if let vector, startMiniQuizIfNeeded(for: vector, dependencies: dependencies, visited: visitedCountryCodes) {
                return
            }
            beginAnalysis()
            try await showResult(vector: vector, dependencies: dependencies, visited: visitedCountryCodes)
        } catch {
            errorMessage = "등록 중 문제가 발생했어요. 입력값을 확인해주세요."
            stage = previousStage
        }
    }

    // MARK: 미니 퀴즈 (여행 경로 뒤 흐린 축 보강)

    /// 여행 기록으로 드러나지 않은 축만 짧게 묻는다. 물을 문항이 없으면 false.
    private func startMiniQuizIfNeeded(
        for vector: UserTasteVector,
        dependencies: AppDependencies,
        visited: Set<String>
    ) -> Bool {
        let axes = dependencies.quizService.axesRequiringQuestions(confidence: vector.confidence)
        let questions = QuizQuestionCatalog.miniQuizQuestions(for: axes)
        guard !questions.isEmpty else { return false }
        quizQuestions = questions
        isMiniQuiz = true
        quizQuestionIndex = 0
        quizAnswers = []
        miniQuizVisitedCountryCodes = visited
        stage = .quiz
        return true
    }

    /// 여행은 이미 저장됐으므로 답이 하나도 없어도 결과로 넘어간다.
    /// 답한 축은 퀴즈 prior로 저장해 원장 재생의 출발점이 된다.
    func finishMiniQuiz(_ dependencies: AppDependencies, session: SessionStore) async {
        guard isMiniQuiz, !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        beginAnalysis()
        defer { isSubmitting = false }

        do {
            if !quizAnswers.isEmpty {
                let previousAnswers = try await dependencies.store.loadQuizAnswers()
                let replacedIDs = Set(quizAnswers.map(\.questionID))
                let merged = previousAnswers.filter { !replacedIDs.contains($0.questionID) } + quizAnswers
                let result = dependencies.quizService.score(answers: merged, interestTagIDs: [])
                try await dependencies.store.saveQuizAnswers(merged)
                try await dependencies.store.saveTastePrior(result.prior)
                _ = try await dependencies.evaluationService.recompute(
                    userID: session.userID,
                    trigger: "mini_quiz"
                )
            }
            try await showResult(
                vector: try await dependencies.store.currentUTV(),
                dependencies: dependencies,
                visited: miniQuizVisitedCountryCodes
            )
            isMiniQuiz = false
        } catch {
            errorMessage = "취향 지문을 계산하지 못했어요. 다시 시도해주세요."
            stage = .quiz
        }
    }

    private func showResult(
        vector: UserTasteVector?,
        dependencies: AppDependencies,
        visited: Set<String>
    ) async throws {
        resultVector = vector
        if let vector {
            recommendations = try await dependencies.recommendationService.generateThreeSlots(
                vector: vector,
                interestTagIDs: dependencies.interestTagIDs,
                visitedCountryCodes: dependencies.excludedCountryCodes(visited: visited)
            )
        }
        await waitForAnalysisPayoff()
        prepareExposure(dependencies, visited: visited)
        stage = .result
    }

    func finishQuiz(_ dependencies: AppDependencies, session: SessionStore) async {
        let previousStage = stage
        isSubmitting = true
        errorMessage = nil
        beginAnalysis()
        defer { isSubmitting = false }

        let result = dependencies.quizService.score(
            answers: quizAnswers,
            interestTagIDs: selectedInterestTagIDs
        )
        let vector = UserTasteVector(
            userID: session.userID,
            axes: result.prior,
            confidence: result.confidence,
            ledgerVersion: 0,
            recomputedAt: Date(),
            acceptedAxes: result.acceptedAxes
        )
        do {
            try await dependencies.store.saveQuizAnswers(quizAnswers)
            try await dependencies.store.saveTastePrior(result.prior)
            try await dependencies.store.save(vector)
            try await dependencies.setInterestTagIDs(result.interestTagIDs)
            resultVector = vector
            recommendations = try await dependencies.recommendationService.generateThreeSlots(
                vector: vector,
                interestTagIDs: result.interestTagIDs,
                visitedCountryCodes: dependencies.excludedCountryCodes(visited: [])
            )
            await waitForAnalysisPayoff()
            prepareExposure(dependencies, visited: [])
            stage = .result
        } catch {
            errorMessage = "취향 지문을 계산하지 못했어요. 다시 시도해주세요."
            stage = previousStage
        }
    }

    func proceedToSignIn() {
        stage = .appleSignIn
    }

    private func prepareExposure(_ dependencies: AppDependencies, visited: Set<String>) {
        guard let resultVector else { exposure = nil; return }
        exposure = RecommendationExposure(
            source: "onboarding", cards: recommendations, vector: resultVector,
            interests: dependencies.interestTagIDs,
            excludedCountries: dependencies.excludedCountryCodes(visited: visited),
            homeCountry: dependencies.homeCountryCode
        )
    }

    func completeSignIn(session: SessionStore, appleUserID: String) {
        session.applyAppleSignIn(userID: appleUserID)
        session.onboardingPhase = .completed
    }

    // MARK: 분석 연출 (1D-1)

    /// 결과 계산이 아무리 빨라도 2~4초의 지문 합성 연출을 보장한다.
    private static let minimumAnalysisDuration: TimeInterval = 2.8

    private func beginAnalysis() {
        analysisStartedAt = Date()
        stage = .analyzing
    }

    private func waitForAnalysisPayoff() async {
        guard let startedAt = analysisStartedAt else { return }
        let remaining = Self.minimumAnalysisDuration - Date().timeIntervalSince(startedAt)
        if remaining > 0 {
            try? await Task.sleep(for: .seconds(remaining))
        }
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

private enum PhotoTripScanError: LocalizedError {
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
        let date: Date
        let assetID: String
    }

    static func scan(excluding homeCountryCode: String, onGrouping: () -> Void) async throws -> [ManualTripDraft] {
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
            located += bucket.photos.map { LocatedPhoto(countryCode: code, date: $0.date, assetID: $0.assetID) }
        }

        let calendar = Calendar.current
        var groups: [(code: String, photos: [LocatedPhoto])] = []
        for code in Set(located.map(\.countryCode)).sorted() {
            let photos = located.filter { $0.countryCode == code }.sorted { $0.date < $1.date }
            for photo in photos {
                if let last = groups.indices.last,
                   groups[last].code == code,
                   let previous = groups[last].photos.last,
                   photo.date.timeIntervalSince(previous.date) <= 14 * 24 * 60 * 60 {
                    groups[last].photos.append(photo)
                } else {
                    groups.append((code, [photo]))
                }
            }
        }
        return groups.filter { $0.photos.count >= 2 }.sorted { $0.photos[0].date > $1.photos[0].date }.prefix(12).map { group in
            var draft = ManualTripDraft()
            draft.countryCode = group.code
            draft.startDate = calendar.startOfDay(for: group.photos.first!.date)
            draft.endDate = calendar.startOfDay(for: group.photos.last!.date)
            draft.photoAssetIDs = group.photos.map(\.assetID)
            return draft
        }
    }
}
