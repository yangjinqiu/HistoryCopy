import XCTest
@testable import HistoryCopy

final class DateFormatterTests: XCTestCase {

    func test_relativeDisplay_justNow() {
        let date = Date().addingTimeInterval(-5)
        XCTAssertEqual(date.relativeDisplay, "刚刚")
    }

    func test_relativeDisplay_under60Seconds() {
        let date = Date().addingTimeInterval(-59)
        XCTAssertEqual(date.relativeDisplay, "刚刚")
    }

    func test_relativeDisplay_at60Seconds_isMinutes() {
        let date = Date().addingTimeInterval(-60)
        XCTAssertEqual(date.relativeDisplay, "1分钟前")
    }

    func test_relativeDisplay_minutes() {
        let date = Date().addingTimeInterval(-120)
        XCTAssertEqual(date.relativeDisplay, "2分钟前")
    }

    func test_relativeDisplay_hours() {
        let date = Date().addingTimeInterval(-7200)
        XCTAssertEqual(date.relativeDisplay, "2小时前")
    }

    func test_relativeDisplay_at3600Seconds_isOneHour() {
        let date = Date().addingTimeInterval(-3600)
        XCTAssertEqual(date.relativeDisplay, "1小时前")
    }

    func test_relativeDisplay_days() {
        let date = Date().addingTimeInterval(-172800)
        XCTAssertEqual(date.relativeDisplay, "2天前")
    }

    func test_relativeDisplay_at86400Seconds_isOneDay() {
        let date = Date().addingTimeInterval(-86400)
        XCTAssertEqual(date.relativeDisplay, "1天前")
    }

    func test_relativeDisplay_overOneWeek_usesDateFormat() {
        let date = Date().addingTimeInterval(-604801)
        let result = date.relativeDisplay
        // Format: "MM-dd HH:mm"
        let pattern = #/^\d{2}-\d{2} \d{2}:\d{2}$/#
        XCTAssertTrue(result.contains(pattern), "Expected MM-dd HH:mm format, got: \(result)")
    }

    func test_relativeDisplay_boundary_atExactly60Seconds() {
        let date = Date().addingTimeInterval(-60)
        XCTAssertEqual(date.relativeDisplay, "1分钟前")
    }

    func test_relativeDisplay_boundary_atExactly3600Seconds() {
        let date = Date().addingTimeInterval(-3600)
        XCTAssertEqual(date.relativeDisplay, "1小时前")
    }

    func test_relativeDisplay_boundary_atExactly86400Seconds() {
        let date = Date().addingTimeInterval(-86400)
        XCTAssertEqual(date.relativeDisplay, "1天前")
    }
}
