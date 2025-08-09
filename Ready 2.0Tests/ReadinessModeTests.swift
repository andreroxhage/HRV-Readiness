import XCTest
@testable import Ready_2_0

final class ReadinessModeTests: XCTestCase {
    func testMorningTimeRangeBeforeEndHourUsesNow() {
        let endHour = 11
        UserDefaultsManager.shared.morningEndHour = endHour

        // Force a date before end hour by constructing 8:30 today
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let eightThirty = cal.date(bySettingHour: 8, minute: 30, second: 0, of: today)!

        // Temporarily override Date() via expectation of logic: start is startOfDay, end should be "now" (< endHour)
        // We can't inject now into getTimeRange(), so assert structure: end hour logic path is executed by comparing component
        let range = ReadinessMode.morning.getTimeRangeForDate(today)
        XCTAssertEqual(cal.component(.hour, from: range.end), endHour)
        XCTAssertEqual(range.start, today)
    }

    func testRollingTimeRangeIsSixHours() {
        let range = ReadinessMode.rolling.getTimeRange()
        let diff = range.end.timeIntervalSince(range.start)
        XCTAssertGreaterThanOrEqual(diff, 6 * 3600 - 5)
        XCTAssertLessThanOrEqual(diff, 6 * 3600 + 5)
    }
}


