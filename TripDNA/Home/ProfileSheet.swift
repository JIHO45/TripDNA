import SwiftUI

/// 홈 상단 프로필 메뉴. 거주 국가 변경과 계정·데이터 삭제를 제공한다.
struct ProfileSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var showingHomeCountryPicker = false
    @State private var showingDeleteDialog = false
    @State private var isDeletingAccount = false
    @State private var deletionError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("계정") {
                    LabeledContent("사용자 ID", value: String(session.userID.prefix(8)))
                        .foregroundStyle(.white)
                }
                .listRowBackground(Color.dnaSurface1)

                Section {
                    Button {
                        showingHomeCountryPicker = true
                    } label: {
                        LabeledContent(
                            "거주 국가",
                            value: dependencies.homeCountryCode.map { CountryCatalog.name(for: $0) } ?? "설정 안 됨"
                        )
                    }
                    .foregroundStyle(.white)
                } footer: {
                    Text("거주 국가는 여행지 추천에서 기본으로 제외돼요. 추천 조건에서 포함할 수 있어요.")
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                .listRowBackground(Color.dnaSurface1)

                Section {
                    Button(role: .destructive) {
                        showingDeleteDialog = true
                    } label: {
                        Text("계정 및 데이터 삭제")
                    }
                    .disabled(isDeletingAccount)
                } footer: {
                    Text("기기에 저장된 여행·지문·추천 기록과 사진을 삭제해요. 다른 기기에서 복구할 수 없어요.")
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                .listRowBackground(Color.dnaSurface1)
            }
            .scrollContentBackground(.hidden)
            .background(AppCanvas())
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .sheet(isPresented: $showingHomeCountryPicker) {
                HomeCountryPickerSheet()
            }
            .confirmationDialog(
                "계정과 모든 데이터를 삭제할까요?",
                isPresented: $showingDeleteDialog,
                titleVisibility: .visible
            ) {
                Button("모두 삭제", role: .destructive) {
                    Task {
                        isDeletingAccount = true
                        defer { isDeletingAccount = false }
                        do {
                            try await dependencies.deleteAccount(session: session)
                            dismiss()
                        } catch {
                            deletionError = error.localizedDescription
                        }
                    }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("기기에 저장된 여행·평가·지문·추천 반응·사진이 영구 삭제돼요.")
            }
            .alert("삭제를 완료하지 못했어요", isPresented: Binding(
                get: { deletionError != nil },
                set: { if !$0 { deletionError = nil } }
            )) {
                Button("확인", role: .cancel) { deletionError = nil }
            } message: {
                Text(deletionError ?? "다시 시도해 주세요.")
            }
        }
    }
}

private struct HomeCountryPickerSheet: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCode: String

    init() {
        _selectedCode = State(initialValue: "KR")
    }

    var body: some View {
        NavigationStack {
            CountrySelectionList(selectedCode: $selectedCode)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("저장") {
                            Task {
                                await dependencies.setHomeCountryCode(selectedCode)
                                dismiss()
                            }
                        }
                    }
                }
        }
        .task {
            selectedCode = dependencies.homeCountryCode ?? Locale.current.region?.identifier.uppercased() ?? "KR"
        }
    }
}

#Preview("ProfileSheet") {
    ProfileSheet()
        .previewWithAppEnvironment()
}
