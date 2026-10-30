import CoreImage
import SwiftUI
import Vision
import XCTest
@testable import TripDNA

final class ShareCardRenderingTests: XCTestCase {
    @MainActor
    func testCardsRenderWithBrandAndRespectDestinationPrivacy() throws {
        let trip = try sampleTrip(city: "SECRET_CITY")
        let summary = TripShareSummary(trip: trip)
        let wrapped = try sampleWrapped()
        let cards: [(String, AnyView)] = [
            ("fingerprint", AnyView(FingerprintShareCard(fingerprint: try sampleFingerprint()))),
            ("trip-private", AnyView(TripShareCard(summary: summary, showsDestinationNames: false))),
            ("trip-public", AnyView(TripShareCard(summary: summary, showsDestinationNames: true))),
            ("wrapped-private", AnyView(WrappedShareCardView(wrapped: wrapped, showsDestinationNames: false))),
            ("wrapped-public", AnyView(WrappedShareCardView(wrapped: wrapped, showsDestinationNames: true)))
        ]
        for (name, card) in cards {
            let image = try XCTUnwrap(ShareCardRenderer.render(card), name)
            let cgImage = try XCTUnwrap(image.cgImage)
            XCTAssertEqual(cgImage.width, 1080)
            XCTAssertEqual(cgImage.height, 1350)
            let attachment = XCTAttachment(image: image)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ko-KR", "en-US"]
            try VNImageRequestHandler(cgImage: cgImage).perform([request])
            let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
            XCTAssertTrue(text.replacingOccurrences(of: " ", with: "").contains("TripDNA"), "\(name): \(text)")
            XCTAssertFalse(text.contains("PRIVATE_DATE"))
            XCTAssertFalse(text.contains("SECRET_CITY"))
            if name == "wrapped-private" { XCTAssertFalse(text.contains("일본")) }
            if name == "wrapped-public" { XCTAssertTrue(text.contains("일본")) }
            if name == "trip-private" { XCTAssertFalse(text.contains("일본")) }
            if name == "trip-public" { XCTAssertTrue(text.contains("일본")) }
        }
    }

    @MainActor
    func testInstallQRCodeEncodesShareURLOnEveryCard() throws {
        let url = try XCTUnwrap(URL(string: "https://tripdna.app/get"))
        let trip = try sampleTrip(city: nil)
        let wrapped = try sampleWrapped()
        let cards: [(String, AnyView)] = [
            ("fingerprint", AnyView(FingerprintShareCard(fingerprint: try sampleFingerprint(), installURL: url))),
            ("trip", AnyView(TripShareCard(summary: TripShareSummary(trip: trip), showsDestinationNames: false, installURL: url))),
            ("wrapped", AnyView(WrappedShareCardView(wrapped: wrapped, showsDestinationNames: false, installURL: url)))
        ]
        for (name, card) in cards {
            let cgImage = try XCTUnwrap(ShareCardRenderer.render(card)?.cgImage, name)
            XCTAssertEqual(try qrPayloads(in: cgImage), [url.absoluteString], name)
        }
    }

    @MainActor
    func testCardsOmitInstallBadgeWithoutShareURL() throws {
        let cgImage = try XCTUnwrap(ShareCardRenderer.render(
            FingerprintShareCard(fingerprint: try sampleFingerprint(), installURL: nil)
        )?.cgImage)
        XCTAssertEqual(try qrPayloads(in: cgImage), [])
    }

    // 도시·정확한 날짜가 카드에 새지 않는지 보려고 2026-05-10 ~ 14 일본 여행을 쓴다.
    private func sampleTrip(city: String?) throws -> Trip {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 10, hour: 12))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 5, day: 14, hour: 12))!
        var trip = try Trip(
            legs: [TripLeg(countryCode: "JP", cities: city.map { [$0] } ?? [], startDate: start, endDate: end)],
            companion: .alone, purpose: .leisure, concepts: TripConcepts(primary: .food)
        )
        try trip.start(at: start)
        try trip.end(at: end)
        return trip
    }

    private func sampleFingerprint() throws -> ConceptFingerprint {
        try XCTUnwrap(ConceptFingerprint(trips: [sampleTrip(city: nil)]))
    }

    private func sampleWrapped() throws -> WrappedYear {
        let calendar = Calendar(identifier: .gregorian)
        return WrappedYear.make(
            year: 2026, now: calendar.date(from: DateComponents(year: 2026, month: 12, day: 20))!,
            trips: [try sampleTrip(city: "SECRET_CITY")], ranking: nil, rankingReordered: false,
            photos: [], calendar: calendar
        )
    }

    /// Vision 바코드 인식은 시뮬레이터에서 추론 컨텍스트를 만들지 못하므로 CoreImage 감지기를 쓴다.
    private func qrPayloads(in image: CGImage) throws -> [String] {
        let detector = try XCTUnwrap(CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        ))
        return detector.features(in: CIImage(cgImage: image))
            .compactMap { ($0 as? CIQRCodeFeature)?.messageString }
    }
}
