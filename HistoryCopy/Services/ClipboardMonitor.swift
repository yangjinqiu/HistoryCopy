import Foundation
import AppKit
import SwiftData
import CryptoKit

@MainActor
final class ClipboardMonitor: ObservableObject {
    private var timer: Timer?
    private var cleanupTimer: Timer?
    private var lastChangeCount: Int = 0
    private let pasteboard = NSPasteboard.general
    private var modelContext: ModelContext?
    private weak var storageManager: StorageManager?

    func start(context: ModelContext, storageManager: StorageManager? = nil) {
        self.modelContext = context
        self.storageManager = storageManager
        lastChangeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPasteboard()
            }
        }
        // Periodic expired-item cleanup (every 10 minutes)
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.storageManager?.cleanupExpired()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }

    private func checkPasteboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        guard let context = modelContext else { return }

        // Try text first
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            addTextItem(text, context: context)
            return
        }

        // Try image
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            addImageItem(image, context: context)
            return
        }
    }

    private func addTextItem(_ text: String, context: ModelContext) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Deduplicate: if same as latest text item, just bump timestamp
        let fetchDescriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\ClipboardItem.timestamp, order: .reverse)]
        )
        if let latest = try? context.fetch(fetchDescriptor).first,
           latest.type == .text,
           latest.textContent == trimmed {
            latest.timestamp = Date()
            latest.sourceAppBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            try? context.save()
            return
        }

        let item = ClipboardItem(
            contentType: .text,
            textContent: trimmed,
            sourceAppBundleId: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        )
        context.insert(item)
        try? context.save()
        enforceLimit(context: context)
    }

    private func addImageItem(_ image: NSImage, context: ModelContext) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return }

        let hash = SHA256.hash(data: pngData).compactMap { String(format: "%02x", $0) }.joined()

        // Deduplicate: if same as latest image item, just bump timestamp
        let fetchDescriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\ClipboardItem.timestamp, order: .reverse)]
        )
        if let latest = try? context.fetch(fetchDescriptor).first,
           latest.type == .image,
           latest.imageHash == hash {
            latest.timestamp = Date()
            latest.sourceAppBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            try? context.save()
            return
        }

        let fileName = "\(UUID().uuidString).png"
        let fileURL = ClipboardItem.imageDirectory.appendingPathComponent(fileName)

        do {
            try pngData.write(to: fileURL)
        } catch {
            return
        }

        let item = ClipboardItem(
            contentType: .image,
            imageFileName: fileName,
            imageHash: hash,
            sourceAppBundleId: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        )
        context.insert(item)
        try? context.save()
        enforceLimit(context: context)
    }

    private func enforceLimit(context: ModelContext) {
        let fetchDescriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\ClipboardItem.timestamp, order: .reverse)]
        )
        guard let allItems = try? context.fetch(fetchDescriptor) else { return }

        let maxCount = UserDefaults.standard.integer(forKey: "maxItemCount")
        let limit = maxCount > 0 ? maxCount : 1000

        let unpinnedToDelete = allItems
            .filter { !$0.isPinned }
            .dropFirst(limit)

        for item in unpinnedToDelete {
            if item.type == .image, let url = item.imageFileURL {
                try? FileManager.default.removeItem(at: url)
            }
            context.delete(item)
        }
        if !unpinnedToDelete.isEmpty {
            try? context.save()
        }
    }

}
