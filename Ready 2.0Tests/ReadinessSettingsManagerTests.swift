import XCTest
@testable import Ready_2_0

final class ReadinessSettingsManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset to known defaults before each test
        let defaults = UserDefaultsManager.shared
        defaults.readinessMode = .morning
        defaults.baselinePeriod = .sevenDays
        defaults.useRHRAdjustment = false
        defaults.useSleepAdjustment = false
        defaults.minimumDaysForBaseline = 3
        defaults.morningEndHour = 11
    }

    func testChangeDetectionBaselinePeriodAndHistoricalFlag() async throws {
        let expectation = expectation(description: "onSettingsChanged called")
        var capturedChanges: ReadinessSettingsChange?

        let mgr = ReadinessSettingsManager { changes in
            capturedChanges = changes
            expectation.fulfill()
        }

        // Change baseline period to trigger historical recalculation requirement
        mgr.baselinePeriod = .fourteenDays
        try await mgr.saveSettings()

        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertNotNil(capturedChanges)
        XCTAssertTrue(capturedChanges!.types.contains(.baselinePeriod))
        XCTAssertTrue(capturedChanges!.requiresHistoricalRecalculation)
        XCTAssertTrue(capturedChanges!.requiresCurrentRecalculation)
        XCTAssertEqual(UserDefaultsManager.shared.baselinePeriod, .fourteenDays)
    }

    func testDiscardRestoresMorningEndHour() {
        let defaults = UserDefaultsManager.shared
        defaults.morningEndHour = 10

        let mgr = ReadinessSettingsManager()
        // Change locally
        mgr.morningEndHour = 12
        mgr.discardChanges()

        // Should be restored from defaults (10)
        XCTAssertEqual(mgr.morningEndHour, 10)
    }

    func testRequiresCurrentOnlyForMorningEndHour() async throws {
        let expectation = expectation(description: "onSettingsChanged called")
        var capturedChanges: ReadinessSettingsChange?

        let mgr = ReadinessSettingsManager { changes in
            capturedChanges = changes
            expectation.fulfill()
        }

        mgr.morningEndHour = 12
        try await mgr.saveSettings()

        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertNotNil(capturedChanges)
        XCTAssertTrue(capturedChanges!.types.contains(.morningEndHour))
        XCTAssertFalse(capturedChanges!.requiresHistoricalRecalculation)
        XCTAssertTrue(capturedChanges!.requiresCurrentRecalculation)
        XCTAssertEqual(UserDefaultsManager.shared.morningEndHour, 12)
    }
}


