import CoreImage.CIFilterBuiltins
import SwiftUI

/// 공유 이미지는 날짜·도시·동행·개인 사진을 넣지 않는다. 나라 이름은 사용자가 켰을 때만 넣는다.
struct TripShareSummary {
    let year: Int
    let conceptKo: String?
    let durationKo: String
    let rank: Int?
    let countriesKo: String

    init(trip: Trip) {
        year = trip.legs.first.map { Calendar.current.component(.year, from: $0.startDate) } ?? 0
        conceptKo = trip.concepts?.primary.labelKo
        durationKo = trip.durationKo
        rank = trip.rankPosition
        countriesKo = trip.titleKo
    }

    var titleKo: String { conceptKo.map { "\($0) 여행" } ?? "나의 여행" }
}

/// 공유 이미지에 넣는 설치 경로. Info.plist의 `TripDNAShareURL`이 비어 있으면 그리지 않는다(없는 주소를 만들지 않는다).
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
                    // QR은 어두운 배경에서 읽히지 않으므로 흰 여백이 필요하다.
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("내 여행 지문 만들기")
                    .font(.system(size: 12, weight: .heavy))
                Text(displayText)
                    .font(.system(size: 11))
                    .opacity(0.8)
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

/// 세 공유 카드의 공통 틀. 배경색은 카드마다 정하고, 글씨는 흰색이다(색 배경 위라서 흰색을 쓴다).
/// 이미지로 굳으므로 글자 크기는 고정한다.
struct TravelShareCardFrame<Content: View>: View {
    let background: Color
    var installURL: URL?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            content
            Spacer(minLength: 0)
            HStack(alignment: .bottom) {
                Text("TripDNA")
                    .font(.system(size: 15, weight: .heavy))
                Spacer()
                if let installURL {
                    ShareInstallBadge(url: installURL)
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(Color.white)
        .background(background)
    }
}

/// 공유 카드 안의 작은 소제목.
private func shareEyebrow(_ text: String) -> some View {
    Text(text).font(.system(size: 14, weight: .heavy)).opacity(0.8)
}

struct FingerprintShareCard: View {
    let fingerprint: ConceptFingerprint
    var installURL: URL? = ShareDestination.url

    var body: some View {
        TravelShareCardFrame(background: Color(hex: 0x222222), installURL: installURL) {
            shareEyebrow("내 여행 지문 · 여행 \(fingerprint.total)번")
            Text(headline)
                .font(.system(size: 34, weight: .heavy))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(fingerprint.entries.prefix(5), id: \.concept) { entry in
                    HStack(spacing: 6) {
                        Text(entry.concept.labelKo)
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 84, alignment: .leading)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        ForEach(0..<min(entry.count, 8), id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(fingerprint.top.contains(entry.concept) ? Color.dnaAction : Color.white)
                                .frame(width: 24, height: 24)
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private var headline: String {
        if fingerprint.isSingleTrip { return "첫 기록은\n\(fingerprint.topNamesKo) 여행" }
        if fingerprint.isTie { return "\(fingerprint.topNamesKo) 여행을\n\(fingerprint.topCount)번씩 떠났어요" }
        return "가장 많이 떠난 건\n\(fingerprint.topNamesKo) 여행"
    }
}

struct TripShareCard: View {
    let summary: TripShareSummary
    let showsDestinationNames: Bool
    var installURL: URL? = ShareDestination.url

    var body: some View {
        TravelShareCardFrame(background: Color(hex: 0x0F7B73), installURL: installURL) {
            shareEyebrow(summary.year > 0 ? "\(String(summary.year))년의 여행" : "나의 여행")
            Text("\(summary.titleKo)\n\(summary.durationKo)")
                .font(.system(size: 38, weight: .heavy))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            if let rank = summary.rank {
                Text("내 랭킹 \(rank)위")
                    .font(.system(size: 17, weight: .bold))
                    .opacity(0.9)
            }
            Text(showsDestinationNames ? summary.countriesKo : "나라 이름 숨김")
                .font(.system(size: showsDestinationNames ? 20 : 13, weight: showsDestinationNames ? .heavy : .medium))
                .multilineTextAlignment(.center)
                .opacity(showsDestinationNames ? 1 : 0.8)
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
