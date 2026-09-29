import SwiftUI

// MARK: - 1C 사진 취향 퀴즈

struct OnboardingQuizView: View {
    let viewModel: OnboardingViewModel
    let dependencies: AppDependencies
    let session: SessionStore

    @State private var selectedOptionID: UUID?

    private let interestTagIDs = [
        "food", "culture", "history", "outdoor", "beach",
        "nightlife", "shopping", "wellness", "sportsAndEvents"
    ]

    var body: some View {
        VStack(spacing: 0) {
            DNAStepTopBar(
                progress: quizProgress,
                counterText: counterText,
                trailingTitle: viewModel.isQuizAnswering ? "건너뛰기" : nil,
                onBack: { handleBack() },
                onTrailing: { skipCurrentQuestion() }
            )

            if viewModel.isMiniQuiz {
                Text("여행 기록으로 덜 드러난 취향만 물어볼게요")
                    .font(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
                    .padding(.top, DNASpacing.sm)
            }

            if let question = viewModel.currentQuizQuestion {
                questionView(question)
                    .id(question.id)
                    .transition(transition(for: question))
            } else if viewModel.isMiniQuiz {
                miniQuizFinishStep
                    .transition(.opacity)
            } else {
                interestStep
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: viewModel.quizQuestionIndex)
    }

    private var quizProgress: Double {
        let total = Double(viewModel.quizQuestions.count) + 1 // 관심사 화면 포함
        return Double(min(viewModel.quizQuestionIndex, viewModel.quizQuestions.count) + (viewModel.isQuizAnswering ? 0 : 1)) / total
    }

    private var counterText: String? {
        guard viewModel.isQuizAnswering else { return nil }
        return "\(viewModel.quizQuestionIndex + 1) / \(viewModel.quizQuestions.count)"
    }

    /// A/B 구간은 빠른 슬라이드, Q13(2×2)부터는 크로스페이드로 구간 전환 신호를 준다.
    private func transition(for question: QuizQuestion) -> AnyTransition {
        if question.options.count == 4 {
            return .opacity.combined(with: .scale(scale: 0.98))
        }
        return .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    // MARK: 문항

    private func questionView(_ question: QuizQuestion) -> some View {
        VStack(spacing: DNASpacing.lg) {
            Spacer()
            Text(question.prompt)
                .font(.title3.bold())
                .foregroundStyle(Color.dnaTextPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DNASpacing.lg)

            if question.options.count == 4 {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DNASpacing.sm) {
                    ForEach(question.options) { option in
                        DNAChoiceCard(text: option.text, isSelected: selectedOptionID == option.id) {
                            choose(option)
                        }
                    }
                }
                .padding(.horizontal, DNASpacing.lg)
            } else {
                VStack(spacing: DNASpacing.sm) {
                    ForEach(question.options) { option in
                        DNAChoiceCard(text: option.text, isSelected: selectedOptionID == option.id) {
                            choose(option)
                        }
                    }
                }
                .padding(.horizontal, DNASpacing.lg)
            }
            Spacer()
            DNABottomCTA {
                Button(question.options.count == 2 ? "둘 다 좋아요" : "모두 좋아요") {
                    guard selectedOptionID == nil else { return }
                    viewModel.answerQuizAcceptingBoth()
                }
                .buttonStyle(.dnaSecondary)
                Button(QuizQuestionCatalog.escapeText) {
                    skipCurrentQuestion()
                }
                .buttonStyle(.dnaGhost)
            }
        }
    }

    /// 탭 즉시 체크 표시를 보여주고 0.3초 뒤 자동으로 다음 문항으로 넘어간다.
    private func choose(_ option: QuizOption) {
        guard selectedOptionID == nil else { return }
        selectedOptionID = option.id
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            viewModel.answerQuiz(option: option)
            selectedOptionID = nil
        }
    }

    private func skipCurrentQuestion() {
        guard selectedOptionID == nil else { return }
        viewModel.answerQuiz(option: nil)
    }

    private func handleBack() {
        guard selectedOptionID == nil else { return }
        guard !viewModel.goBackInQuiz() else { return }
        if viewModel.isMiniQuiz {
            // 여행은 이미 저장됐으므로 입력 방식 선택으로 되돌아가지 않고 지금까지의 답으로 마무리한다.
            Task { await viewModel.finishMiniQuiz(dependencies, session: session) }
        } else {
            viewModel.goBack()
        }
    }

    // MARK: 미니 퀴즈 마무리

    /// 관심사는 여행 태그로 이미 받았으므로 묻지 않고 바로 지문을 다시 계산한다.
    /// 실패했을 때만 재시도 버튼을 보여 자동 재시도 반복을 막는다.
    private var miniQuizFinishStep: some View {
        VStack(spacing: DNASpacing.lg) {
            Spacer()
            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.dnaError)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DNASpacing.lg)
                Button("다시 시도") {
                    Task { await viewModel.finishMiniQuiz(dependencies, session: session) }
                }
                .buttonStyle(.dnaSecondary)
                .frame(maxWidth: 260)
            } else {
                ProgressView()
                    .tint(Color.dnaTextSecondary)
            }
            Spacer()
        }
        .task {
            guard viewModel.errorMessage == nil else { return }
            await viewModel.finishMiniQuiz(dependencies, session: session)
        }
    }

    // MARK: 관심사 (별도 마무리 화면)

    private var interestStep: some View {
        VStack(spacing: DNASpacing.lg) {
            Spacer()
            VStack(spacing: 6) {
                Text("여행에서 가장 끌리는 걸\n3개 골라주세요")
                    .font(.title3.bold())
                    .foregroundStyle(Color.dnaTextPrimary)
                    .multilineTextAlignment(.center)
                Text("1개만 골라도 지문을 만들 수 있어요")
                    .font(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }

            DNAFlowLayout(spacing: 10) {
                ForEach(interestTagIDs, id: \.self) { tagID in
                    let isSelected = viewModel.selectedInterestTagIDs.contains(tagID)
                    let isLocked = !isSelected && viewModel.selectedInterestTagIDs.count >= 3
                    DNATagChip(title: TagCatalog.labelKo(for: tagID), isSelected: isSelected) {
                        viewModel.toggleInterestTag(tagID)
                    }
                    .disabled(isLocked)
                    .opacity(isLocked ? 0.35 : 1)
                }
            }
            .padding(.horizontal, DNASpacing.lg)

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.dnaError)
            }
            Spacer()
            DNABottomCTA {
                Button {
                    Task { await viewModel.finishQuiz(dependencies, session: session) }
                } label: {
                    if viewModel.isSubmitting {
                        ProgressView().tint(Color.dnaCanvas)
                    } else {
                        Text("내 지문 만들기")
                    }
                }
                .buttonStyle(.dnaPrimary(isDisabled: viewModel.selectedInterestTagIDs.isEmpty || viewModel.isSubmitting))
                .disabled(viewModel.selectedInterestTagIDs.isEmpty || viewModel.isSubmitting)
            }
        }
    }
}

#Preview("OnboardingQuizView") {
    let dependencies = AppDependencies()
    let session = SessionStore()
    return OnboardingQuizView(
        viewModel: OnboardingViewModel(),
        dependencies: dependencies,
        session: session
    )
    .environment(dependencies)
    .environment(session)
    .background(AppCanvas())
    .preferredColorScheme(.dark)
}

#Preview("OnboardingQuizView 관심사") {
    let dependencies = AppDependencies()
    let session = SessionStore()
    let viewModel = OnboardingViewModel()
    viewModel.quizQuestionIndex = viewModel.quizQuestions.count
    return OnboardingQuizView(
        viewModel: viewModel,
        dependencies: dependencies,
        session: session
    )
    .environment(dependencies)
    .environment(session)
    .background(AppCanvas())
    .preferredColorScheme(.dark)
}
