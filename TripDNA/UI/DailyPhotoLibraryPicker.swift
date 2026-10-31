import Photos
import PhotosUI
import SwiftUI
import UIKit

/// UI-7: 해당 날짜에 찍은 사진을 보여 주고, 유저가 한 장을 고른다. 자동 선정은 하지 않는다.
struct DailyPhotoLibraryPicker: View {
    /// 후보를 이 날짜(로컬 자정 기준)로 한정한다. `nil`이면 최근 사진 전체.
    var day: Date? = Calendar.current.startOfDay(for: Date())
    /// 있으면 `day`부터 이 날까지(여행 기간) 위치 정보가 있는 사진만 촬영순으로 보여준다. 스크린샷 등을 거르기 위해서다.
    var lastDay: Date? = nil
    /// 저장 완료된 `local://photos/...` 경로를 넘긴다.
    let onSelect: (String) -> Void

    @State private var authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var assets: [PHAsset] = []
    @State private var isLoading = false
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var pickerItem: PhotosPickerItem?

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 6)
    ]

    private var filtersToSingleDay: Bool { day != nil }

    private var dayLabel: String {
        guard let day else { return String(localized: "on this device") }
        if lastDay != nil { return String(localized: "during your trip") }
        if Calendar.current.isDateInToday(day) { return String(localized: "today") }
        if Calendar.current.isDateInYesterday(day) { return String(localized: "yesterday") }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return String(localized: "on \(formatter.string(from: day))")
    }

    var body: some View {
        Group {
            switch authorization {
            case .notDetermined:
                primingLayout
            case .denied, .restricted:
                deniedLayout
            case .authorized, .limited:
                libraryLayout
            @unknown default:
                deniedLayout
            }
        }
        .task(id: [day, lastDay].map { $0?.timeIntervalSince1970 }) {
            if authorization == .authorized || authorization == .limited {
                await reloadAssets()
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await importPickerItem(item) }
        }
    }

    // MARK: - 권한

    private var primingLayout: some View {
        VStack(spacing: 0) {
            DNATrustPanel(text: String(localized: "Photo access is needed so you can pick one photo taken \(dayLabel). Photos are processed only on your device."))
                .padding(.horizontal, DNASpacing.lg)
            Spacer(minLength: DNASpacing.lg)
            DNABottomCTA {
                Button {
                    Task { await requestAccess() }
                } label: {
                    Text("Allow Photo Access")
                }
                .buttonStyle(.dnaPrimary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var deniedLayout: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            deniedCard
                .padding(.horizontal, DNASpacing.lg)
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.dnaAction)
                    .padding(.horizontal, DNASpacing.lg)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var libraryLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                libraryContent
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Color.dnaAction)
                }
            }
            .padding(.horizontal, DNASpacing.lg)
            .padding(.bottom, DNASpacing.md)
        }
    }

    private var deniedCard: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            Label("Photo access is off", systemImage: "photo.badge.exclamationmark")
                .dnaFont(.cardTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            Text("Allow access in Settings to pick a photo taken \(dayLabel). It's fine to skip for now.")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url)
                    .dnaFont(.cardTitle)
                    .foregroundStyle(Color.dnaData)
            }
        }
        .padding(DNASpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .fill(Color.dnaSurface1)
        )
    }

    // MARK: - 그리드

    @ViewBuilder
    private var libraryContent: some View {
        if isLoading && assets.isEmpty {
            ProgressView()
                .tint(Color.dnaTextSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DNASpacing.xl)
        } else if assets.isEmpty {
            emptyTodayCard
        } else {
            if filtersToSingleDay {
                Text("Photos taken \(dayLabel)")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(assets, id: \.localIdentifier) { asset in
                    DailyPhotoAssetCell(asset: asset, isBusy: isImporting) {
                        Task { await importAsset(asset) }
                    }
                }
            }
            .disabled(isImporting)
            .overlay {
                if isImporting {
                    ProgressView()
                        .tint(Color.dnaTextSecondary)
                        .padding(16)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }

            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                Label("See More in Photos", systemImage: "photo.on.rectangle")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaData)
            }
            .disabled(isImporting)
        }
    }

    private var emptyTodayCard: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            Text(filtersToSingleDay ? String(localized: "No photos taken \(dayLabel)") : String(localized: "No photos to choose from"))
                .dnaFont(.cardTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            Text("Skip, or pick a different photo from your library.")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                Text("Choose from Library")
                    .dnaFont(.cardTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Capsule().fill(Color.dnaSurface2))
            }
            .disabled(isImporting)
        }
        .padding(DNASpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .fill(Color.dnaSurface1)
        )
    }

    // MARK: - Actions

    @MainActor
    private func requestAccess() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorization = status
        if status == .authorized || status == .limited {
            await reloadAssets()
        }
    }

    @MainActor
    private func reloadAssets() async {
        isLoading = true
        defer { isLoading = false }
        let day = self.day
        let lastDay = self.lastDay
        assets = await Task.detached(priority: .userInitiated) {
            Self.fetchAssets(day: day, lastDay: lastDay)
        }.value
    }

    nonisolated private static func fetchAssets(day: Date?, lastDay: Date?) -> [PHAsset] {
        let options = PHFetchOptions()
        // ponytail: 여행 기간은 앞에서 300장까지만 본다. 나머지는 "사진첩에서 더 보기"로 고른다.
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: lastDay != nil)]
        options.fetchLimit = day == nil ? 60 : (lastDay == nil ? 120 : 300)
        if let day {
            let start = Calendar.current.startOfDay(for: day)
            guard let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: lastDay ?? day)) else {
                return []
            }
            options.predicate = NSPredicate(
                format: "mediaType == %d AND creationDate >= %@ AND creationDate < %@",
                PHAssetMediaType.image.rawValue,
                start as NSDate,
                end as NSDate
            )
        } else {
            options.predicate = NSPredicate(
                format: "mediaType == %d",
                PHAssetMediaType.image.rawValue
            )
        }
        let result = PHAsset.fetchAssets(with: options)
        var collected: [PHAsset] = []
        collected.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            if lastDay == nil || asset.location != nil { collected.append(asset) }
        }
        return collected
    }

    @MainActor
    private func importAsset(_ asset: PHAsset) async {
        guard !isImporting else { return }
        isImporting = true
        errorMessage = nil
        defer { isImporting = false }

        do {
            let data = try await Self.requestImageData(for: asset)
            let path = try LocalPhotoStore.saveImageData(data)
            onSelect(path)
        } catch {
            errorMessage = String(localized: "Couldn't load the photo. Please try again.")
        }
    }

    @MainActor
    private func importPickerItem(_ item: PhotosPickerItem) async {
        guard !isImporting else { return }
        isImporting = true
        errorMessage = nil
        defer {
            isImporting = false
            pickerItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = String(localized: "Couldn't load the photo. Please try again.")
                return
            }
            let path = try LocalPhotoStore.saveImageData(data)
            onSelect(path)
        } catch {
            errorMessage = String(localized: "Couldn't load the photo. Please try again.")
        }
    }

    private static func requestImageData(for asset: PHAsset) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, info in
                if let data {
                    continuation.resume(returning: data)
                    return
                }
                let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                if cancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    continuation.resume(throwing: LocalPhotoStoreError.invalidImageData)
                }
            }
        }
    }
}

