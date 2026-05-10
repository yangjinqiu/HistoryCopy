import Foundation
import AppKit
import SwiftData

@MainActor
final class ClipboardMonitor: ObservableObject {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let pasteboard = NSPasteboard.general
    private var modelContext: ModelContext?

    func start(context: ModelContext) {
        self.modelContext = context
        lastChangeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPasteboard()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
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

    func cleanupExpired(context: ModelContext) {
        let retentionDays = UserDefaults.standard.integer(forKey: "retentionDays")
        guard retentionDays > 0 else { return }

        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        let fetchDescriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.isPinned == false && $0.timestamp < cutoff }
        )
        guard let expired = try? context.fetch(fetchDescriptor) else { return }

        for item in expired {
            if item.type == .image, let url = item.imageFileURL {
                try? FileManager.default.removeItem(at: url)
            }
            context.delete(item)
        }
        try? context.save()
    }
}
