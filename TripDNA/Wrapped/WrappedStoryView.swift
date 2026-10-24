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
            background
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
                title: "공유 미리보기",
                disclosure: "포함: 여행 수, 가장 많이 떠난 컨셉 · 빠짐: 날짜, 도시, 동행, 사진",
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
                    TripPhotoImage(storagePath: path)
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
                .dnaFont(.caption)
                .opacity(0.8)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .dnaFont(size: 15, weight: .bold)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .accessibilityLabel("닫기")
        }
    }

    private var yearLabel: String {
        guard wrapped.isInProgress else { return "\(wrapped.year)년" }
        let parts = Calendar.current.dateComponents([.month, .day], from: Date())
        return "\(wrapped.year)년 · \(parts.month ?? 12)월 \(parts.day ?? 1)일까지"
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
            bigText("\(wrapped.tripCount)번\n떠났어요")
            Text("나라 \(wrapped.countryCount)곳 · 도시 \(wrapped.cityCount)곳")
                .dnaFont(size: 17, weight: .bold)
                .opacity(0.9)
                .padding(.top, 8)
            Spacer()
            HStack(spacing: 6) {
                ForEach(Array(wrapped.rows.prefix(6))) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        TripPhotoImage(storagePath: row.coverPath ?? "")
                            .frame(height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Text("\(row.month)월").dnaFont(size: 11).opacity(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            footnote("확인된 방문지만 셌어요 · 출장은 여행 수에 넣지 않았어요")
        }
    }

    // ② 올해의 1위 여행
    private var topTrip: some View {
        VStack(alignment: .leading, spacing: DNASpacing.xs) {
            Spacer()
            kicker("올해의 1위 여행")
            bigText(wrapped.topTrip?.place ?? "", size: 44)
            Text(wrapped.topTrip?.detail ?? "").dnaFont(size: 15, weight: .bold).opacity(0.9)
            footnote("여행 탭 랭킹에서 올해 여행 중 가장 위에 둔 여행이에요").padding(.top, DNASpacing.sm)
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
                            Text(entry.concept.labelKo)
                                .dnaFont(size: 13, weight: .bold)
                                .frame(width: 64, alignment: .leading)
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
            footnote("여행마다 고른 주 컨셉을 센 거예요 · 성격 진단이 아니에요")
        }
    }

    // ④ 여행마다 고른 컨셉
    private var concepts: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            Spacer().frame(height: 8)
            Text("올해의 여행들").dnaFont(size: 30, weight: .heavy)
            // ponytail: 여덟 번째 이후 여행은 줄이지 않고 자른다. 스크롤을 넣으려면 탭 이동과 제스처를 나눠야 한다.
            VStack(spacing: 10) {
                    ForEach(wrapped.rows.prefix(8)) { row in
                        HStack(spacing: 12) {
                            TripPhotoImage(storagePath: row.coverPath ?? "")
                                .frame(width: 48, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(row.month)월").dnaFont(.caption).foregroundStyle(Color.dnaTextSecondary)
                                Text(row.place).dnaFont(.sectionTitle)
                            }
                            Spacer(minLength: 0)
                            Text(row.concept?.labelKo ?? "고르지 않음")
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
            Text("컨셉을 안 고른 여행은 \"고르지 않음\"으로 보여요")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
        }
    }

    // ⑤ 올해의 한 장
    private var photos: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            Spacer().frame(height: 8)
            Text(wrapped.photos.isEmpty ? "올해 남긴 한 장이\n아직 없어요" : "하루 한 장으로\n남긴 \(wrapped.photos.count)개의 순간")
                .dnaFont(size: 30, weight: .heavy)
            if !wrapped.photos.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                    ForEach(wrapped.photos.prefix(12)) { photo in
                        TripPhotoImage(storagePath: photo.storagePath)
                            .aspectRatio(3.0 / 4.0, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
            Spacer()
            footnote("이 사진들은 이 화면에서만 보여요. 공유 카드에는 들어가지 않아요.")
        }
    }

    // ⑥ 마무리
    private var finish: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            Spacer().frame(height: 40)
            Text("\(wrapped.periodKo)의\n여행 기록")
                .dnaFont(size: 30, weight: .heavy)
            VStack(alignment: .leading, spacing: 10) {
                summaryLine("여행", "\(wrapped.tripCount)번")
                summaryLine("나라", "\(wrapped.countryCount)곳")
                if let fingerprint = wrapped.fingerprint, !wrapped.isSingleTrip {
                    summaryLine(fingerprint.isTie ? "같이 많이" : "가장 많이 떠난 여행", fingerprint.top.map(\.labelKo).joined(separator: " · "))
                }
                if let topTrip = wrapped.topTrip {
                    summaryLine("1위 여행", topTrip.place)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            Spacer()
            Button {
                showingShare = true
            } label: {
                Text("공유 카드 만들기")
                    .dnaFont(.button)
                    .foregroundStyle(Color.dnaAction)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
            }
            .accessibilityIdentifier("wrapped.sharePreview")
            Button("처음부터 보기") {
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
