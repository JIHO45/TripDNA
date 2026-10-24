import SwiftUI

/// 여행 컨셉 선택: 큰 컨셉 1개를 2열 타일로, 함께한 컨셉(최대 2개)을 가로 칩 두 줄로 고른다.
/// 등록 카드와 평가의 컨셉 고치기가 같이 쓴다. 고르는 규칙은 호출하는 쪽의 클로저가 정한다.
struct TripConceptPicker: View {
    let primary: TripConcept?
    let secondary: [TripConcept]
    /// 부 컨셉 제목. 예정 여행은 "함께 하고 싶은 것", 다녀온 여행은 "함께 한 것".
    let secondaryTitle: String
    let onPrimary: (TripConcept) -> Void
    let onSecondary: (TripConcept) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: DNASpacing.xs), GridItem(.flexible())],
                spacing: DNASpacing.xs
            ) {
                ForEach(TripConcept.allCases, id: \.self) { concept in
                    tile(concept)
                }
            }

            if let primary {
                HStack {
                    Text(secondaryTitle)
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                    Spacer()
                    Text("최대 2개 · \(secondary.count)/2")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextTertiary)
                }
                let others = TripConcept.allCases.filter { $0 != primary }
                let half = (others.count + 1) / 2
                chipRow(Array(others.prefix(half)))
                chipRow(Array(others.dropFirst(half)))
            }
        }
    }

    private func tile(_ concept: TripConcept) -> some View {
        let isSelected = primary == concept
        return Button { onPrimary(concept) } label: {
            Text(concept.labelKo)
                .dnaFont(.cardTitle)
                .foregroundStyle(isSelected ? Color.dnaSelectedForeground : Color.dnaTextPrimary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    isSelected ? Color.dnaSelectedBackground : Color.dnaSurface1,
                    in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func chipRow(_ concepts: [TripConcept]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DNASpacing.xs) {
                ForEach(concepts, id: \.self) { concept in
                    let selected = secondary.contains(concept)
                    let locked = !selected && secondary.count >= 2
                    DNATagChip(title: concept.labelKo, isSelected: selected) { onSecondary(concept) }
                        .disabled(locked)
                        .opacity(locked ? 0.35 : 1)
                }
            }
        }
    }
}

/// 평가 화면의 "여행 컨셉 고치기" 시트. 고른 값은 바로 반영하고 닫으면 끝난다.
struct TripConceptEditSheet: View {
    @Binding var primary: TripConcept?
    @Binding var secondary: [TripConcept]
    let secondaryTitle: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                TripConceptPicker(
                    primary: primary,
                    secondary: secondary,
                    secondaryTitle: secondaryTitle,
                    onPrimary: { concept in
                        primary = concept
                        secondary.removeAll { $0 == concept }
                    },
                    onSecondary: { concept in
                        if let index = secondary.firstIndex(of: concept) {
                            secondary.remove(at: index)
                        } else if concept != primary, secondary.count < 2 {
                            secondary.append(concept)
                        }
                    }
                )
                .padding(DNASpacing.gutter)
            }
            .background(Color.dnaSheet)
            .navigationTitle("여행 컨셉")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

extension [TripConcept] {
    /// "도시 + 미식"처럼 주 컨셉을 앞세워 이어 붙인 한 줄.
    func joinedLabelKo() -> String { map(\.labelKo).joined(separator: " + ") }
}
