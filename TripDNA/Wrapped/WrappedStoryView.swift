import SwiftUI

/// 풀스크린 스토리. 오른쪽 탭/왼쪽으로 스와이프=다음, 왼쪽 탭/오른쪽으로 스와이프=이전.
/// 카드 목록은 `WrappedYear.cards`가 정한다(②는 랭킹을 직접 바꿨을 때만 등).
struct WrappedStoryView: View {
    let wrapped: WrappedYear
    let onClose: () -> Void

    @State private var index = 0
    @State private var showingShare = false

    private var cards: [WrappedYear.Card] { wrapped.cards }
    private var card: WrappedYear.Card { cards[min(index, cards.count - 1)] }
    private var isLight: Bool { card == .concepts }
    private var foreground: Color { isLight ? Color.dnaTextPrimary : Color.white }

    var body: some View {
        ZStack {
            // 배경만 안전 영역 밖까지 편다. 글자와 버튼은 안쪽에 둔다.
            background.ignoresSafeArea()
            content
                .id(index)
                .transition(.opacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, DNASpacing.lg)
                .padding(.top, 96)
                .padding(.bottom, 56)
                .allowsHitTesting(card == .finish)
            tapZones
            VStack(spacing: DNASpacing.sm) {
                progressBar
                topRow
                Spacer()
            }
            .padding(.horizontal, DNASpacing.lg)
            .padding(.top, DNASpacing.xs)
        }
        .foregroundStyle(foreground)
        .gesture(DragGesture(minimumDistance: 30).onEnded { value in
            if value.translation.width < -40 { advance() } else if value.translation.width > 40 { goBack() }
        })
        .sheet(isPresented: $showingShare) {
            ShareCardSheet(
                kind: .wrapped,
                title: String(localized: "Share Preview"),
                disclosure: String(localized: "Included: trip count, most-taken concept · Left out: dates, cities, companions, photos"),
                allowsDestinationNames: true
            ) { showsDestinationNames in
                WrappedShareCardView(wrapped: wrapped, showsDestinationNames: showsDestinationNames)
            }
        }
    }

    // MARK: 배경

