import CoreImage
import SwiftUI
import Vision
import XCTest
@testable import TripDNA

final class ShareCardRenderingTests: XCTestCase {
    @MainActor
    func testCardsRenderWithBrandAndRespectDestinationPrivacy() throws {
        let axes = TasteAxes(natureUrban: -0.5, energyLevel: 0.4, planningStyle: -0.3, socialMode: 0.6, noveltyAppetite: 0.2)
        let confidence = TasteAxes(natureUrban: 0.8, energyLevel: 0.8, planningStyle: 0.8, socialMode: 0.8, noveltyAppetite: 0.8)
        let date = Date(timeIntervalSince1970: 1_780_000_000)
        let trip = try Trip(legs: [TripLeg(countryCode: "JP", cities: ["SECRET_CITY"], startDate: date, endDate: date)], companion: .alone, purpose: .leisure)
        let summary = TripShareSummary(trip: trip)
        let wrapped = WrappedDisplayModel(
            year: 2026, tripCount: 3, destinationCount: 4, cards: [],
            topTripTitle: "PRIVATE_DESTINATION", topTripDateRange: "PRIVATE_DATE",
            strongestAxis: .natureUrban, isStrongestAxisConditional: false,
            topTagLabels: ["미식 탐험", "자연 풍경", "문화 체험"], axes: axes, confidence: confidence,
            isLowConfidence: false, annualPhotos: []
        )
        let cards: [(String, AnyView)] = [
            ("fingerprint", AnyView(FingerprintShareCard(axes: axes, confidence: confidence))),
            ("trip-private", AnyView(TripShareCard(summary: summary, showsDestinationNames: false))),
            ("trip-public", AnyView(TripShareCard(summary: summary, showsDestinationNames: true))),
            ("wrapped-private", AnyView(WrappedShareCardView(display: wrapped, showsDestinationNames: false))),
            ("wrapped-public", AnyView(WrappedShareCardView(display: wrapped, showsDestinationNames: true)))
        ]
        for (name, card) in cards {
            let image = try XCTUnwrap(ShareCardRenderer.render(card), name)
            let cgImage = try XCTUnwrap(image.cgImage)
            XCTAssertEqual(cgImage.width, 1080)
            XCTAssertEqual(cgImage.height, 1920)
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
            if name == "wrapped-private" { XCTAssertFalse(text.contains("PRIVATE_DESTINATION")) }
            if name == "wrapped-public" { XCTAssertTrue(text.contains("PRIVATE_DESTINATION")) }
            if name == "trip-private" { XCTAssertFalse(text.contains("일본")) }
            if name == "trip-public" { XCTAssertTrue(text.contains("일본")) }
        }
    }

    @MainActor
    func testInstallQRCodeEncodesShareURLOnEveryCard() throws {
        let url = try XCTUnwrap(URL(string: "https://tripdna.app/get"))
        let axes = TasteAxes(natureUrban: -0.5, energyLevel: 0.4, planningStyle: -0.3, socialMode: 0.6, noveltyAppetite: 0.2)
        let date = Date(timeIntervalSince1970: 1_780_000_000)
        let trip = try Trip(legs: [TripLeg(countryCode: "JP", cities: [], startDate: date, endDate: date)], companion: .alone, purpose: .leisure)
        let wrapped = WrappedDisplayModel(
            year: 2026, tripCount: 1, destinationCount: 1, cards: [],
            topTripTitle: "일본", topTripDateRange: "",
            strongestAxis: .natureUrban, isStrongestAxisConditional: false,
            topTagLabels: [], axes: axes, confidence: axes,
            isLowConfidence: false, annualPhotos: []
        )
        let cards: [(String, AnyView)] = [
            ("fingerprint", AnyView(FingerprintShareCard(axes: axes, confidence: axes, installURL: url))),
            ("trip", AnyView(TripShareCard(summary: TripShareSummary(trip: trip), showsDestinationNames: false, installURL: url))),
            ("wrapped", AnyView(WrappedShareCardView(display: wrapped, showsDestinationNames: false, installURL: url)))
        ]
        for (name, card) in cards {
            let cgImage = try XCTUnwrap(ShareCardRenderer.render(card)?.cgImage, name)
            XCTAssertEqual(try qrPayloads(in: cgImage), [url.absoluteString], name)
        }
    }

    @MainActor
    func testCardsOmitInstallBadgeWithoutShareURL() throws {
        let axes = TasteAxes(natureUrban: 0.1, energyLevel: 0.1, planningStyle: 0.1, socialMode: 0.1, noveltyAppetite: 0.1)
        let cgImage = try XCTUnwrap(ShareCardRenderer.render(
            FingerprintShareCard(axes: axes, confidence: axes, installURL: nil)
        )?.cgImage)
        XCTAssertEqual(try qrPayloads(in: cgImage), [])
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
