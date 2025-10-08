import XCTest
@testable import Ready_2_0

final class ReadinessModeTests: XCTestCase {
    func testMorningTimeRangeUsesConfiguredEndHour() {
        let endHour = 11
        UserDefaultsManager.shared.morningEndHour = endHour

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let range = ReadinessMode.morning.getTimeRangeForDate(today)
        
        XCTAssertEqual(cal.component(.hour, from: range.end), endHour)
        XCTAssertEqual(range.start, today)
    }

    func testMorningTimeRangeStartsAtMidnight() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let range = ReadinessMode.morning.getTimeRangeForDate(today)
        
        XCTAssertEqual(range.start, today)
        XCTAssertEqual(cal.component(.hour, from: range.start), 0)
    }
}


