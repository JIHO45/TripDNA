import Foundation
import Photos

/// 동의한 사용자에 한해 앱이 활성화될 때 비어 있는 여행 날짜를 한 장으로 채운다.
enum AutoPhotoFallbackService {
    static let consentKey = "tripdna.dailyPhotoAutoFallbackConsent"

    static func fillMissingDays(dependencies: AppDependencies) async {
        guard UserDefaults.standard.bool(forKey: consentKey),
              [.authorized, .limited].contains(PHPhotoLibrary.authorizationStatus(for: .readWrite)),
              let trips = try? await dependencies.store.trips() else { return }
        let calendar = Calendar.current
        for trip in trips where trip.status == .active {
            guard let start = trip.startedAt ?? trip.legs.first?.startDate else { continue }
            let count = min(30, max(0, calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: Date())
            ).day ?? 0) + 1)
            let existing = (try? await dependencies.store.photos(tripID: trip.id)) ?? []
            let occupied = Set(existing.map(\.tripDayIndex))
            for index in 1...count where !occupied.contains(index) {
                guard let day = calendar.date(byAdding: .day, value: index - 1, to: calendar.startOfDay(for: start)),
                      let end = calendar.date(byAdding: .day, value: 1, to: day),
                      let asset = candidate(from: day, to: end),
                      let data = try? await imageData(for: asset),
                      let path = try? LocalPhotoStore.saveImageData(data) else { continue }
                _ = try? await dependencies.dailyPhotoService.saveSelection(
                    tripID: trip.id,
                    tripDayIndex: index,
                    storagePath: path,
                    selection: .autoFallback,
                    reaction: nil
                )
            }
        }
    }

    private static func candidate(from start: Date, to end: Date) -> PHAsset? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType == %d AND creationDate >= %@ AND creationDate < %@",
            PHAssetMediaType.image.rawValue, start as NSDate, end as NSDate
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 20
        let assets = PHAsset.fetchAssets(with: options)
        var selected: PHAsset?
        assets.enumerateObjects { asset, _, stop in
            if selected == nil { selected = asset }
            if asset.isFavorite { selected = asset; stop.pointee = true }
        }
        return selected
    }

    private static func imageData(for asset: PHAsset) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.version = .current
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) {
                data, _, _, _ in
                if let data { continuation.resume(returning: data) }
                else { continuation.resume(throwing: LocalPhotoStoreError.invalidImageData) }
            }
        }
    }
}
