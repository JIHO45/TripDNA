import SwiftUI

/// 저장·공유용 Wrapped 카드. 하루 한 장 사진·도시·정확한 날짜는 넣지 않는다.
/// 나라 이름은 `showsDestinationNames`가 켜졌을 때만 넣는다.
struct WrappedShareCardView: View {
    let wrapped: WrappedYear
    var showsDestinationNames: Bool
    var installURL: URL? = ShareDestination.url

    var body: some View {
        TravelShareCardFrame(background: Color.dnaAction, installURL: installURL) {
            Text(wrapped.periodKo)
                .font(.system(size: 14, weight: .heavy))
                .opacity(0.85)
            Text(wrapped.isSingleTrip ? "한 번 떠났어요" : "\(wrapped.tripCount)번 떠났어요")
                .font(.system(size: 38, weight: .heavy))
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) {
                line("나라", showsDestinationNames ? wrapped.countryNames.joined(separator: " · ") : "\(wrapped.countryCount)곳")
                // 한 번뿐인 해에는 "가장 많이"를 말하지 않는다.
                if let fingerprint = wrapped.fingerprint, !wrapped.isSingleTrip {
                    line(fingerprint.isTie ? "같이 많이" : "가장 많이", fingerprint.top.map(\.labelKo).joined(separator: " · "))
                }
                if let topTrip = wrapped.topTrip {
                    let value = [showsDestinationNames ? topTrip.countriesKo : nil, topTrip.conceptKo].compactMap { $0 }.joined(separator: " · ")
                    line("1위 여행", value.isEmpty ? "나라 이름 숨김" : value)
                }
            }
        }
    }

    private func line(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title).font(.system(size: 15)).opacity(0.85)
            Spacer(minLength: 8)
            Text(value).font(.system(size: 16, weight: .heavy)).multilineTextAlignment(.trailing)
        }
    }
}
