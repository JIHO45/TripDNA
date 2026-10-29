import SafariServices
import SwiftUI

/// 여행·추천 상세가 함께 쓰는 액티비티 링크 섹션.
/// 앱 안의 웹 브라우저로 연다. 이후 파트너 페이지의 리다이렉트와 예약 귀속은
/// 파트너 앱이 설치된 실기기에서 별도로 검증해야 한다.
struct AffiliateActivitySection: View {
    let title: String
    let links: [AffiliateActivityLink]

    @Environment(AppDependencies.self) private var dependencies
    @State private var selectedLink: AffiliateActivityLink?

    var body: some View {
        if !links.isEmpty {
            section
        }
    }

    private var section: some View {
        SectionCard(title: title) {
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                disclosure

                ForEach(links) { link in
                    Button {
                        selectedLink = link
                        Task {
                            try? await dependencies.affiliateLinkService.recordClick(link)
                        }
                    } label: {
                        HStack(spacing: DNASpacing.sm) {
                            Image(systemName: link.category.systemImage)
                                .dnaFont(.sectionTitle)
                                .foregroundStyle(Color.dnaData)
                                .frame(width: 38, height: 38)
                                .background(Color.dnaData.opacity(0.12), in: Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(link.city) · \(link.category.labelKo)")
                                    .dnaFont(.cardTitle)
                                    .foregroundStyle(Color.dnaTextPrimary)
                                Text("\(link.providerName) 웹에서 보기")
                                    .dnaFont(.caption)
                                    .foregroundStyle(Color.dnaTextSecondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right")
                                .dnaFont(.caption)
                                .foregroundStyle(Color.dnaData)
                        }
                        .padding(DNASpacing.sm)
                        .background(Color.dnaTextPrimary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.dnaDivider, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("외부 예약 웹 페이지를 앱 안의 브라우저로 엽니다")
                }
            }
        }
        .sheet(item: $selectedLink) { link in
            AffiliateBrowserView(url: link.url)
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var disclosure: some View {
        if links.first?.isAffiliateActive == true {
            Label {
                Text("이 링크로 예약하면 TripDNA가 수수료를 제공받습니다.")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "info.circle.fill")
            }
            .dnaFont(.caption)
            .foregroundStyle(Color.dnaTextPrimary)
        } else {
            Label {
                Text("현재는 제휴 연결 전 테스트 링크예요. 예약 수수료는 발생하지 않습니다.")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "hammer.fill")
            }
            .dnaFont(.caption)
            .foregroundStyle(Color.dnaWarning)
        }
    }
}

private struct AffiliateBrowserView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        configuration.barCollapsingEnabled = true
        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.preferredControlTintColor = UIColor(Color.dnaData)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
