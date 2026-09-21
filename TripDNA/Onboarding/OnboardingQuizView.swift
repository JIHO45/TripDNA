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
                Text("부족한 취향만 확인하고 있어요")
                    .font(.caption)
                    .foregroundStyle(Color.dnaTeal)
                    .padding(.top, DNASpacing.sm)
            }

            if let question = viewModel.currentQuizQuestion {
                questionView(question)
                    .id(question.id)
                    .transition(transition(for: question))
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
                .foregroundStyle(.white)
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
                Button(QuizQuestionCatalog.escapeText) {
                    skipCurrentQuestion()
                }
                .buttonStyle(.dnaGhost)
            }
        }
    }

    /// 탭 즉시 글로우 피드백을 주고 0.3초 뒤 자동으로 다음 문항으로 넘어간다.
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
        if !viewModel.goBackInQuiz() {
            viewModel.goBack()
        }
    }

    // MARK: 관심사 (별도 마무리 화면)

    private var interestStep: some View {
        VStack(spacing: DNASpacing.lg) {
            Spacer()
            VStack(spacing: 6) {
                Text("여행에서 가장 끌리는 걸\n3개 골라주세요")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("1개만 골라도 지문을 만들 수 있어요")
                    .font(.caption)
                    .foregroundStyle(Color.dnaSlate)
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
                    .foregroundStyle(Color.dnaCoral)
            }
            Spacer()
            DNABottomCTA {
                Button {
                    Task { await viewModel.finishQuiz(dependencies, session: session) }
                } label: {
                    if viewModel.isSubmitting {
                        ProgressView().tint(.white)
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
    .background(AuroraBackground())
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
    .background(AuroraBackground())
    .preferredColorScheme(.dark)
}
