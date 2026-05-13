import XCTest
@testable import HistoryCopy

final class ClipboardItemTests: XCTestCase {

    // MARK: - Init

    func testInit_withTextContent() {
        let item = ClipboardItem(contentType: .text, textContent: "Hello")
        XCTAssertEqual(item.type, .text)
        XCTAssertEqual(item.textContent, "Hello")
        XCTAssertNil(item.imageFileName)
        XCTAssertNil(item.imageHash)
        XCTAssertFalse(item.isPinned)
        XCTAssertNotNil(item.id)
        XCTAssertNotNil(item.timestamp)
    }

    func testInit_withImageContent() {
        let item = ClipboardItem(
            contentType: .image,
            imageFileName: "abc.png",
            imageHash: "deadbeef",
            sourceAppBundleId: "com.apple.Safari"
        )
        XCTAssertEqual(item.type, .image)
        XCTAssertEqual(item.imageFileName, "abc.png")
        XCTAssertEqual(item.imageHash, "deadbeef")
        XCTAssertEqual(item.sourceAppBundleId, "com.apple.Safari")
        XCTAssertNil(item.textContent)
    }

    func testInit_defaultValues() {
        let item = ClipboardItem(contentType: .text)
        XCTAssertFalse(item.isPinned)
        XCTAssertNil(item.sourceAppBundleId)
        XCTAssertNil(item.textContent)
    }

    func testInit_withCustomTimestamp() {
        let date = Date(timeIntervalSince1970: 0)
        let item = ClipboardItem(contentType: .text, timestamp: date)
        XCTAssertEqual(item.timestamp, date)
    }

    // MARK: - ContentType

    func test_type_rawValue_text() {
        let item = ClipboardItem(contentType: .text)
        XCTAssertEqual(item.contentType, 0)
        XCTAssertEqual(item.type, .text)
    }

    func test_type_rawValue_image() {
        let item = ClipboardItem(contentType: .image)
        XCTAssertEqual(item.contentType, 1)
        XCTAssertEqual(item.type, .image)
    }

    func test_type_invalidRawValue_fallsBackToText() {
        let item = ClipboardItem(contentType: .text)
        item.contentType = 99
        XCTAssertEqual(item.type, .text)
    }

    // MARK: - imageFileURL

    func test_imageFileURL_withFileName() {
        let item = ClipboardItem(contentType: .image, imageFileName: "test.png")
        let url = item.imageFileURL
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.pathExtension == "png")
        XCTAssertTrue(url!.path.contains("HistoryCopy/Images"))
        XCTAssertTrue(url!.lastPathComponent == "test.png")
    }

    func test_imageFileURL_withoutFileName_returnsNil() {
        let item = ClipboardItem(contentType: .text)
        XCTAssertNil(item.imageFileURL)
    }

    // MARK: - imageDirectory

    func test_imageDirectory_pathIsCorrect() {
        let dir = ClipboardItem.imageDirectory
        XCTAssertTrue(dir.path.hasSuffix("HistoryCopy/Images"))
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }

    // MARK: - Pinned

    func test_isPinned_defaultFalse() {
        let item = ClipboardItem(contentType: .text)
        XCTAssertFalse(item.isPinned)
    }

    func test_isPinned_explicitTrue() {
        let item = ClipboardItem(contentType: .text, isPinned: true)
        XCTAssertTrue(item.isPinned)
    }
}
