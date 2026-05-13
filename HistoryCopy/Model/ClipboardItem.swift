import Foundation
import SwiftData
import AppKit

enum ContentType: Int, Codable {
    case text = 0
    case image = 1
}

@Model
final class ClipboardItem {
    var id: UUID
    var contentType: Int
    var textContent: String?
    var imageFileName: String?
    var imageHash: String?
    var timestamp: Date
    var isPinned: Bool
    var sourceAppBundleId: String?

    var type: ContentType {
        ContentType(rawValue: contentType) ?? .text
    }

    var imageFileURL: URL? {
        guard let fileName = imageFileName else { return nil }
        return ClipboardItem.imageDirectory.appendingPathComponent(fileName)
    }

    static var imageDirectory: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("HistoryCopy/Images")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    init(
        id: UUID = UUID(),
        contentType: ContentType,
        textContent: String? = nil,
        imageFileName: String? = nil,
        imageHash: String? = nil,
        timestamp: Date = Date(),
        isPinned: Bool = false,
        sourceAppBundleId: String? = nil
    ) {
        self.id = id
        self.contentType = contentType.rawValue
        self.textContent = textContent
        self.imageFileName = imageFileName
        self.imageHash = imageHash
        self.timestamp = timestamp
        self.isPinned = isPinned
        self.sourceAppBundleId = sourceAppBundleId
    }
}
