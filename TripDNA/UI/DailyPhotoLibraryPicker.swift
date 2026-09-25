import Photos
import PhotosUI
import SwiftUI
import UIKit

/// UI-7: 해당 날짜에 찍은 사진을 보여 주고, 유저가 한 장을 고른다. 자동 선정은 하지 않는다.
struct DailyPhotoLibraryPicker: View {
    /// 후보를 이 날짜(로컬 자정 기준)로 한정한다. `nil`이면 최근 사진 전체.
    var day: Date? = Calendar.current.startOfDay(for: Date())
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
        guard let day else { return "사진" }
        if Calendar.current.isDateInToday(day) { return "오늘" }
        if Calendar.current.isDateInYesterday(day) { return "어제" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        return formatter.string(from: day)
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
        .task(id: day?.timeIntervalSince1970) {
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
            DNATrustPanel(text: "\(dayLabel) 찍은 사진에서 한 장만 고를 수 있도록 사진 접근이 필요해요. 사진은 기기 안에서만 처리돼요.")
                .padding(.horizontal, DNASpacing.lg)
            Spacer(minLength: DNASpacing.lg)
            DNABottomCTA {
                Button {
                    Task { await requestAccess() }
                } label: {
                    Text("사진 접근 허용")
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
            Label("사진 접근이 꺼져 있어요", systemImage: "photo.badge.exclamationmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text("설정에서 허용하면 \(dayLabel) 찍은 사진을 고를 수 있어요. 지금은 건너뛰어도 괜찮아요.")
                .font(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("설정 열기", destination: url)
                    .font(.subheadline.weight(.semibold))
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
                .tint(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DNASpacing.xl)
        } else if assets.isEmpty {
            emptyTodayCard
        } else {
            if filtersToSingleDay {
                Text("\(dayLabel) 찍은 사진")
                    .font(.caption.weight(.semibold))
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
                        .tint(.white)
                        .padding(16)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }

            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                Label("사진첩에서 더 보기", systemImage: "photo.on.rectangle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dnaData)
            }
            .disabled(isImporting)
        }
    }

    private var emptyTodayCard: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            Text(filtersToSingleDay ? "\(dayLabel) 찍은 사진이 없어요" : "고를 수 있는 사진이 없어요")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text("건너뛰거나, 사진첩에서 다른 사진을 고를 수 있어요.")
                .font(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                Text("사진첩에서 고르기")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
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
        assets = await Task.detached(priority: .userInitiated) {
            Self.fetchAssets(day: day)
        }.value
    }

    nonisolated private static func fetchAssets(day: Date?) -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = day == nil ? 60 : 120
        if let day {
            let start = Calendar.current.startOfDay(for: day)
            guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else {
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
            collected.append(asset)
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
            errorMessage = "사진을 불러오지 못했어요. 다시 시도해 주세요."
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
                errorMessage = "사진을 불러오지 못했어요. 다시 시도해 주세요."
                return
            }
            let path = try LocalPhotoStore.saveImageData(data)
            onSelect(path)
        } catch {
            errorMessage = "사진을 불러오지 못했어요. 다시 시도해 주세요."
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
                    ProgressView().tint(.white)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: DNARadius.control - 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DNARadius.control - 4, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
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
                    ProgressView().tint(.white)
                }
                Text(isImporting ? "불러오는 중…" : title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Capsule().fill(Color.white.opacity(0.1)))
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
