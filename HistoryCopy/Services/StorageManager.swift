import Foundation
import SwiftData
import AppKit

@MainActor
final class StorageManager {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init(container: ModelContainer? = nil) {
        if let container {
            self.container = container
        } else {
            let schema = Schema([ClipboardItem.self])
            let config = ModelConfiguration("HistoryCopyStore", groupContainer: .none)
            do {
                self.container = try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }

    func fetchPinnedItems() -> [ClipboardItem] {
        var descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.isPinned == true }
        )
        descriptor.sortBy = [SortDescriptor(\ClipboardItem.timestamp, order: .reverse)]
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchItems(searchText: String = "") -> [ClipboardItem] {
        var descriptor: FetchDescriptor<ClipboardItem>
        let sortBy = [SortDescriptor(\ClipboardItem.timestamp, order: .reverse)]
        if searchText.isEmpty {
            descriptor = FetchDescriptor<ClipboardItem>(sortBy: sortBy)
        } else {
            descriptor = FetchDescriptor<ClipboardItem>(
                predicate: #Predicate { $0.textContent?.localizedStandardContains(searchText) == true },
                sortBy: sortBy
            )
        }
        let items = (try? context.fetch(descriptor)) ?? []
        return items.filter { !$0.isPinned }
    }

    func togglePin(_ item: ClipboardItem) {
        item.isPinned.toggle()
        try? context.save()
    }

    func deleteItem(_ item: ClipboardItem) {
        if item.type == .image, let url = item.imageFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        context.delete(item)
        try? context.save()
    }

    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .text:
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .image:
            if let url = item.imageFileURL, let image = NSImage(contentsOf: url) {
                pasteboard.writeObjects([image])
            }
        }
    }

    func fetchAllItems() -> [ClipboardItem] {
        var descriptor = FetchDescriptor<ClipboardItem>()
        descriptor.sortBy = [SortDescriptor(\ClipboardItem.timestamp, order: .reverse)]
        return (try? context.fetch(descriptor)) ?? []
    }

    func cleanupExpired() {
        let retentionDays = UserDefaults.standard.integer(forKey: "retentionDays")
        guard retentionDays > 0 else { return }

        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.isPinned == false && $0.timestamp < cutoff }
        )
        guard let expired = try? context.fetch(descriptor) else { return }

        for item in expired {
            if item.type == .image, let url = item.imageFileURL {
                try? FileManager.default.removeItem(at: url)
            }
            context.delete(item)
        }
        try? context.save()
    }
}
