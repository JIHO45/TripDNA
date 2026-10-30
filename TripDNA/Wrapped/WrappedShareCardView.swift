import SwiftUI

/// 저장·공유용 Wrapped 카드. 하루 한 장 사진·도시·정확한 날짜는 넣지 않는다.
/// 나라 이름은 `showsDestinationNames`가 켜졌을 때만 넣는다.
struct WrappedShareCardView: View {
    let wrapped: WrappedYear
    var showsDestinationNames: Bool
    var installURL: URL? = ShareDestination.url

    var body: some View {
        TravelShareCardFrame(background: Color.dnaAction, kicker: wrapped.periodKo, installURL: installURL) {
            Text(wrapped.isSingleTrip ? "한 번 떠났어요" : "\(wrapped.tripCount)번 떠났어요")
                .font(.system(size: 46, weight: .heavy))
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 18) {
                line("나라", showsDestinationNames ? ShareText.list(wrapped.countryNames) : "\(wrapped.countryCount)곳")
                // 한 번뿐인 해에는 "가장 많이"를 말하지 않는다.
                if let fingerprint = wrapped.fingerprint, !wrapped.isSingleTrip {
                    line(fingerprint.isTie ? "같이 많이" : "가장 많이", ShareText.list(fingerprint.top.map(\.labelKo)))
                }
                if let topTrip = wrapped.topTrip {
                    let value = [showsDestinationNames ? topTrip.countriesKo : nil, topTrip.conceptKo.map(ShareText.keepTogether)]
                        .compactMap { $0 }.joined(separator: ", ")
                    line("1위 여행", value.isEmpty ? "나라 이름 숨김" : value)
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
