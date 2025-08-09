import XCTest
@testable import Ready_2_0

final class MorningWindowTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset key to ensure a clean slate per test
        UserDefaults.standard.removeObject(forKey: "morningEndHour")
    }

    func testDefaultMorningEndHourIs11() {
        // Given fresh defaults
        let manager = UserDefaultsManager.shared

        // When
        let endHour = manager.morningEndHour

        // Then
        XCTAssertEqual(endHour, 11, "Default morningEndHour should be 11")
    }

    func testMorningEndHourClampingLow() {
        let manager = UserDefaultsManager.shared

        // When setting below range
        manager.morningEndHour = 8

        // Then expect clamp to 9
        XCTAssertEqual(manager.morningEndHour, 9, "morningEndHour should clamp to 9 when set below range")
    }

    func testMorningEndHourClampingHigh() {
        let manager = UserDefaultsManager.shared

        // When setting above range
        manager.morningEndHour = 13

        // Then expect clamp to 12
        XCTAssertEqual(manager.morningEndHour, 12, "morningEndHour should clamp to 12 when set above range")
    }

    func testDescriptionReflectsMorningEndHour() {
        let manager = UserDefaultsManager.shared
        manager.morningEndHour = 10

        let description = ReadinessMode.morning.description
        XCTAssertTrue(description.contains("00:00-10:00"), "Description should include the configured morning end hour")
    }

    func testGetTimeRangeForDateUsesConfiguredEndHour() {
        let manager = UserDefaultsManager.shared
        manager.morningEndHour = 12

        let date = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let expectedEnd = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startOfDay)!

        let range = ReadinessMode.morning.getTimeRangeForDate(date)
        XCTAssertEqual(range.start, startOfDay)
        XCTAssertEqual(calendar.component(.hour, from: range.end), 12, "End hour should match configured morning end hour")
        XCTAssertEqual(range.end, expectedEnd)
    }
}


