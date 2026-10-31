import Foundation
import UIKit

/// 하루 한 장·대표 사진을 앱 Documents에 JPEG로 보관한다.
/// UIImage 재인코딩으로 EXIF(위치 포함)를 제거한다.
enum LocalPhotoStore {
    static let pathPrefix = "local://photos/"

    static var directory: URL {
        AppStorageLocation.directory(.documentDirectory)
            .appendingPathComponent("DailyPhotos", isDirectory: true)
    }

    static func isLocalPhotoPath(_ storagePath: String) -> Bool {
        storagePath.hasPrefix(pathPrefix)
    }

    static func fileURL(for storagePath: String) -> URL? {
        guard isLocalPhotoPath(storagePath) else { return nil }
        let name = String(storagePath.dropFirst(pathPrefix.count))
        guard !name.isEmpty, !name.contains("/") else { return nil }
        return directory.appendingPathComponent(name)
    }

    static func image(at storagePath: String) -> UIImage? {
        guard let url = fileURL(for: storagePath) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    /// 원본 바이트를 리사이즈·재인코딩해 저장하고 `local://photos/{id}.jpg` 경로를 반환한다.
    @discardableResult
    static func saveImageData(_ data: Data, maxDimension: CGFloat = 1600) throws -> String {
        guard let image = UIImage(data: data) else {
            throw LocalPhotoStoreError.invalidImageData
        }
        return try saveImage(image, maxDimension: maxDimension)
    }

    @discardableResult
    static func saveImage(_ image: UIImage, maxDimension: CGFloat = 1600) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let resized = image.resized(maxDimension: maxDimension)
        guard let jpeg = resized.jpegData(compressionQuality: 0.82) else {
            throw LocalPhotoStoreError.encodingFailed
        }
        let fileName = "\(UUID().uuidString).jpg"
        let url = directory.appendingPathComponent(fileName)
        try jpeg.write(to: url, options: .atomic)
        return pathPrefix + fileName
    }

    static func deleteAll() throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.removeItem(at: directory)
    }

    static func delete(paths: [String]) throws {
        for path in Set(paths) {
            guard let url = fileURL(for: path), FileManager.default.fileExists(atPath: url.path) else { continue }
            try FileManager.default.removeItem(at: url)
        }
    }
}

enum LocalPhotoStoreError: LocalizedError {
    case invalidImageData
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImageData: String(localized: "Couldn't read the photo.")
        case .encodingFailed: String(localized: "Couldn't save the photo.")
        }
    }
}

private extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
