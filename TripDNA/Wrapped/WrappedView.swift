import SwiftUI

/// 연간 Wrapped 루트. 그해 여행이 없으면 추정으로 채우지 않고 빈 화면을 보여준다.
struct WrappedView: View {
    let year: Int
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = WrappedViewModel()
    @State private var showingRegistration = false

    var body: some View {
        Group {
            if let wrapped = viewModel.wrapped, !wrapped.isEmpty {
                WrappedStoryView(wrapped: wrapped, onClose: { dismiss() })
            } else if viewModel.isLoading {
                LoadingView()
            } else {
                emptyState
            }
        }
        .background(Color.dnaCanvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await viewModel.load(year: year, dependencies: dependencies) }
        .sheet(isPresented: $showingRegistration, onDismiss: {
            Task { await viewModel.load(year: year, dependencies: dependencies) }
        }) {
            NavigationStack { TripRegistrationView(prefilledCountryCode: nil) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DNASpacing.sm) {
            Spacer()
            Text("No trips registered\nfor \(WrappedYear.yearText(year))")
                .dnaFont(.screenTitle)
                .foregroundStyle(Color.dnaTextPrimary)
                .multilineTextAlignment(.center)
            Text("Register a trip you took this year and your Wrapped will be made.")
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            DNABottomCTA {
                Button("Register a Trip") { showingRegistration = true }
                    .buttonStyle(.dnaPrimary)
                Button("Close") { dismiss() }
                    .buttonStyle(.dnaGhost)
            }
        }
        .padding(.horizontal, DNASpacing.lg)
    }
}

#Preview("WrappedView") {
    NavigationStack {
        WrappedView(year: Calendar.current.component(.year, from: Date()))
    }
    .previewWithAppEnvironment()
}
