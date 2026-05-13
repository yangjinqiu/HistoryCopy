import XCTest
import SwiftData
@testable import HistoryCopy

@MainActor
final class StorageManagerTests: XCTestCase {
    private var storage: StorageManager!
    private var container: ModelContainer!

    override func setUp() {
        super.setUp()
        let schema = Schema([ClipboardItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        storage = StorageManager(container: container)
    }

    override func tearDown() {
        storage = nil
        container = nil
        super.tearDown()
    }

    // MARK: - fetchPinnedItems

    func test_fetchPinnedItems_returnsOnlyPinned() {
        let pinned = ClipboardItem(contentType: .text, textContent: "pinned", isPinned: true)
        let unpinned = ClipboardItem(contentType: .text, textContent: "unpinned")
        container.mainContext.insert(pinned)
        container.mainContext.insert(unpinned)
        try? container.mainContext.save()

        let result = storage.fetchPinnedItems()
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.textContent, "pinned")
    }

    func test_fetchPinnedItems_emptyWhenNonePinned() {
        let item = ClipboardItem(contentType: .text, textContent: "hello")
        container.mainContext.insert(item)
        try? container.mainContext.save()

        XCTAssertTrue(storage.fetchPinnedItems().isEmpty)
    }

    func test_fetchPinnedItems_sortedByTimestampDesc() {
        let older = ClipboardItem(contentType: .text, textContent: "older", timestamp: Date(timeIntervalSinceNow: -100), isPinned: true)
        let newer = ClipboardItem(contentType: .text, textContent: "newer", timestamp: Date(), isPinned: true)
        container.mainContext.insert(older)
        container.mainContext.insert(newer)
        try? container.mainContext.save()

        let result = storage.fetchPinnedItems()
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].textContent, "newer")
        XCTAssertEqual(result[1].textContent, "older")
    }

    // MARK: - fetchItems

    func test_fetchItems_excludesPinnedItems() {
        let pinned = ClipboardItem(contentType: .text, textContent: "pinned", isPinned: true)
        let regular = ClipboardItem(contentType: .text, textContent: "regular")
        container.mainContext.insert(pinned)
        container.mainContext.insert(regular)
        try? container.mainContext.save()

        let result = storage.fetchItems()
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.textContent, "regular")
    }

    func test_fetchItems_sortedByTimestampDesc() {
        let older = ClipboardItem(contentType: .text, textContent: "older", timestamp: Date(timeIntervalSinceNow: -100))
        let newer = ClipboardItem(contentType: .text, textContent: "newer", timestamp: Date())
        container.mainContext.insert(older)
        container.mainContext.insert(newer)
        try? container.mainContext.save()

        let result = storage.fetchItems()
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].textContent, "newer")
        XCTAssertEqual(result[1].textContent, "older")
    }

    func test_fetchItems_withSearchText() {
        let apple = ClipboardItem(contentType: .text, textContent: "Apple pie recipe")
        let banana = ClipboardItem(contentType: .text, textContent: "Banana bread")
        let orange = ClipboardItem(contentType: .text, textContent: "Orange juice")
        container.mainContext.insert(apple)
        container.mainContext.insert(banana)
        container.mainContext.insert(orange)
        try? container.mainContext.save()

        let result = storage.fetchItems(searchText: "apple")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.textContent, "Apple pie recipe")
    }

    func test_fetchItems_searchIsCaseInsensitive() {
        let item = ClipboardItem(contentType: .text, textContent: "Hello World")
        container.mainContext.insert(item)
        try? container.mainContext.save()

        XCTAssertEqual(storage.fetchItems(searchText: "hello").count, 1)
        XCTAssertEqual(storage.fetchItems(searchText: "WORLD").count, 1)
        XCTAssertEqual(storage.fetchItems(searchText: "xyz").count, 0)
    }

    func test_fetchItems_searchEmptyText_returnsAllUnpinned() {
        for i in 0..<3 {
            container.mainContext.insert(ClipboardItem(contentType: .text, textContent: "item\(i)"))
        }
        try? container.mainContext.save()
        XCTAssertEqual(storage.fetchItems(searchText: "").count, 3)
    }

    // MARK: - fetchAllItems

    func test_fetchAllItems_includesPinnedAndUnpinned() {
        container.mainContext.insert(ClipboardItem(contentType: .text, textContent: "pinned", isPinned: true))
        container.mainContext.insert(ClipboardItem(contentType: .text, textContent: "unpinned"))
        try? container.mainContext.save()

        let result = storage.fetchAllItems()
        XCTAssertEqual(result.count, 2)
    }

    func test_fetchAllItems_emptyWhenNoItems() {
        XCTAssertTrue(storage.fetchAllItems().isEmpty)
    }

    // MARK: - togglePin

    func test_togglePin_flipsFromFalseToTrue() {
        let item = ClipboardItem(contentType: .text, textContent: "test")
        container.mainContext.insert(item)
        try? container.mainContext.save()

        XCTAssertFalse(item.isPinned)
        storage.togglePin(item)
        // Refresh from context
        let fetched = storage.fetchAllItems().first!
        XCTAssertTrue(fetched.isPinned)
    }

    func test_togglePin_flipsFromTrueToFalse() {
        let item = ClipboardItem(contentType: .text, textContent: "test", isPinned: true)
        container.mainContext.insert(item)
        try? container.mainContext.save()

        storage.togglePin(item)
        let fetched = storage.fetchAllItems().first!
        XCTAssertFalse(fetched.isPinned)
    }

    // MARK: - deleteItem

    func test_deleteItem_removesFromStore() {
        let item = ClipboardItem(contentType: .text, textContent: "to delete")
        container.mainContext.insert(item)
        try? container.mainContext.save()

        storage.deleteItem(item)
        XCTAssertTrue(storage.fetchAllItems().isEmpty)
    }

    func test_deleteItem_image_removesFile() {
        // Create a temp image file
        let testDir = ClipboardItem.imageDirectory
        let fileName = "test_delete.png"
        let fileURL = testDir.appendingPathComponent(fileName)
        let image = NSImage(size: NSSize(width: 1, height: 1))
        let pngData = NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!
        try! pngData.write(to: fileURL)

        let item = ClipboardItem(contentType: .image, imageFileName: fileName)
        container.mainContext.insert(item)
        try? container.mainContext.save()

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        storage.deleteItem(item)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    // MARK: - copyToClipboard

    func test_copyToClipboard_text() {
        let item = ClipboardItem(contentType: .text, textContent: "Copied text")
        storage.copyToClipboard(item)

        let pasteboard = NSPasteboard.general
        XCTAssertEqual(pasteboard.string(forType: .string), "Copied text")
    }

    func test_copyToClipboard_image() {
        let testDir = ClipboardItem.imageDirectory
        let fileName = "test_copy.png"
        let fileURL = testDir.appendingPathComponent(fileName)
        let image = NSImage(size: NSSize(width: 10, height: 10))
        let pngData = NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!
        try! pngData.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let item = ClipboardItem(contentType: .image, imageFileName: fileName)
        storage.copyToClipboard(item)

        let pasteboard = NSPasteboard.general
        let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)
        XCTAssertNotNil(images?.first)
    }

    // MARK: - cleanupExpired

    func test_cleanupExpired_removesOldUnpinnedItems() {
        let retentionDays = UserDefaults.standard.integer(forKey: "retentionDays")
        UserDefaults.standard.set(3, forKey: "retentionDays")
        defer { UserDefaults.standard.set(retentionDays, forKey: "retentionDays") }

        let oldDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let old = ClipboardItem(contentType: .text, textContent: "old", timestamp: oldDate)
        let recent = ClipboardItem(contentType: .text, textContent: "recent", timestamp: Date())
        container.mainContext.insert(old)
        container.mainContext.insert(recent)
        try? container.mainContext.save()

        storage.cleanupExpired()
        let remaining = storage.fetchAllItems()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.textContent, "recent")
    }

    func test_cleanupExpired_keepsPinnedItems() {
        let retentionDays = UserDefaults.standard.integer(forKey: "retentionDays")
        UserDefaults.standard.set(3, forKey: "retentionDays")
        defer { UserDefaults.standard.set(retentionDays, forKey: "retentionDays") }

        let oldDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let oldPinned = ClipboardItem(contentType: .text, textContent: "old pinned", timestamp: oldDate, isPinned: true)
        container.mainContext.insert(oldPinned)
        try? container.mainContext.save()

        storage.cleanupExpired()
        XCTAssertEqual(storage.fetchAllItems().count, 1)
    }

    func test_cleanupExpired_retentionZero_skipsCleanup() {
        let retentionDays = UserDefaults.standard.integer(forKey: "retentionDays")
        UserDefaults.standard.set(0, forKey: "retentionDays")
        defer { UserDefaults.standard.set(retentionDays, forKey: "retentionDays") }

        let oldDate = Calendar.current.date(byAdding: .day, value: -365, to: Date())!
        let old = ClipboardItem(contentType: .text, textContent: "ancient", timestamp: oldDate)
        container.mainContext.insert(old)
        try? container.mainContext.save()

        storage.cleanupExpired()
        XCTAssertEqual(storage.fetchAllItems().count, 1)
    }
}
