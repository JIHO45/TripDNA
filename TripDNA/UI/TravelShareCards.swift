import SwiftUI

/// 공유 카드에는 공개를 허용한 요약만 전달하며 원본 여행의 날짜·사진을 그리지 않는다.
struct TripShareSummary {
    let destinationNames: String
    let satisfaction: Int?
    let rank: Int?
    let positiveTags: [String]

    init(trip: Trip) {
        destinationNames = trip.titleKo
        satisfaction = trip.evaluation?.satisfaction
        rank = trip.rankPosition
        positiveTags = Array((trip.evaluation?.positiveTagIDs ?? []).prefix(3)).map(TagCatalog.labelKo(for:))
    }

    func title(showsDestinationNames: Bool) -> String {
        showsDestinationNames ? destinationNames : "나의 여행 기록"
    }
}

struct TravelShareCardFrame<Content: View>: View {
    let eyebrow: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 22) {
            Text(eyebrow)
                .font(.caption.weight(.medium))
                .tracking(2)
                .foregroundStyle(Color.dnaTeal)
                .padding(.top, 28)
            content
            Spacer(minLength: 0)
            Label("TripDNA", systemImage: "touchid")
                .font(.subheadline.weight(.semibold))
            Text("여행이 만드는 나만의 지문")
                .font(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(Color.white)
        .background {
            ZStack {
                Color.dnaCanvas
                LinearGradient(colors: [Color.dnaIndigo.opacity(0.3), .clear, Color.dnaTeal.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }
}

struct FingerprintShareCard: View {
    let axes: TasteAxes
    let confidence: AxisConfidence

    var body: some View {
        TravelShareCardFrame(eyebrow: "MY TRAVEL FINGERPRINT") {
            Text("나의 여행 지문")
                .font(.largeTitle.weight(.regular))
            FingerprintRadarView(axes: axes, confidence: confidence)
                .frame(width: 290, height: 240)
            Text(AxisNarrative.representativeSentenceKo(axes: axes, confidence: confidence))
                .font(.title2.weight(.medium))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct TripShareCard: View {
    let summary: TripShareSummary
    let showsDestinationNames: Bool

    var body: some View {
        TravelShareCardFrame(eyebrow: "MY TRAVEL JOURNAL") {
            Image(systemName: "suitcase.rolling")
                .font(.system(size: 64, weight: .ultraLight))
                .padding(.vertical, 22)
                .foregroundStyle(Color.dnaTeal)
            Text(summary.title(showsDestinationNames: showsDestinationNames))
                .font(.largeTitle.weight(.regular))
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.6)
            if let satisfaction = summary.satisfaction {
                Text("만족도 \(satisfaction) / 5")
                    .font(.title2)
            }
            if let rank = summary.rank {
                Text("내 여행 랭킹 \(rank)위")
                    .font(.headline)
                    .foregroundStyle(Color.dnaAmber)
            }
            VStack(spacing: 8) {
                ForEach(Array(summary.positiveTags.enumerated()), id: \.offset) { _, label in
                    Text("#\(label)").font(.subheadline)
                }
            }
        }
    }
}
