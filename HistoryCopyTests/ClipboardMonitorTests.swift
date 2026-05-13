import XCTest
import SwiftData
import CryptoKit
@testable import HistoryCopy

@MainActor
final class ClipboardMonitorTests: XCTestCase {
    private var monitor: ClipboardMonitor!
    private var container: ModelContainer!
    private var storage: StorageManager!

    override func setUp() {
        super.setUp()
        let schema = Schema([ClipboardItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        storage = StorageManager(container: container)
        monitor = ClipboardMonitor()
    }

    override func tearDown() {
        monitor.stop()
        monitor = nil
        storage = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Text deduplication

    func test_addText_duplicateText_bumpsTimestamp() {
        monitor.start(context: storage.context)

        // Manually insert a text item
        let now = Date(timeIntervalSinceNow: -60)
        let item = ClipboardItem(contentType: .text, textContent: "Duplicate text", timestamp: now)
        storage.context.insert(item)
        try? storage.context.save()

        let originalTimestamp = item.timestamp

        // Simulate copying same text to pasteboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("Duplicate text", forType: .string)

        // Wait a moment for the timer to fire
        let expectation = XCTestExpectation(description: "dedup check")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        let allItems = storage.fetchAllItems()
        XCTAssertEqual(allItems.count, 1, "Should not create duplicate")
        if let first = allItems.first {
            XCTAssertGreaterThan(first.timestamp, originalTimestamp, "Timestamp should be bumped")
        }
    }

    func test_addText_differentText_createsNewItem() {
        monitor.start(context: storage.context)

        storage.context.insert(ClipboardItem(contentType: .text, textContent: "First text"))
        try? storage.context.save()

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("Second text", forType: .string)

        let expectation = XCTestExpectation(description: "new item check")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        let allItems = storage.fetchAllItems()
        XCTAssertEqual(allItems.count, 2, "Different text should create new item")
    }

    func test_addText_emptyContent_ignored() {
        monitor.start(context: storage.context)

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("   ", forType: .string)

        let expectation = XCTestExpectation(description: "empty check")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        XCTAssertTrue(storage.fetchAllItems().isEmpty, "Empty/whitespace text should not create item")
    }

    // MARK: - Image deduplication

    func test_addImage_sameImage_deduplicates() {
        monitor.start(context: storage.context)

        // Create a small test image, compute its hash
        let image = NSImage(size: NSSize(width: 10, height: 10))
        let tiff = image.tiffRepresentation!
        let bitmap = NSBitmapImageRep(data: tiff)!
        let pngData = bitmap.representation(using: .png, properties: [:])!
        let hash = SHA256.hash(data: pngData).compactMap { String(format: "%02x", $0) }.joined()

        // Pre-insert same image item
        let existingDate = Date(timeIntervalSinceNow: -120)
        let fileName = "existing.png"
        let fileURL = ClipboardItem.imageDirectory.appendingPathComponent(fileName)
        try! pngData.write(to: fileURL)

        let existing = ClipboardItem(
            contentType: .image,
            imageFileName: fileName,
            imageHash: hash,
            timestamp: existingDate
        )
        storage.context.insert(existing)
        try? storage.context.save()

        // Copy same image to pasteboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])

        let expectation = XCTestExpectation(description: "image dedup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        let allItems = storage.fetchAllItems()
        XCTAssertEqual(allItems.count, 1, "Same image should not create duplicate")
        if let first = allItems.first {
            XCTAssertGreaterThan(first.timestamp, existingDate, "Timestamp should be bumped")
        }

        // Clean up test file
        try? FileManager.default.removeItem(at: fileURL)
    }

    func test_addImage_differentImage_createsNewItem() {
        monitor.start(context: storage.context)

        // Pre-insert one image
        let image1 = NSImage(size: NSSize(width: 10, height: 10))
        let png1 = NSBitmapImageRep(data: image1.tiffRepresentation!)!.representation(using: .png, properties: [:])!
        let hash1 = SHA256.hash(data: png1).compactMap { String(format: "%02x", $0) }.joined()

        let fileName = "image1.png"
        let fileURL = ClipboardItem.imageDirectory.appendingPathComponent(fileName)
        try! png1.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        storage.context.insert(ClipboardItem(contentType: .image, imageFileName: fileName, imageHash: hash1))
        try? storage.context.save()

        // Copy a DIFFERENT image to pasteboard
        let image2 = NSImage(size: NSSize(width: 20, height: 20)) // Different size = different PNG
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image2])

        let expectation = XCTestExpectation(description: "different image")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        let allItems = storage.fetchAllItems()
        XCTAssertEqual(allItems.count, 2, "Different image should create new item")
    }

    // MARK: - Source app update on dedup

    func test_addText_duplicateText_updatesSourceApp() {
        monitor.start(context: storage.context)

        let item = ClipboardItem(
            contentType: .text,
            textContent: "Repeat text",
            sourceAppBundleId: "com.old.App"
        )
        storage.context.insert(item)
        try? storage.context.save()

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("Repeat text", forType: .string)

        let expectation = XCTestExpectation(description: "source update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        let allItems = storage.fetchAllItems()
        XCTAssertEqual(allItems.count, 1)
        // sourceAppBundleId should be updated to the current frontmost app
        if let first = allItems.first {
            // Could be nil if no frontmost app, or the actual bundle ID
            // We just verify it changed from the original
            XCTAssertNotEqual(first.sourceAppBundleId, "com.old.App")
        }
    }

}
