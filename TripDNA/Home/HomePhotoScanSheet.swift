import SwiftUI

/// 홈의 "사진첩에서 찾기". 온보딩의 사진 단계(설명 → 스캔 → 후보 확인)와 여행별 컨셉 단계를 새 상태로 재사용한다.
/// 사는 나라·티어 단계는 거치지 않고, 온보딩 진행 상태 저장(`saveDraft`)과 완료 처리도 하지 않는다.
struct HomePhotoScanSheet: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: OnboardingViewModel = {
        let model = OnboardingViewModel()
        model.entryMode = .photoScan
        model.isFromHome = true
        model.stage = .photoPriming
        return model
    }()

    var body: some View {
        ZStack {
            AppCanvas()
            switch viewModel.stage {
            case .photoPriming:
                OnboardingPhotoPrimingView(viewModel: viewModel)
            case .photoScanning:
                OnboardingPhotoScanningView(viewModel: viewModel)
            case .noCandidates:
                OnboardingNoCandidatesView(viewModel: viewModel)
            case .candidates:
                OnboardingCandidatesView(viewModel: viewModel, dependencies: dependencies)
            case .concepts:
                OnboardingConceptsView(viewModel: viewModel, dependencies: dependencies)
            default:
                // 뒤로 가기·컨셉 끝·취향부터 시작 등으로 이 흐름 밖 단계에 닿으면 시트를 닫는다.
                Color.clear
            }
        }
        .onAppear { viewModel.homeCountryCode = dependencies.homeCountryCode }
        .onChange(of: viewModel.stage) {
            switch viewModel.stage {
            case .photoPriming, .photoScanning, .noCandidates, .candidates, .concepts: break
            default: dismiss()
            }
        }
        // "직접 등록으로 바꾸기"는 온보딩과 같이 여행 등록 화면을 연다.
        .sheet(isPresented: $viewModel.showsManualRegistration) {
            NavigationStack {
                TripRegistrationView(prefilledCountryCode: nil) {
                    Task { await viewModel.finishManualRegistration(dependencies: dependencies) }
                }
            }
        }
    }
}
