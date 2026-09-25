import CoreImage.CIFilterBuiltins
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

/// 공유 이미지에 넣는 설치 경로. Info.plist의 `TripDNAShareURL`이 비어 있으면 그리지 않는다.
enum ShareDestination {
    static var url: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "TripDNAShareURL") as? String,
              !raw.isEmpty else { return nil }
        return URL(string: raw)
    }
}

/// 공유 이미지를 본 사람이 앱을 찾아올 수 있게 QR과 짧은 주소를 함께 둔다.
struct ShareInstallBadge: View {
    let url: URL

    var body: some View {
        HStack(spacing: 12) {
            if let qr = Self.qrImage(for: url.absoluteString) {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 60, height: 60)
                    .padding(5)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("내 여행 지문 만들기")
                    .font(.caption.weight(.semibold))
                Text(displayText)
                    .font(.caption2)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
        }
    }

    private var displayText: String {
        let host = url.host() ?? url.absoluteString
        let path = url.path()
        return path.isEmpty || path == "/" ? host : host + path
    }

    static func qrImage(for message: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(message.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

struct TravelShareCardFrame<Content: View>: View {
    let eyebrow: String
    var installURL: URL?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 22) {
            Text(eyebrow)
                .font(.caption.weight(.medium))
                .tracking(0.5)
                .foregroundStyle(Color.dnaData)
                .padding(.top, 28)
            content
            Spacer(minLength: 0)
            Label("TripDNA", systemImage: "touchid")
                .font(.subheadline.weight(.semibold))
            Text("여행이 만드는 나만의 지문")
                .font(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
            if let installURL {
                ShareInstallBadge(url: installURL)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(Color.white)
        .background {
            ZStack {
                Color.dnaCanvas
                LinearGradient(colors: [Color.dnaTextTertiary.opacity(0.3), .clear, Color.dnaData.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }
}

struct FingerprintShareCard: View {
    let axes: TasteAxes
    let confidence: AxisConfidence
    var installURL: URL? = ShareDestination.url

    var body: some View {
        TravelShareCardFrame(eyebrow: "나의 여행 지문", installURL: installURL) {
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
    var installURL: URL? = ShareDestination.url

    var body: some View {
        TravelShareCardFrame(eyebrow: "나의 여행 기록", installURL: installURL) {
            Image(systemName: "suitcase.rolling")
                .font(.system(size: 64, weight: .ultraLight))
                .padding(.vertical, 22)
                .foregroundStyle(Color.dnaData)
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
                    .foregroundStyle(Color.dnaWarning)
            }
            VStack(spacing: 8) {
                ForEach(Array(summary.positiveTags.enumerated()), id: \.offset) { _, label in
                    Text("#\(label)").font(.subheadline)
                }
            }
        }
    }
}
