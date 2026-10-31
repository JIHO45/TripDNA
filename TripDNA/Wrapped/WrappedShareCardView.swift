import SwiftUI

/// 저장·공유용 Wrapped 카드. 하루 한 장 사진·도시·정확한 날짜는 넣지 않는다.
/// 나라 이름은 `showsDestinationNames`가 켜졌을 때만 넣는다.
struct WrappedShareCardView: View {
    let wrapped: WrappedYear
    var showsDestinationNames: Bool
    var installURL: URL? = ShareDestination.url

    var body: some View {
        TravelShareCardFrame(background: Color.dnaAction, kicker: wrapped.periodKo, installURL: installURL) {
            Text(wrapped.isSingleTrip ? String(localized: "You took one trip") : String(localized: "You took \(wrapped.tripCount) trips"))
                .font(.system(size: 46, weight: .heavy))
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 18) {
                line(String(localized: "Countries"), showsDestinationNames ? ShareText.list(wrapped.countryNames) : String(localized: "\(wrapped.countryCount) visited"))
                // 한 번뿐인 해에는 "가장 많이"를 말하지 않는다.
                if let fingerprint = wrapped.fingerprint, !wrapped.isSingleTrip {
                    line(fingerprint.isTie ? String(localized: "Tied for most") : String(localized: "Most often"), fingerprint.topCountedKo ?? ShareText.list(fingerprint.top.map(\.label)))
                }
                if let topTrip = wrapped.topTrip {
                    let value = [showsDestinationNames ? topTrip.countriesKo : nil, topTrip.conceptKo.map(ShareText.keepTogether)]
                        .compactMap { $0 }.joined(separator: ", ")
                    line(String(localized: "Top trip"), value.isEmpty ? String(localized: "Country names hidden") : value)
                }
            }
        }
    }

    private func line(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title).font(.system(size: 17)).opacity(0.85)
            Spacer(minLength: 8)
            Text(value).font(.system(size: 20, weight: .heavy)).multilineTextAlignment(.trailing)
        }
    }
}
