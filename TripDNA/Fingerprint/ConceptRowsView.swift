import SwiftUI

/// 컨셉마다 한 줄, 여행 하나가 칸 하나. 1위는 dnaData, 다음은 dnaDataMuted, 그 아래는 dnaDataFaint.
/// 숫자를 막대 길이로 바꾸지 않고 여행이 쌓이는 모양으로 그려서 한두 건이어도 어색하지 않다.
struct ConceptBlockRows: View {
    let fingerprint: ConceptFingerprint
    var maxRows = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(fingerprint.entries.prefix(maxRows).enumerated()), id: \.element.concept) { rank, entry in
                HStack(spacing: DNASpacing.sm) {
                    Text(entry.concept.labelKo)
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextPrimary)
                        .frame(width: 72, alignment: .leading)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        ForEach(0..<min(entry.count, 10), id: \.self) { _ in
                            RoundedRectangle(cornerRadius: DNARadius.cell, style: .continuous)
                                .fill(Self.color(rank: rank))
                                .frame(width: 22, height: 22)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(entry.concept.labelKo) \(entry.count)번")
            }
        }
    }

    static func color(rank: Int) -> Color {
        switch rank {
        case 0: .dnaData
        case 1: .dnaDataMuted
        default: .dnaDataFaint
        }
    }
}