    @ViewBuilder
    private var background: some View {
        switch card {
        case .movement: Color.dnaInk
        case .topConcept: Color(hex: 0x0F7B73)
        case .concepts: Color.dnaSurface1
        case .photos: Color(hex: 0x141414)
        case .finish: Color.dnaAction
        case .topTrip:
            ZStack {
                Color(hex: 0x0F7B73)
                if let path = wrapped.topTrip?.coverPath, LocalPhotoStore.image(at: path) != nil {
                    // 채우기 사진이 원래 폭으로 화면을 넓히지 않게 빈 면 위에 얹는다.
                    Color.clear.overlay { TripPhotoImage(storagePath: path) }.clipped()
                }
                LinearGradient(colors: [.black.opacity(0.15), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
            }
        }
    }

    // MARK: 상단

    private var progressBar: some View {
        HStack(spacing: 5) {
            ForEach(cards.indices, id: \.self) { segment in
                Capsule()
                    .fill(foreground.opacity(segment <= index ? 1 : 0.25))
                    .frame(height: 3)
            }
        }
        .accessibilityHidden(true)
    }

    private var topRow: some View {
        HStack {
            Text(yearLabel)
                .dnaFont(size: 15, weight: .bold)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .dnaFont(size: 15, weight: .bold)
                    .frame(width: 36, height: 36)
                    .background(foreground.opacity(0.18), in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .accessibilityLabel("Close")
        }
    }

    private var yearLabel: String {
        let year = WrappedYear.yearText(wrapped.year)
        guard wrapped.isInProgress else { return year }
        return String(localized: "\(year) · through \(Date().formatted(.dateTime.month().day()))")
    }

    // MARK: 카드

    @ViewBuilder
    private var content: some View {
        switch card {
        case .movement: movement
        case .topTrip: topTrip
        case .topConcept: topConcept
        case .concepts: concepts
        case .photos: photos
        case .finish: finish
        }
    }

    private func kicker(_ text: String) -> some View {
        Text(text).dnaFont(size: 15, weight: .heavy).opacity(0.85)
    }

    private func bigText(_ text: String, size: CGFloat = 56) -> some View {
        Text(text)
            .dnaFont(size: size, weight: .heavy)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func footnote(_ text: String) -> some View {
        Text(text).dnaFont(.caption).opacity(0.75).fixedSize(horizontal: false, vertical: true)
    }

    // ① 올해의 이동
    private var movement: some View {
        VStack(alignment: .leading, spacing: DNASpacing.xs) {
            Spacer().frame(height: 80)
            kicker(wrapped.periodKo)
            bigText(String(localized: "You took\n\(wrapped.tripCount) trips"))
            Text("\(wrapped.countryCount) countries · \(wrapped.cityCount) cities")
                .dnaFont(size: 17, weight: .bold)
                .opacity(0.9)
                .padding(.top, 8)
            Spacer()
            HStack(spacing: 6) {
                ForEach(Array(wrapped.rows.prefix(6))) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        Color.clear
                            .frame(height: 64)
                            .overlay { TripPhotoImage(storagePath: row.coverPath ?? "") }
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Text(WrappedYear.monthLabel(row.month)).dnaFont(size: 11).opacity(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            footnote(String(localized: "Only confirmed visits are counted · Business trips are not included in trip totals"))
        }
    }

    // ② 올해의 1위 여행
    private var topTrip: some View {
        VStack(alignment: .leading, spacing: DNASpacing.xs) {
            Spacer()
            kicker(String(localized: "\(wrapped.yearWordKo)'s top trip").capitalizingFirst)
            bigText(wrapped.topTrip?.place ?? "", size: 44)
            Text(wrapped.topTrip?.detail ?? "").dnaFont(size: 15, weight: .bold).opacity(0.9)
            footnote(String(localized: "The trip you placed at the top of your Trips tab ranking for \(wrapped.yearWordKo)")).padding(.top, DNASpacing.sm)
        }
    }

    // ③ 올해 가장 많이 떠난 여행
    private var topConcept: some View {
        VStack(alignment: .leading, spacing: DNASpacing.xs) {
            Spacer().frame(height: 80)
            kicker(wrapped.topConceptEyebrowKo)
            bigText(wrapped.topConceptBigKo)
            Text(wrapped.topConceptCaptionKo).dnaFont(size: 17, weight: .bold).opacity(0.9)
            Spacer()
            if !wrapped.isSingleTrip, let fingerprint = wrapped.fingerprint {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(fingerprint.entries.prefix(4), id: \.concept) { entry in
                        HStack(spacing: 10) {
                            Text(entry.concept.label)
                                .dnaFont(size: 13, weight: .bold)
                                // 영어 한 단어("Socializing")가 한 줄에 들어가는 폭. 64면 "Relaxatio/n"처럼 끊긴다.
                                .frame(width: 84, alignment: .leading)
                            ForEach(0..<min(entry.count, 6), id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(fingerprint.top.contains(entry.concept) ? 1 : 0.45))
                                    .frame(width: 40, height: 40)
                            }
                        }
                    }
                }
                .accessibilityHidden(true)
            }
            footnote(wrapped.isSingleTrip
                ? String(localized: "With just one trip for \(wrapped.yearWordKo), there are no rankings or comparisons")
                : String(localized: "Counted from the main concept you chose for each trip · Not a personality test"))
        }
    }

    // ④ 여행마다 고른 컨셉
    private var concepts: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            Spacer().frame(height: 8)
            Text(String(localized: "\(wrapped.yearWordKo)'s trips").capitalizingFirst).dnaFont(size: 30, weight: .heavy)
            // ponytail: 여덟 번째 이후 여행은 줄이지 않고 자른다. 스크롤을 넣으려면 탭 이동과 제스처를 나눠야 한다.
            VStack(spacing: 10) {
                    ForEach(wrapped.rows.prefix(8)) { row in
                        HStack(spacing: 12) {
                            TripPhotoImage(storagePath: row.coverPath ?? "")
                                .frame(width: 48, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(WrappedYear.monthLabel(row.month)).dnaFont(.caption).foregroundStyle(Color.dnaTextSecondary)
                                Text(row.place).dnaFont(.sectionTitle)
                            }
                            Spacer(minLength: 0)
                            Text(row.concept?.label ?? String(localized: "Not chosen"))
                                .dnaFont(.caption)
                                .padding(.horizontal, 10)
                                .frame(minHeight: 28)
                                .foregroundStyle(row.concept == nil ? Color.dnaTextSecondary : Color.dnaSelectedForeground)
                                .background(row.concept == nil ? Color.dnaSurface2 : Color.dnaSelectedBackground, in: Capsule())
                        }
                        .padding(10)
                        .background(Color.dnaRaised, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
                    }
            }
            Text("Trips without a concept show as \"Not chosen\"")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
        }
    }

    // ⑤ 올해의 한 장
    private var photos: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            Spacer().frame(height: 8)
            Text(wrapped.photos.isEmpty ? String(localized: "No daily photo yet\nfor \(wrapped.yearWordKo)") : String(localized: "\(wrapped.photos.count) moments saved\nas daily photos"))
                .dnaFont(size: 30, weight: .heavy)
            if !wrapped.photos.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                    ForEach(wrapped.photos.prefix(12)) { photo in
                        Color.clear
                            .aspectRatio(3.0 / 4.0, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .overlay { TripPhotoImage(storagePath: photo.storagePath) }
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
            Spacer()
            footnote(String(localized: "These photos only appear on this screen. They aren't included in the share card."))
        }
    }

    // ⑥ 마무리
    private var finish: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            Spacer().frame(height: 40)
            Text(wrapped.isInProgress ? String(localized: "Your travel record\nso far this year") : String(localized: "Your travel record\nfor \(wrapped.periodKo)"))
                .dnaFont(size: 30, weight: .heavy)
            VStack(alignment: .leading, spacing: 10) {
                summaryLine(String(localized: "Trips"), String(localized: "\(wrapped.tripCount) total"))
                summaryLine(String(localized: "Countries"), String(localized: "\(wrapped.countryCount) visited"))
                if let fingerprint = wrapped.fingerprint, !wrapped.isSingleTrip {
                    summaryLine(fingerprint.isTie ? String(localized: "Tied for most") : String(localized: "Most-taken trip type"), fingerprint.topCountedKo ?? fingerprint.top.map(\.label).joined(separator: " · "))
                }
                if let topTrip = wrapped.topTrip {
                    summaryLine(String(localized: "Top trip"), topTrip.place)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            Spacer()
            Button {
                showingShare = true
            } label: {
                Text("Create Share Card")
                    .dnaFont(.button)
                    .foregroundStyle(Color.dnaInk)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
            }
            .accessibilityIdentifier("wrapped.sharePreview")
            Button("Start Over") {
                withAnimation(.easeOut(duration: 0.3)) { index = 0 }
            }
            .dnaFont(.button)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func summaryLine(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).dnaFont(size: 14, weight: .medium).opacity(0.85)
            Spacer(minLength: DNASpacing.sm)
            Text(value).dnaFont(size: 15, weight: .heavy).multilineTextAlignment(.trailing)
        }
    }

    // MARK: 이동

    /// 마지막 카드에서는 버튼을 가리지 않도록 왼쪽 가장자리만 이전 탭으로 쓴다.
    private var tapZones: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                Color.clear.contentShape(Rectangle()).onTapGesture(perform: goBack)
                    .frame(width: proxy.size.width * (card == .finish ? 0.12 : 0.35))
                if card == .finish {
                    Spacer(minLength: 0)
                } else {
                    Color.clear.contentShape(Rectangle()).onTapGesture(perform: advance)
                }
            }
            .padding(.top, 110)
        }
    }

    private func advance() {
        guard index < cards.count - 1 else { return }
        withAnimation(.easeOut(duration: 0.3)) { index += 1 }
    }

    private func goBack() {
        guard index > 0 else { return }
        withAnimation(.easeOut(duration: 0.3)) { index -= 1 }
    }
}