// MARK: - Cell

private struct DailyPhotoAssetCell: View {
    let asset: PHAsset
    let isBusy: Bool
    let onTap: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.dnaSurface1
                    ProgressView().tint(Color.dnaTextSecondary)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: DNARadius.control - 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DNARadius.control - 4, style: .continuous)
                    .strokeBorder(Color.dnaDivider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .task(id: asset.localIdentifier) {
            thumbnail = await Self.loadThumbnail(for: asset)
        }
    }

    private static func loadThumbnail(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            let size = CGSize(width: 240, height: 240)
            var hasResumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: image)
            }
        }
    }
}

/// 대표 사진 등 날짜 제한 없이 한 장을 고를 때 쓰는 PhotosPicker 래퍼.
struct AnyPhotoLibraryPickerButton: View {
    let title: String
    let onSelect: (String) -> Void

    @State private var item: PhotosPickerItem?
    @State private var isImporting = false

    var body: some View {
        PhotosPicker(selection: $item, matching: .images, photoLibrary: .shared()) {
            HStack {
                if isImporting {
                    ProgressView().tint(Color.dnaTextSecondary)
                }
                Text(isImporting ? String(localized: "Loading…") : title)
                    .dnaFont(.cardTitle)
            }
            .foregroundStyle(Color.dnaTextPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Capsule().fill(Color.dnaSurface2))
        }
        .disabled(isImporting)
        .onChange(of: item) { _, newItem in
            guard let newItem else { return }
            Task {
                isImporting = true
                defer {
                    isImporting = false
                    item = nil
                }
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let path = try? LocalPhotoStore.saveImageData(data) {
                    onSelect(path)
                }
            }
        }
    }
}
