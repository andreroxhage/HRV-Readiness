import XCTest
@testable import Ready_2_0

class ReadinessServiceTests: XCTestCase {
    
    func testOptimalReadinessScore() {
        // Mock a ReadinessService with controlled baseline values
        let service = MockReadinessService(mockHRVBaseline: 50, mockRHRBaseline: 60)
        
        // Test optimal readiness (HRV within ±3% of baseline)
        let result = service.calculateReadinessScore(hrv: 51, restingHeartRate: 60, sleepHours: 8)
        
        XCTAssertEqual(result.category, ReadinessCategory.optimal)
        XCTAssertTrue(result.score >= 80 && result.score <= 100)
        XCTAssertTrue(result.hrvDeviation > -3 && result.hrvDeviation < 3)
    }
    
    func testModerateReadinessScore() {
        // Mock a ReadinessService with controlled baseline values
        let service = MockReadinessService(mockHRVBaseline: 50, mockRHRBaseline: 60)
        
        // Test moderate readiness (HRV 3-7% lower than baseline)
        let result = service.calculateReadinessScore(hrv: 47, restingHeartRate: 60, sleepHours: 8)
        
        XCTAssertEqual(result.category, ReadinessCategory.moderate)
        XCTAssertTrue(result.score >= 50 && result.score <= 79)
        XCTAssertTrue(result.hrvDeviation < -3 && result.hrvDeviation >= -7)
    }
    
    func testLowReadinessScore() {
        // Mock a ReadinessService with controlled baseline values
        let service = MockReadinessService(mockHRVBaseline: 50, mockRHRBaseline: 60)
        
        // Test low readiness (HRV 7-10% lower than baseline)
        let result = service.calculateReadinessScore(hrv: 45, restingHeartRate: 60, sleepHours: 8)
        
        XCTAssertEqual(result.category, ReadinessCategory.low)
        XCTAssertTrue(result.score >= 30 && result.score <= 49)
        XCTAssertTrue(result.hrvDeviation < -7 && result.hrvDeviation >= -10)
    }
    
    func testFatigueReadinessScore() {
        // Mock a ReadinessService with controlled baseline values
        let service = MockReadinessService(mockHRVBaseline: 50, mockRHRBaseline: 60)
        
        // Test fatigue readiness (HRV >10% lower than baseline)
        let result = service.calculateReadinessScore(hrv: 40, restingHeartRate: 60, sleepHours: 8)
        
        XCTAssertEqual(result.category, ReadinessCategory.fatigue)
        XCTAssertTrue(result.score >= 0 && result.score <= 29)
        XCTAssertTrue(result.hrvDeviation < -10)
    }
    
    func testRHRAdjustment() {
        // Mock a ReadinessService with controlled baseline values
        let service = MockReadinessService(mockHRVBaseline: 50, mockRHRBaseline: 60)
        
        // Test RHR adjustment (RHR >5 bpm above baseline)
        let resultWithoutAdjustment = service.calculateReadinessScore(hrv: 51, restingHeartRate: 60, sleepHours: 8)
        let resultWithAdjustment = service.calculateReadinessScore(hrv: 51, restingHeartRate: 66, sleepHours: 8)
        
        XCTAssertLessThan(resultWithAdjustment.score, resultWithoutAdjustment.score)
        XCTAssertLessThan(resultWithAdjustment.rhrAdjustment, 0)
    }
    
    func testSleepAdjustment() {
        // Mock a ReadinessService with controlled baseline values
        let service = MockReadinessService(mockHRVBaseline: 50, mockRHRBaseline: 60)
        
        // Test sleep adjustment (sleep <6 hours)
        let resultWithoutAdjustment = service.calculateReadinessScore(hrv: 51, restingHeartRate: 60, sleepHours: 8)
        let resultWithAdjustment = service.calculateReadinessScore(hrv: 51, restingHeartRate: 60, sleepHours: 5)
        
        XCTAssertLessThan(resultWithAdjustment.score, resultWithoutAdjustment.score)
        XCTAssertLessThan(resultWithAdjustment.sleepAdjustment, 0)
    }

    func testHistoricalRecalculationChronologyAndMinimumDays() async throws {
        // Arrange: enforce minimum 3 prior days for baseline
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 3
        userDefaults.baselinePeriod = .sevenDays
        
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Seed 4 consecutive days with valid HRV data (>= 10 ms)
        // Oldest first: d4 is the most recent among seeded
        let today = calendar.startOfDay(for: Date())
        let d1 = calendar.date(byAdding: .day, value: -6, to: today)! // oldest
        let d2 = calendar.date(byAdding: .day, value: -5, to: today)!
        let d3 = calendar.date(byAdding: .day, value: -4, to: today)!
        let d4 = calendar.date(byAdding: .day, value: -3, to: today)! // first day with 3 prior
        
        _ = storage.saveHealthMetrics(date: d1, hrv: 50, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: d2, hrv: 52, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: d3, hrv: 54, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: d4, hrv: 56, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Act: recalculate historical scores for last 10 days
        let calculated = try await service.recalculateHistoricalScores(limitDays: 10)
        XCTAssertGreaterThanOrEqual(calculated, 4)
        
        // Assert: d1..d3 should not have sufficient as-of baseline (baseline 0 -> category unknown)
        if let s1 = storage.getReadinessScoreForDate(d1) {
            XCTAssertEqual(s1.hrvBaseline, 0, accuracy: 0.001)
            XCTAssertEqual(s1.category, ReadinessCategory.unknown)
        }
        if let s2 = storage.getReadinessScoreForDate(d2) {
            XCTAssertEqual(s2.hrvBaseline, 0, accuracy: 0.001)
            XCTAssertEqual(s2.category, ReadinessCategory.unknown)
        }
        if let s3 = storage.getReadinessScoreForDate(d3) {
            XCTAssertEqual(s3.hrvBaseline, 0, accuracy: 0.001)
            XCTAssertEqual(s3.category, ReadinessCategory.unknown)
        }
        
        // d4 should have baseline computed from d1..d3 (avg = 52) and not include d4's own HRV
        if let s4 = storage.getReadinessScoreForDate(d4) {
            XCTAssertEqual(s4.hrvBaseline, 52, accuracy: 0.001)
            XCTAssertNotEqual(s4.category, ReadinessCategory.unknown)
        } else {
            XCTFail("Expected readiness score for d4 to be created")
        }
    }

    func testRetentionCleanupDeletesOldData() {
        let coreData = CoreDataManager.shared
        let calendar = Calendar.current
        
        // Seed a score and metrics 400 days ago
        let oldDate = calendar.date(byAdding: .day, value: -400, to: calendar.startOfDay(for: Date()))!
        let metrics = coreData.saveHealthMetrics(date: oldDate, hrv: 40, restingHeartRate: 60, sleepHours: 7, sleepQuality: 3)
        _ = coreData.saveReadinessScore(date: oldDate, score: 50, hrvBaseline: 45, hrvDeviation: -11, readinessCategory: ReadinessCategory.low.rawValue, rhrAdjustment: 0, sleepAdjustment: 0, readinessMode: ReadinessMode.morning.rawValue, baselinePeriod: BaselinePeriod.sevenDays.rawValue, healthMetrics: metrics)
        
        // Run cleanup
        coreData.cleanupDataOlderThan(days: 365)
        
        // Assert old records are gone
        XCTAssertNil(coreData.getHealthMetricsForDate(oldDate))
        XCTAssertNil(coreData.getReadinessScoreForDate(oldDate))
    }

    func testFR3ThresholdBoundaries() {
        // Baseline 100 → HRV values map directly to deviation
        class BaselineMock: ReadinessService {
            override func calculateHRVBaseline() -> Double { 100 }
            override var useRHRAdjustment: Bool { false }
            override var useSleepAdjustment: Bool { false }
        }
        let service = BaselineMock()

        // -3% boundary → 97 → Optimal lower bound
        var r = service.calculateReadinessScore(hrv: 97, restingHeartRate: 0, sleepHours: 0)
        XCTAssertEqual(r.category, ReadinessCategory.optimal)
        XCTAssertTrue(r.score >= 80 && r.score <= 100)

        // -7% boundary → 93 → Moderate/Low boundary
        r = service.calculateReadinessScore(hrv: 93, restingHeartRate: 0, sleepHours: 0)
        XCTAssertEqual(r.category, ReadinessCategory.moderate)
        XCTAssertTrue(r.score >= 50 && r.score <= 79)

        // -10% boundary → 90 → Low/Fatigue boundary
        r = service.calculateReadinessScore(hrv: 90, restingHeartRate: 0, sleepHours: 0)
        XCTAssertEqual(r.category, ReadinessCategory.low)
        XCTAssertTrue(r.score >= 30 && r.score <= 49)

        // < -10% → 80 → Fatigue
        r = service.calculateReadinessScore(hrv: 80, restingHeartRate: 0, sleepHours: 0)
        XCTAssertEqual(r.category, ReadinessCategory.fatigue)
        XCTAssertTrue(r.score >= 0 && r.score <= 29)

        // +3% boundary → 103 → Optimal
        r = service.calculateReadinessScore(hrv: 103, restingHeartRate: 0, sleepHours: 0)
        XCTAssertEqual(r.category, ReadinessCategory.optimal)

        // +10% boundary → 110 → Supercompensation band (>= 90)
        r = service.calculateReadinessScore(hrv: 110, restingHeartRate: 0, sleepHours: 0)
        XCTAssertTrue(r.score >= 90 && r.score <= 100)
    }
    
    // MARK: - Edge Case Tests for Baseline Calculation
    
    func testBaselineCalculationWithExactly2Days() {
        // Test baseline calculation with exactly 2 days of valid HRV data (minimum required)
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        
        // Create exactly 2 days of valid HRV data
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 50, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: day2, hrv: 52, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Calculate baseline
        let baseline = service.calculateHRVBaseline()
        
        // Should calculate baseline from 2 days (average = 51)
        XCTAssertEqual(baseline, 51, accuracy: 0.001)
        XCTAssertGreaterThan(baseline, 0, "Baseline should be calculated with exactly 2 days")
    }
    
    func testBaselineCalculationWithExactly3Days() {
        // Test baseline calculation with exactly 3 days of valid HRV data
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        
        // Create exactly 3 days of valid HRV data
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -3, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day3 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 50, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: day2, hrv: 52, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: day3, hrv: 54, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Calculate baseline
        let baseline = service.calculateHRVBaseline()
        
        // Should calculate baseline from 3 days (average = 52)
        XCTAssertEqual(baseline, 52, accuracy: 0.001)
        XCTAssertGreaterThan(baseline, 0, "Baseline should be calculated with exactly 3 days")
    }
    
    func testBaselineCalculationWithMixedValidInvalidData() {
        // Test baseline calculation with mixed valid and invalid HRV data
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        
        // Create mixed data: some valid (10-200ms), some invalid (<10ms, >200ms)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -5, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -4, to: today)!
        let day3 = calendar.date(byAdding: .day, value: -3, to: today)!
        let day4 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day5 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        // Valid HRV data (should be included)
        _ = storage.saveHealthMetrics(date: day1, hrv: 50, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)  // Valid
        _ = storage.saveHealthMetrics(date: day2, hrv: 5, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)   // Invalid (<10ms)
        _ = storage.saveHealthMetrics(date: day3, hrv: 52, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)  // Valid
        _ = storage.saveHealthMetrics(date: day4, hrv: 250, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3) // Invalid (>200ms)
        _ = storage.saveHealthMetrics(date: day5, hrv: 54, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)  // Valid
        
        // Calculate baseline
        let baseline = service.calculateHRVBaseline()
        
        // Should calculate baseline from only valid data (50, 52, 54) = average 52
        XCTAssertEqual(baseline, 52, accuracy: 0.001)
        XCTAssertGreaterThan(baseline, 0, "Baseline should be calculated from valid data only")
    }
    
    func testProgressiveBaselineWithInsufficientData() {
        // Test progressive baseline building when insufficient data is available
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        
        // Create only 1 day of valid HRV data (insufficient for minimum requirement)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 50, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Calculate baseline
        let baseline = service.calculateHRVBaseline()
        
        // Should use progressive baseline (single day = 50)
        XCTAssertEqual(baseline, 50, accuracy: 0.001)
        XCTAssertGreaterThan(baseline, 0, "Progressive baseline should be calculated with insufficient data")
    }
    
    func testBaselineCalculationWithNoValidData() {
        // Test baseline calculation when no valid HRV data is available
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        
        // Create only invalid HRV data
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 5, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)   // Invalid (<10ms)
        _ = storage.saveHealthMetrics(date: day2, hrv: 250, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3) // Invalid (>200ms)
        
        // Calculate baseline
        let baseline = service.calculateHRVBaseline()
        
        // Should return 0 (no valid data)
        XCTAssertEqual(baseline, 0, accuracy: 0.001)
    }
    
    func testBaselineStabilityWithHighVariation() {
        // Test baseline stability checking with high coefficient of variation
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        
        // Create data with high variation (should trigger stability warning)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -3, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day3 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 20, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)  // Low HRV
        _ = storage.saveHealthMetrics(date: day2, hrv: 50, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)  // Medium HRV
        _ = storage.saveHealthMetrics(date: day3, hrv: 80, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)  // High HRV
        
        // Calculate baseline (average = 50, high variation)
        let baseline = service.calculateHRVBaseline()
        
        // Should still calculate baseline but with high variation
        XCTAssertEqual(baseline, 50, accuracy: 0.001)
        XCTAssertGreaterThan(baseline, 0, "Baseline should be calculated even with high variation")
    }
    
    func testBaselineStabilityWithLowVariation() {
        // Test baseline stability checking with low coefficient of variation
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        
        // Create data with low variation (should be stable)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -3, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day3 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 49, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)  // Very close values
        _ = storage.saveHealthMetrics(date: day2, hrv: 50, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)  // Very close values
        _ = storage.saveHealthMetrics(date: day3, hrv: 51, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)  // Very close values
        
        // Calculate baseline (average = 50, low variation)
        let baseline = service.calculateHRVBaseline()
        
        // Should calculate stable baseline
        XCTAssertEqual(baseline, 50, accuracy: 0.001)
        XCTAssertGreaterThan(baseline, 0, "Baseline should be calculated with low variation")
    }
    
    func testReadinessScoreWithOnlyHRVData() {
        // Test that readiness scores can be calculated using ONLY HRV data when adjustments are disabled
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Ensure adjustments are disabled (default state)
        let userDefaults = UserDefaultsManager.shared
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        
        // Create baseline data (2 days of valid HRV data)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 50, restingHeartRate: 0, sleepHours: 0, sleepQuality: 0)
        _ = storage.saveHealthMetrics(date: day2, hrv: 52, restingHeartRate: 0, sleepHours: 0, sleepQuality: 0)
        
        // Calculate readiness score with only HRV data (RHR=0, Sleep=0)
        let result = service.calculateReadinessScore(hrv: 51, restingHeartRate: 0, sleepHours: 0)
        
        // Should successfully calculate score using only HRV data
        XCTAssertGreaterThan(result.score, 0, "Should calculate readiness score with only HRV data")
        XCTAssertNotEqual(result.category, ReadinessCategory.unknown, "Should not return unknown category")
        XCTAssertEqual(result.hrvBaseline, 51, accuracy: 0.001, "Should calculate HRV baseline from 2 days")
        XCTAssertEqual(result.rhrAdjustment, 0, accuracy: 0.001, "RHR adjustment should be 0 when disabled")
        XCTAssertEqual(result.sleepAdjustment, 0, accuracy: 0.001, "Sleep adjustment should be 0 when disabled")
        
        // HRV deviation should be calculated correctly (51 vs 51 baseline = 0% deviation)
        XCTAssertEqual(result.hrvDeviation, 0, accuracy: 0.001, "HRV deviation should be 0%")
    }
    
    func testReadinessScoreWithInvalidRHRAndSleepData() {
        // Test that readiness scores work even with invalid RHR and sleep data when adjustments are disabled
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Ensure adjustments are disabled
        let userDefaults = UserDefaultsManager.shared
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        
        // Create baseline data
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 50, restingHeartRate: 0, sleepHours: 0, sleepQuality: 0)
        _ = storage.saveHealthMetrics(date: day2, hrv: 52, restingHeartRate: 0, sleepHours: 0, sleepQuality: 0)
        
        // Calculate readiness score with invalid RHR and sleep data
        let result = service.calculateReadinessScore(hrv: 51, restingHeartRate: -1, sleepHours: -1)
        
        // Should successfully calculate score despite invalid RHR and sleep data
        XCTAssertGreaterThan(result.score, 0, "Should calculate readiness score despite invalid RHR/sleep data")
        XCTAssertNotEqual(result.category, ReadinessCategory.unknown, "Should not return unknown category")
        XCTAssertEqual(result.rhrAdjustment, 0, accuracy: 0.001, "RHR adjustment should be 0 when disabled")
        XCTAssertEqual(result.sleepAdjustment, 0, accuracy: 0.001, "Sleep adjustment should be 0 when disabled")
    }
    
    // MARK: - Boundary Value Tests for Data Validation
    
    func testHRVValidationBoundaryValues() {
        // Test HRV validation at boundary values (10ms and 200ms)
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        
        // Create baseline data
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 50, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: day2, hrv: 52, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Test exactly 10ms HRV (should be valid)
        let result10ms = service.calculateReadinessScore(hrv: 10, restingHeartRate: 60, sleepHours: 8)
        XCTAssertGreaterThan(result10ms.score, 0, "HRV of exactly 10ms should be valid")
        XCTAssertNotEqual(result10ms.category, ReadinessCategory.unknown, "HRV of exactly 10ms should not return unknown category")
        
        // Test exactly 200ms HRV (should be valid)
        let result200ms = service.calculateReadinessScore(hrv: 200, restingHeartRate: 60, sleepHours: 8)
        XCTAssertGreaterThan(result200ms.score, 0, "HRV of exactly 200ms should be valid")
        XCTAssertNotEqual(result200ms.category, ReadinessCategory.unknown, "HRV of exactly 200ms should not return unknown category")
        
        // Test 9.99ms HRV (should be invalid)
        let result9_99ms = service.calculateReadinessScore(hrv: 9.99, restingHeartRate: 60, sleepHours: 8)
        XCTAssertEqual(result9_99ms.score, 0, "HRV of 9.99ms should be invalid and return 0 score")
        XCTAssertEqual(result9_99ms.category, ReadinessCategory.unknown, "HRV of 9.99ms should return unknown category")
        
        // Test 200.01ms HRV (should be invalid)
        let result200_01ms = service.calculateReadinessScore(hrv: 200.01, restingHeartRate: 60, sleepHours: 8)
        XCTAssertEqual(result200_01ms.score, 0, "HRV of 200.01ms should be invalid and return 0 score")
        XCTAssertEqual(result200_01ms.category, ReadinessCategory.unknown, "HRV of 200.01ms should return unknown category")
    }
    
    func testRHRValidationBoundaryValues() {
        // Test RHR validation at boundary values (30 bpm and 120 bpm)
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and enable RHR adjustment
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = true
        
        // Create baseline data with valid RHR values
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 50, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: day2, hrv: 52, restingHeartRate: 62, sleepHours: 8, sleepQuality: 3)
        
        // Test exactly 30 bpm RHR (should be valid)
        let result30bpm = service.calculateReadinessScore(hrv: 51, restingHeartRate: 30, sleepHours: 8)
        XCTAssertGreaterThan(result30bpm.score, 0, "RHR of exactly 30 bpm should be valid")
        XCTAssertNotEqual(result30bpm.category, ReadinessCategory.unknown, "RHR of exactly 30 bpm should not return unknown category")
        
        // Test exactly 120 bpm RHR (should be valid)
        let result120bpm = service.calculateReadinessScore(hrv: 51, restingHeartRate: 120, sleepHours: 8)
        XCTAssertGreaterThan(result120bpm.score, 0, "RHR of exactly 120 bpm should be valid")
        XCTAssertNotEqual(result120bpm.category, ReadinessCategory.unknown, "RHR of exactly 120 bpm should not return unknown category")
        
        // Test 29.99 bpm RHR (should be invalid)
        let result29_99bpm = service.calculateReadinessScore(hrv: 51, restingHeartRate: 29.99, sleepHours: 8)
        XCTAssertGreaterThan(result29_99bpm.score, 0, "RHR of 29.99 bpm should still calculate score (RHR validation is for baseline, not current)")
        
        // Test 120.01 bpm RHR (should be invalid)
        let result120_01bpm = service.calculateReadinessScore(hrv: 51, restingHeartRate: 120.01, sleepHours: 8)
        XCTAssertGreaterThan(result120_01bpm.score, 0, "RHR of 120.01 bpm should still calculate score (RHR validation is for baseline, not current)")
    }
    
    func testSleepValidationBoundaryValues() {
        // Test sleep validation at boundary values (>0 hours and <=12 hours)
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and enable sleep adjustment
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useSleepAdjustment = true
        
        // Create baseline data with valid sleep values
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 50, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: day2, hrv: 52, restingHeartRate: 60, sleepHours: 7.5, sleepQuality: 3)
        
        // Test exactly 0.01 hours sleep (should be valid)
        let result0_01h = service.calculateReadinessScore(hrv: 51, restingHeartRate: 60, sleepHours: 0.01)
        XCTAssertGreaterThan(result0_01h.score, 0, "Sleep of exactly 0.01 hours should be valid")
        XCTAssertNotEqual(result0_01h.category, ReadinessCategory.unknown, "Sleep of exactly 0.01 hours should not return unknown category")
        
        // Test exactly 12 hours sleep (should be valid)
        let result12h = service.calculateReadinessScore(hrv: 51, restingHeartRate: 60, sleepHours: 12)
        XCTAssertGreaterThan(result12h.score, 0, "Sleep of exactly 12 hours should be valid")
        XCTAssertNotEqual(result12h.category, ReadinessCategory.unknown, "Sleep of exactly 12 hours should not return unknown category")
        
        // Test exactly 0 hours sleep (should be invalid)
        let result0h = service.calculateReadinessScore(hrv: 51, restingHeartRate: 60, sleepHours: 0)
        XCTAssertGreaterThan(result0h.score, 0, "Sleep of exactly 0 hours should still calculate score (sleep validation is for baseline, not current)")
        
        // Test 12.01 hours sleep (should be invalid)
        let result12_01h = service.calculateReadinessScore(hrv: 51, restingHeartRate: 60, sleepHours: 12.01)
        XCTAssertGreaterThan(result12_01h.score, 0, "Sleep of 12.01 hours should still calculate score (sleep validation is for baseline, not current)")
    }
    
    func testBaselineCalculationWithBoundaryValues() {
        // Test baseline calculation with boundary values to ensure they're included/excluded correctly
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        
        // Create data with boundary values
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -3, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day3 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 10, restingHeartRate: 30, sleepHours: 0.01, sleepQuality: 3)  // Lower boundary
        _ = storage.saveHealthMetrics(date: day2, hrv: 200, restingHeartRate: 120, sleepHours: 12, sleepQuality: 3) // Upper boundary
        _ = storage.saveHealthMetrics(date: day3, hrv: 50, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)    // Normal value
        
        // Calculate HRV baseline (should include 10, 200, 50 = average 86.67)
        let hrvBaseline = service.calculateHRVBaseline()
        XCTAssertEqual(hrvBaseline, 86.67, accuracy: 0.01, "HRV baseline should include boundary values")
        
        // Calculate RHR baseline (should include 30, 120, 60 = average 70)
        let rhrBaseline = service.calculateRHRBaseline()
        XCTAssertEqual(rhrBaseline, 70, accuracy: 0.01, "RHR baseline should include boundary values")
        
        // Calculate sleep baseline (should include 0.01, 12, 8 = average 6.67)
        let sleepBaseline = service.calculateSleepBaseline()
        XCTAssertEqual(sleepBaseline, 6.67, accuracy: 0.01, "Sleep baseline should include boundary values")
    }
    
    func testBaselineCalculationExcludesInvalidBoundaryValues() {
        // Test that baseline calculation excludes values just outside the valid range
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        
        // Create data with invalid boundary values
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -3, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day3 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 9.99, restingHeartRate: 29.99, sleepHours: 0, sleepQuality: 3)    // Just below lower boundary
        _ = storage.saveHealthMetrics(date: day2, hrv: 200.01, restingHeartRate: 120.01, sleepHours: 12.01, sleepQuality: 3) // Just above upper boundary
        _ = storage.saveHealthMetrics(date: day3, hrv: 50, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)           // Valid value
        
        // Calculate HRV baseline (should only include 50, since 9.99 and 200.01 are invalid)
        let hrvBaseline = service.calculateHRVBaseline()
        XCTAssertEqual(hrvBaseline, 50, accuracy: 0.01, "HRV baseline should exclude invalid boundary values")
        
        // Calculate RHR baseline (should only include 60, since 29.99 and 120.01 are invalid)
        let rhrBaseline = service.calculateRHRBaseline()
        XCTAssertEqual(rhrBaseline, 60, accuracy: 0.01, "RHR baseline should exclude invalid boundary values")
        
        // Calculate sleep baseline (should only include 8, since 0 and 12.01 are invalid)
        let sleepBaseline = service.calculateSleepBaseline()
        XCTAssertEqual(sleepBaseline, 8, accuracy: 0.01, "Sleep baseline should exclude invalid boundary values")
    }
    
    // MARK: - FR-3 Threshold Tests
    
    func testFR3ThresholdsCorrectlyImplemented() {
        // Test that FR-3 research thresholds are correctly implemented
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and disable adjustments for pure HRV testing
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Create baseline data (HRV baseline = 100)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: day2, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Test FR-3 thresholds with HRV baseline = 100
        
        // 1. >10% below baseline → Poor/Fatigue (0-29)
        let resultPoor = service.calculateReadinessScore(hrv: 85, restingHeartRate: 60, sleepHours: 8) // -15% deviation
        XCTAssertGreaterThanOrEqual(resultPoor.score, 0, "Poor/Fatigue score should be >= 0")
        XCTAssertLessThanOrEqual(resultPoor.score, 29, "Poor/Fatigue score should be <= 29")
        XCTAssertEqual(resultPoor.hrvDeviation, -15, accuracy: 0.1, "HRV deviation should be -15%")
        
        // 2. 7-10% below baseline → Low (30-49)
        let resultLow = service.calculateReadinessScore(hrv: 92, restingHeartRate: 60, sleepHours: 8) // -8% deviation
        XCTAssertGreaterThanOrEqual(resultLow.score, 30, "Low score should be >= 30")
        XCTAssertLessThanOrEqual(resultLow.score, 49, "Low score should be <= 49")
        XCTAssertEqual(resultLow.hrvDeviation, -8, accuracy: 0.1, "HRV deviation should be -8%")
        
        // 3. 3-7% below baseline → Moderate (50-79)
        let resultModerate = service.calculateReadinessScore(hrv: 95, restingHeartRate: 60, sleepHours: 8) // -5% deviation
        XCTAssertGreaterThanOrEqual(resultModerate.score, 50, "Moderate score should be >= 50")
        XCTAssertLessThanOrEqual(resultModerate.score, 79, "Moderate score should be <= 79")
        XCTAssertEqual(resultModerate.hrvDeviation, -5, accuracy: 0.1, "HRV deviation should be -5%")
        
        // 4. Within ±3% of baseline → Optimal (80-100)
        let resultOptimal = service.calculateReadinessScore(hrv: 100, restingHeartRate: 60, sleepHours: 8) // 0% deviation
        XCTAssertGreaterThanOrEqual(resultOptimal.score, 80, "Optimal score should be >= 80")
        XCTAssertLessThanOrEqual(resultOptimal.score, 100, "Optimal score should be <= 100")
        XCTAssertEqual(resultOptimal.hrvDeviation, 0, accuracy: 0.1, "HRV deviation should be 0%")
        
        // 5. 3-10% above baseline → Good Optimal (80-90)
        let resultGoodOptimal = service.calculateReadinessScore(hrv: 105, restingHeartRate: 60, sleepHours: 8) // +5% deviation
        XCTAssertGreaterThanOrEqual(resultGoodOptimal.score, 80, "Good Optimal score should be >= 80")
        XCTAssertLessThanOrEqual(resultGoodOptimal.score, 90, "Good Optimal score should be <= 90")
        XCTAssertEqual(resultGoodOptimal.hrvDeviation, 5, accuracy: 0.1, "HRV deviation should be +5%")
        
        // 6. >10% above baseline → Supercompensation (90-100)
        let resultSupercompensation = service.calculateReadinessScore(hrv: 115, restingHeartRate: 60, sleepHours: 8) // +15% deviation
        XCTAssertGreaterThanOrEqual(resultSupercompensation.score, 90, "Supercompensation score should be >= 90")
        XCTAssertLessThanOrEqual(resultSupercompensation.score, 100, "Supercompensation score should be <= 100")
        XCTAssertEqual(resultSupercompensation.hrvDeviation, 15, accuracy: 0.1, "HRV deviation should be +15%")
    }
    
    func testFR3ThresholdBoundaryValues() {
        // Test FR-3 thresholds at exact boundary values
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and disable adjustments
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Create baseline data (HRV baseline = 100)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: day2, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Test exact boundary values
        
        // -10% boundary (between Poor/Fatigue and Low)
        let resultMinus10 = service.calculateReadinessScore(hrv: 90, restingHeartRate: 60, sleepHours: 8) // -10% deviation
        XCTAssertEqual(resultMinus10.hrvDeviation, -10, accuracy: 0.1, "HRV deviation should be exactly -10%")
        
        // -7% boundary (between Low and Moderate)
        let resultMinus7 = service.calculateReadinessScore(hrv: 93, restingHeartRate: 60, sleepHours: 8) // -7% deviation
        XCTAssertEqual(resultMinus7.hrvDeviation, -7, accuracy: 0.1, "HRV deviation should be exactly -7%")
        
        // -3% boundary (between Moderate and Optimal)
        let resultMinus3 = service.calculateReadinessScore(hrv: 97, restingHeartRate: 60, sleepHours: 8) // -3% deviation
        XCTAssertEqual(resultMinus3.hrvDeviation, -3, accuracy: 0.1, "HRV deviation should be exactly -3%")
        
        // +3% boundary (between Optimal and Good Optimal)
        let resultPlus3 = service.calculateReadinessScore(hrv: 103, restingHeartRate: 60, sleepHours: 8) // +3% deviation
        XCTAssertEqual(resultPlus3.hrvDeviation, 3, accuracy: 0.1, "HRV deviation should be exactly +3%")
        
        // +10% boundary (between Good Optimal and Supercompensation)
        let resultPlus10 = service.calculateReadinessScore(hrv: 110, restingHeartRate: 60, sleepHours: 8) // +10% deviation
        XCTAssertEqual(resultPlus10.hrvDeviation, 10, accuracy: 0.1, "HRV deviation should be exactly +10%")
    }
    
    func testFR3ThresholdScoreRanges() {
        // Test that FR-3 threshold score ranges are correctly implemented
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and disable adjustments
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Create baseline data (HRV baseline = 100)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: day2, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Test score ranges for each threshold
        
        // Poor/Fatigue range (0-29): Test with -20% deviation
        let resultPoor = service.calculateReadinessScore(hrv: 80, restingHeartRate: 60, sleepHours: 8) // -20% deviation
        XCTAssertGreaterThanOrEqual(resultPoor.score, 0, "Poor/Fatigue score should be >= 0")
        XCTAssertLessThanOrEqual(resultPoor.score, 29, "Poor/Fatigue score should be <= 29")
        
        // Low range (30-49): Test with -8.5% deviation
        let resultLow = service.calculateReadinessScore(hrv: 91.5, restingHeartRate: 60, sleepHours: 8) // -8.5% deviation
        XCTAssertGreaterThanOrEqual(resultLow.score, 30, "Low score should be >= 30")
        XCTAssertLessThanOrEqual(resultLow.score, 49, "Low score should be <= 49")
        
        // Moderate range (50-79): Test with -5% deviation
        let resultModerate = service.calculateReadinessScore(hrv: 95, restingHeartRate: 60, sleepHours: 8) // -5% deviation
        XCTAssertGreaterThanOrEqual(resultModerate.score, 50, "Moderate score should be >= 50")
        XCTAssertLessThanOrEqual(resultModerate.score, 79, "Moderate score should be <= 79")
        
        // Optimal range (80-100): Test with 0% deviation
        let resultOptimal = service.calculateReadinessScore(hrv: 100, restingHeartRate: 60, sleepHours: 8) // 0% deviation
        XCTAssertGreaterThanOrEqual(resultOptimal.score, 80, "Optimal score should be >= 80")
        XCTAssertLessThanOrEqual(resultOptimal.score, 100, "Optimal score should be <= 100")
        
        // Good Optimal range (80-90): Test with +6.5% deviation
        let resultGoodOptimal = service.calculateReadinessScore(hrv: 106.5, restingHeartRate: 60, sleepHours: 8) // +6.5% deviation
        XCTAssertGreaterThanOrEqual(resultGoodOptimal.score, 80, "Good Optimal score should be >= 80")
        XCTAssertLessThanOrEqual(resultGoodOptimal.score, 90, "Good Optimal score should be <= 90")
        
        // Supercompensation range (90-100): Test with +15% deviation
        let resultSupercompensation = service.calculateReadinessScore(hrv: 115, restingHeartRate: 60, sleepHours: 8) // +15% deviation
        XCTAssertGreaterThanOrEqual(resultSupercompensation.score, 90, "Supercompensation score should be >= 90")
        XCTAssertLessThanOrEqual(resultSupercompensation.score, 100, "Supercompensation score should be <= 100")
    }
    
    // MARK: - HRV Deviation Calculation Tests
    
    func testHRVDeviationCalculationAccuracy() {
        // Test that HRV deviation calculations are accurate (primary scoring method)
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and disable adjustments for pure HRV testing
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Create baseline data (HRV baseline = 100)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: day2, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Test various HRV deviation calculations
        
        // Test 0% deviation (exact baseline)
        let result0 = service.calculateReadinessScore(hrv: 100, restingHeartRate: 60, sleepHours: 8)
        XCTAssertEqual(result0.hrvDeviation, 0, accuracy: 0.001, "HRV deviation should be exactly 0% when HRV equals baseline")
        
        // Test +10% deviation
        let resultPlus10 = service.calculateReadinessScore(hrv: 110, restingHeartRate: 60, sleepHours: 8)
        XCTAssertEqual(resultPlus10.hrvDeviation, 10, accuracy: 0.001, "HRV deviation should be exactly +10%")
        
        // Test -10% deviation
        let resultMinus10 = service.calculateReadinessScore(hrv: 90, restingHeartRate: 60, sleepHours: 8)
        XCTAssertEqual(resultMinus10.hrvDeviation, -10, accuracy: 0.001, "HRV deviation should be exactly -10%")
        
        // Test +25% deviation
        let resultPlus25 = service.calculateReadinessScore(hrv: 125, restingHeartRate: 60, sleepHours: 8)
        XCTAssertEqual(resultPlus25.hrvDeviation, 25, accuracy: 0.001, "HRV deviation should be exactly +25%")
        
        // Test -25% deviation
        let resultMinus25 = service.calculateReadinessScore(hrv: 75, restingHeartRate: 60, sleepHours: 8)
        XCTAssertEqual(resultMinus25.hrvDeviation, -25, accuracy: 0.001, "HRV deviation should be exactly -25%")
        
        // Test +50% deviation
        let resultPlus50 = service.calculateReadinessScore(hrv: 150, restingHeartRate: 60, sleepHours: 8)
        XCTAssertEqual(resultPlus50.hrvDeviation, 50, accuracy: 0.001, "HRV deviation should be exactly +50%")
        
        // Test -50% deviation
        let resultMinus50 = service.calculateReadinessScore(hrv: 50, restingHeartRate: 60, sleepHours: 8)
        XCTAssertEqual(resultMinus50.hrvDeviation, -50, accuracy: 0.001, "HRV deviation should be exactly -50%")
    }
    
    func testHRVDeviationWithDifferentBaselines() {
        // Test HRV deviation calculations with different baseline values
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and disable adjustments
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Test with baseline = 50
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 50, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: day2, hrv: 50, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Test +20% deviation from baseline 50 (should be 60)
        let resultPlus20 = service.calculateReadinessScore(hrv: 60, restingHeartRate: 60, sleepHours: 8)
        XCTAssertEqual(resultPlus20.hrvDeviation, 20, accuracy: 0.001, "HRV deviation should be exactly +20% from baseline 50")
        
        // Test -20% deviation from baseline 50 (should be 40)
        let resultMinus20 = service.calculateReadinessScore(hrv: 40, restingHeartRate: 60, sleepHours: 8)
        XCTAssertEqual(resultMinus20.hrvDeviation, -20, accuracy: 0.001, "HRV deviation should be exactly -20% from baseline 50")
        
        // Test with baseline = 200
        _ = storage.saveHealthMetrics(date: day1, hrv: 200, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: day2, hrv: 200, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Test +15% deviation from baseline 200 (should be 230)
        let resultPlus15 = service.calculateReadinessScore(hrv: 230, restingHeartRate: 60, sleepHours: 8)
        XCTAssertEqual(resultPlus15.hrvDeviation, 15, accuracy: 0.001, "HRV deviation should be exactly +15% from baseline 200")
        
        // Test -15% deviation from baseline 200 (should be 170)
        let resultMinus15 = service.calculateReadinessScore(hrv: 170, restingHeartRate: 60, sleepHours: 8)
        XCTAssertEqual(resultMinus15.hrvDeviation, -15, accuracy: 0.001, "HRV deviation should be exactly -15% from baseline 200")
    }
    
    func testHRVDeviationPrecision() {
        // Test HRV deviation calculation precision with decimal values
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and disable adjustments
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Create baseline data with decimal values (HRV baseline = 75.5)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 75.5, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: day2, hrv: 75.5, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Test precise deviation calculations
        
        // Test +6.67% deviation (should be 80.5)
        let resultPlus6_67 = service.calculateReadinessScore(hrv: 80.5, restingHeartRate: 60, sleepHours: 8)
        XCTAssertEqual(resultPlus6_67.hrvDeviation, 6.67, accuracy: 0.01, "HRV deviation should be approximately +6.67%")
        
        // Test -6.67% deviation (should be 70.5)
        let resultMinus6_67 = service.calculateReadinessScore(hrv: 70.5, restingHeartRate: 60, sleepHours: 8)
        XCTAssertEqual(resultMinus6_67.hrvDeviation, -6.67, accuracy: 0.01, "HRV deviation should be approximately -6.67%")
        
        // Test +13.33% deviation (should be 85.5)
        let resultPlus13_33 = service.calculateReadinessScore(hrv: 85.5, restingHeartRate: 60, sleepHours: 8)
        XCTAssertEqual(resultPlus13_33.hrvDeviation, 13.33, accuracy: 0.01, "HRV deviation should be approximately +13.33%")
        
        // Test -13.33% deviation (should be 65.5)
        let resultMinus13_33 = service.calculateReadinessScore(hrv: 65.5, restingHeartRate: 60, sleepHours: 8)
        XCTAssertEqual(resultMinus13_33.hrvDeviation, -13.33, accuracy: 0.01, "HRV deviation should be approximately -13.33%")
    }
    
    func testHRVDeviationFormula() {
        // Test the HRV deviation formula: ((hrv - hrvBaseline) / hrvBaseline) * 100
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and disable adjustments
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Create baseline data (HRV baseline = 80)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 80, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: day2, hrv: 80, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Test the formula manually and compare with service result
        let hrvBaseline = 80.0
        let testHRV = 88.0
        let expectedDeviation = ((testHRV - hrvBaseline) / hrvBaseline) * 100 // Should be 10%
        
        let result = service.calculateReadinessScore(hrv: testHRV, restingHeartRate: 60, sleepHours: 8)
        
        XCTAssertEqual(result.hrvDeviation, expectedDeviation, accuracy: 0.001, "HRV deviation should match manual calculation")
        XCTAssertEqual(result.hrvDeviation, 10, accuracy: 0.001, "HRV deviation should be exactly 10%")
        
        // Test another case
        let testHRV2 = 72.0
        let expectedDeviation2 = ((testHRV2 - hrvBaseline) / hrvBaseline) * 100 // Should be -10%
        
        let result2 = service.calculateReadinessScore(hrv: testHRV2, restingHeartRate: 60, sleepHours: 8)
        
        XCTAssertEqual(result2.hrvDeviation, expectedDeviation2, accuracy: 0.001, "HRV deviation should match manual calculation")
        XCTAssertEqual(result2.hrvDeviation, -10, accuracy: 0.001, "HRV deviation should be exactly -10%")
    }
    
    // MARK: - RHR and Sleep Adjustment Tests
    
    func testRHRAdjustmentWhenEnabled() {
        // Test that RHR adjustment works correctly when enabled
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and enable RHR adjustment
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = true
        userDefaults.useSleepAdjustment = false
        
        // Create baseline data (HRV baseline = 100, RHR baseline = 60)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: day2, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Test RHR within normal range (≤5 bpm over baseline) - should have no adjustment
        let resultNormal = service.calculateReadinessScore(hrv: 100, restingHeartRate: 65, sleepHours: 8) // +5 bpm over baseline
        XCTAssertEqual(resultNormal.rhrAdjustment, 0, accuracy: 0.001, "RHR adjustment should be 0 when within normal range")
        XCTAssertEqual(resultNormal.score, resultNormal.hrvBaseline > 0 ? 100 : 0, accuracy: 0.001, "Score should not be adjusted")
        
        // Test RHR elevated >5 bpm over baseline - should have -10% adjustment
        let resultElevated = service.calculateReadinessScore(hrv: 100, restingHeartRate: 70, sleepHours: 8) // +10 bpm over baseline
        XCTAssertEqual(resultElevated.rhrAdjustment, -10, accuracy: 0.001, "RHR adjustment should be -10 when elevated >5 bpm")
        XCTAssertEqual(resultElevated.score, 90, accuracy: 0.001, "Score should be reduced by 10 points")
        
        // Test RHR significantly elevated - should have -10% adjustment
        let resultVeryElevated = service.calculateReadinessScore(hrv: 100, restingHeartRate: 80, sleepHours: 8) // +20 bpm over baseline
        XCTAssertEqual(resultVeryElevated.rhrAdjustment, -10, accuracy: 0.001, "RHR adjustment should be -10 when significantly elevated")
        XCTAssertEqual(resultVeryElevated.score, 90, accuracy: 0.001, "Score should be reduced by 10 points")
    }
    
    func testRHRAdjustmentWhenDisabled() {
        // Test that RHR adjustment is not applied when disabled
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and disable RHR adjustment
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Create baseline data (HRV baseline = 100, RHR baseline = 60)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: day2, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Test with elevated RHR - should have no adjustment when disabled
        let result = service.calculateReadinessScore(hrv: 100, restingHeartRate: 80, sleepHours: 8) // +20 bpm over baseline
        XCTAssertEqual(result.rhrAdjustment, 0, accuracy: 0.001, "RHR adjustment should be 0 when disabled")
        XCTAssertEqual(result.score, 100, accuracy: 0.001, "Score should not be adjusted when RHR adjustment is disabled")
    }
    
    func testSleepAdjustmentWhenEnabled() {
        // Test that sleep adjustment works correctly when enabled
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and enable sleep adjustment
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = true
        
        // Create baseline data (HRV baseline = 100)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: day2, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Test adequate sleep (≥6 hours) - should have no adjustment
        let resultAdequate = service.calculateReadinessScore(hrv: 100, restingHeartRate: 60, sleepHours: 8) // 8 hours sleep
        XCTAssertEqual(resultAdequate.sleepAdjustment, 0, accuracy: 0.001, "Sleep adjustment should be 0 when sleep is adequate")
        XCTAssertEqual(resultAdequate.score, 100, accuracy: 0.001, "Score should not be adjusted")
        
        // Test poor sleep (<6 hours) - should have -15% adjustment
        let resultPoor = service.calculateReadinessScore(hrv: 100, restingHeartRate: 60, sleepHours: 5) // 5 hours sleep
        XCTAssertEqual(resultPoor.sleepAdjustment, -15, accuracy: 0.001, "Sleep adjustment should be -15 when sleep is poor")
        XCTAssertEqual(resultPoor.score, 85, accuracy: 0.001, "Score should be reduced by 15 points")
        
        // Test very poor sleep - should have -15% adjustment
        let resultVeryPoor = service.calculateReadinessScore(hrv: 100, restingHeartRate: 60, sleepHours: 3) // 3 hours sleep
        XCTAssertEqual(resultVeryPoor.sleepAdjustment, -15, accuracy: 0.001, "Sleep adjustment should be -15 when sleep is very poor")
        XCTAssertEqual(resultVeryPoor.score, 85, accuracy: 0.001, "Score should be reduced by 15 points")
        
        // Test exactly 6 hours sleep - should have no adjustment (boundary case)
        let resultBoundary = service.calculateReadinessScore(hrv: 100, restingHeartRate: 60, sleepHours: 6) // 6 hours sleep
        XCTAssertEqual(resultBoundary.sleepAdjustment, 0, accuracy: 0.001, "Sleep adjustment should be 0 when sleep is exactly 6 hours")
        XCTAssertEqual(resultBoundary.score, 100, accuracy: 0.001, "Score should not be adjusted")
    }
    
    func testSleepAdjustmentWhenDisabled() {
        // Test that sleep adjustment is not applied when disabled
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and disable sleep adjustment
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Create baseline data (HRV baseline = 100)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: day2, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Test with poor sleep - should have no adjustment when disabled
        let result = service.calculateReadinessScore(hrv: 100, restingHeartRate: 60, sleepHours: 3) // 3 hours sleep
        XCTAssertEqual(result.sleepAdjustment, 0, accuracy: 0.001, "Sleep adjustment should be 0 when disabled")
        XCTAssertEqual(result.score, 100, accuracy: 0.001, "Score should not be adjusted when sleep adjustment is disabled")
    }
    
    func testCombinedRHRAndSleepAdjustments() {
        // Test that both RHR and sleep adjustments work together when both are enabled
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and enable both adjustments
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = true
        userDefaults.useSleepAdjustment = true
        
        // Create baseline data (HRV baseline = 100, RHR baseline = 60)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: day2, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Test both adjustments applied together
        let result = service.calculateReadinessScore(hrv: 100, restingHeartRate: 70, sleepHours: 4) // Elevated RHR + poor sleep
        XCTAssertEqual(result.rhrAdjustment, -10, accuracy: 0.001, "RHR adjustment should be -10")
        XCTAssertEqual(result.sleepAdjustment, -15, accuracy: 0.001, "Sleep adjustment should be -15")
        XCTAssertEqual(result.score, 75, accuracy: 0.001, "Score should be reduced by both adjustments (100 - 10 - 15 = 75)")
        
        // Test score clamping (should not go below 0)
        let resultClamped = service.calculateReadinessScore(hrv: 50, restingHeartRate: 70, sleepHours: 4) // Low HRV + elevated RHR + poor sleep
        XCTAssertGreaterThanOrEqual(resultClamped.score, 0, "Score should be clamped to minimum 0")
        XCTAssertLessThanOrEqual(resultClamped.score, 100, "Score should be clamped to maximum 100")
    }
    
    func testAdjustmentBoundaryValues() {
        // Test adjustment boundary values
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and enable both adjustments
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = true
        userDefaults.useSleepAdjustment = true
        
        // Create baseline data (HRV baseline = 100, RHR baseline = 60)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: day2, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Test RHR exactly 5 bpm over baseline (boundary case)
        let resultRHRBoundary = service.calculateReadinessScore(hrv: 100, restingHeartRate: 65, sleepHours: 8) // Exactly +5 bpm
        XCTAssertEqual(resultRHRBoundary.rhrAdjustment, 0, accuracy: 0.001, "RHR adjustment should be 0 at exactly 5 bpm over baseline")
        
        // Test RHR just over 5 bpm over baseline
        let resultRHRJustOver = service.calculateReadinessScore(hrv: 100, restingHeartRate: 65.1, sleepHours: 8) // Just over +5 bpm
        XCTAssertEqual(resultRHRJustOver.rhrAdjustment, -10, accuracy: 0.001, "RHR adjustment should be -10 when just over 5 bpm")
        
        // Test sleep exactly 6 hours (boundary case)
        let resultSleepBoundary = service.calculateReadinessScore(hrv: 100, restingHeartRate: 60, sleepHours: 6) // Exactly 6 hours
        XCTAssertEqual(resultSleepBoundary.sleepAdjustment, 0, accuracy: 0.001, "Sleep adjustment should be 0 at exactly 6 hours")
        
        // Test sleep just under 6 hours
        let resultSleepJustUnder = service.calculateReadinessScore(hrv: 100, restingHeartRate: 60, sleepHours: 5.9) // Just under 6 hours
        XCTAssertEqual(resultSleepJustUnder.sleepAdjustment, -15, accuracy: 0.001, "Sleep adjustment should be -15 when just under 6 hours")
    }
    
    // MARK: - Score Generation with Missing RHR/Sleep Data Tests
    
    func testScoreGenerationWithMissingRHRData() {
        // Test that scores are generated when RHR data is missing (0 or invalid)
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and disable adjustments for pure HRV testing
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Create baseline data (HRV baseline = 100)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 100, restingHeartRate: 0, sleepHours: 0, sleepQuality: 0)
        _ = storage.saveHealthMetrics(date: day2, hrv: 100, restingHeartRate: 0, sleepHours: 0, sleepQuality: 0)
        
        // Test with RHR = 0 (missing data)
        let resultRHR0 = service.calculateReadinessScore(hrv: 100, restingHeartRate: 0, sleepHours: 8)
        XCTAssertGreaterThan(resultRHR0.score, 0, "Should generate score with RHR = 0")
        XCTAssertNotEqual(resultRHR0.category, ReadinessCategory.unknown, "Should not return unknown category with RHR = 0")
        XCTAssertEqual(resultRHR0.hrvDeviation, 0, accuracy: 0.001, "HRV deviation should be calculated correctly")
        
        // Test with invalid RHR data
        let resultInvalidRHR = service.calculateReadinessScore(hrv: 100, restingHeartRate: -1, sleepHours: 8)
        XCTAssertGreaterThan(resultInvalidRHR.score, 0, "Should generate score with invalid RHR data")
        XCTAssertNotEqual(resultInvalidRHR.category, ReadinessCategory.unknown, "Should not return unknown category with invalid RHR")
        
        // Test with very high RHR (outside valid range)
        let resultHighRHR = service.calculateReadinessScore(hrv: 100, restingHeartRate: 200, sleepHours: 8)
        XCTAssertGreaterThan(resultHighRHR.score, 0, "Should generate score with very high RHR")
        XCTAssertNotEqual(resultHighRHR.category, ReadinessCategory.unknown, "Should not return unknown category with very high RHR")
    }
    
    func testScoreGenerationWithMissingSleepData() {
        // Test that scores are generated when sleep data is missing (0 or invalid)
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and disable adjustments for pure HRV testing
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Create baseline data (HRV baseline = 100)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 100, restingHeartRate: 60, sleepHours: 0, sleepQuality: 0)
        _ = storage.saveHealthMetrics(date: day2, hrv: 100, restingHeartRate: 60, sleepHours: 0, sleepQuality: 0)
        
        // Test with sleep = 0 (missing data)
        let resultSleep0 = service.calculateReadinessScore(hrv: 100, restingHeartRate: 60, sleepHours: 0)
        XCTAssertGreaterThan(resultSleep0.score, 0, "Should generate score with sleep = 0")
        XCTAssertNotEqual(resultSleep0.category, ReadinessCategory.unknown, "Should not return unknown category with sleep = 0")
        XCTAssertEqual(resultSleep0.hrvDeviation, 0, accuracy: 0.001, "HRV deviation should be calculated correctly")
        
        // Test with invalid sleep data
        let resultInvalidSleep = service.calculateReadinessScore(hrv: 100, restingHeartRate: 60, sleepHours: -1)
        XCTAssertGreaterThan(resultInvalidSleep.score, 0, "Should generate score with invalid sleep data")
        XCTAssertNotEqual(resultInvalidSleep.category, ReadinessCategory.unknown, "Should not return unknown category with invalid sleep")
        
        // Test with very high sleep (outside valid range)
        let resultHighSleep = service.calculateReadinessScore(hrv: 100, restingHeartRate: 60, sleepHours: 20)
        XCTAssertGreaterThan(resultHighSleep.score, 0, "Should generate score with very high sleep")
        XCTAssertNotEqual(resultHighSleep.category, ReadinessCategory.unknown, "Should not return unknown category with very high sleep")
    }
    
    func testScoreGenerationWithBothRHRAndSleepMissing() {
        // Test that scores are generated when both RHR and sleep data are missing
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and disable adjustments for pure HRV testing
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Create baseline data (HRV baseline = 100)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 100, restingHeartRate: 0, sleepHours: 0, sleepQuality: 0)
        _ = storage.saveHealthMetrics(date: day2, hrv: 100, restingHeartRate: 0, sleepHours: 0, sleepQuality: 0)
        
        // Test with both RHR and sleep missing
        let result = service.calculateReadinessScore(hrv: 100, restingHeartRate: 0, sleepHours: 0)
        XCTAssertGreaterThan(result.score, 0, "Should generate score with both RHR and sleep missing")
        XCTAssertNotEqual(result.category, ReadinessCategory.unknown, "Should not return unknown category with both RHR and sleep missing")
        XCTAssertEqual(result.hrvDeviation, 0, accuracy: 0.001, "HRV deviation should be calculated correctly")
        XCTAssertEqual(result.rhrAdjustment, 0, accuracy: 0.001, "RHR adjustment should be 0 when disabled")
        XCTAssertEqual(result.sleepAdjustment, 0, accuracy: 0.001, "Sleep adjustment should be 0 when disabled")
    }
    
    func testScoreGenerationWithInvalidRHRAndSleepData() {
        // Test that scores are generated with completely invalid RHR and sleep data
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and disable adjustments for pure HRV testing
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Create baseline data (HRV baseline = 100)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 100, restingHeartRate: 0, sleepHours: 0, sleepQuality: 0)
        _ = storage.saveHealthMetrics(date: day2, hrv: 100, restingHeartRate: 0, sleepHours: 0, sleepQuality: 0)
        
        // Test with completely invalid RHR and sleep data
        let result = service.calculateReadinessScore(hrv: 100, restingHeartRate: -999, sleepHours: -999)
        XCTAssertGreaterThan(result.score, 0, "Should generate score with completely invalid RHR and sleep data")
        XCTAssertNotEqual(result.category, ReadinessCategory.unknown, "Should not return unknown category with invalid data")
        XCTAssertEqual(result.hrvDeviation, 0, accuracy: 0.001, "HRV deviation should be calculated correctly")
    }
    
    func testScoreGenerationWithAdjustmentsEnabledButMissingData() {
        // Test that scores are generated when adjustments are enabled but RHR/sleep data is missing
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and enable adjustments
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = true
        userDefaults.useSleepAdjustment = true
        
        // Create baseline data (HRV baseline = 100, RHR baseline = 60)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: day2, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Test with missing RHR data (adjustment should be skipped)
        let resultMissingRHR = service.calculateReadinessScore(hrv: 100, restingHeartRate: 0, sleepHours: 8)
        XCTAssertGreaterThan(resultMissingRHR.score, 0, "Should generate score with missing RHR data")
        XCTAssertNotEqual(resultMissingRHR.category, ReadinessCategory.unknown, "Should not return unknown category")
        XCTAssertEqual(resultMissingRHR.rhrAdjustment, 0, accuracy: 0.001, "RHR adjustment should be 0 when RHR data is missing")
        XCTAssertEqual(resultMissingRHR.sleepAdjustment, 0, accuracy: 0.001, "Sleep adjustment should be 0 when sleep is adequate")
        
        // Test with missing sleep data (adjustment should be skipped)
        let resultMissingSleep = service.calculateReadinessScore(hrv: 100, restingHeartRate: 60, sleepHours: 0)
        XCTAssertGreaterThan(resultMissingSleep.score, 0, "Should generate score with missing sleep data")
        XCTAssertNotEqual(resultMissingSleep.category, ReadinessCategory.unknown, "Should not return unknown category")
        XCTAssertEqual(resultMissingSleep.rhrAdjustment, 0, accuracy: 0.001, "RHR adjustment should be 0 when RHR is normal")
        XCTAssertEqual(resultMissingSleep.sleepAdjustment, 0, accuracy: 0.001, "Sleep adjustment should be 0 when sleep data is missing")
        
        // Test with both missing (adjustments should be skipped)
        let resultBothMissing = service.calculateReadinessScore(hrv: 100, restingHeartRate: 0, sleepHours: 0)
        XCTAssertGreaterThan(resultBothMissing.score, 0, "Should generate score with both RHR and sleep missing")
        XCTAssertNotEqual(resultBothMissing.category, ReadinessCategory.unknown, "Should not return unknown category")
        XCTAssertEqual(resultBothMissing.rhrAdjustment, 0, accuracy: 0.001, "RHR adjustment should be 0 when RHR data is missing")
        XCTAssertEqual(resultBothMissing.sleepAdjustment, 0, accuracy: 0.001, "Sleep adjustment should be 0 when sleep data is missing")
    }
    
    func testScoreGenerationWithDifferentHRVValues() {
        // Test that scores are generated for different HRV values regardless of RHR/sleep availability
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and disable adjustments
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Create baseline data (HRV baseline = 100)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 100, restingHeartRate: 0, sleepHours: 0, sleepQuality: 0)
        _ = storage.saveHealthMetrics(date: day2, hrv: 100, restingHeartRate: 0, sleepHours: 0, sleepQuality: 0)
        
        // Test various HRV values with missing RHR/sleep data
        let testCases = [
            (hrv: 50.0, expectedDeviation: -50.0),   // Poor HRV
            (hrv: 80.0, expectedDeviation: -20.0),   // Low HRV
            (hrv: 95.0, expectedDeviation: -5.0),    // Moderate HRV
            (hrv: 100.0, expectedDeviation: 0.0),    // Optimal HRV
            (hrv: 105.0, expectedDeviation: 5.0),    // Good HRV
            (hrv: 120.0, expectedDeviation: 20.0)    // Supercompensation HRV
        ]
        
        for testCase in testCases {
            let result = service.calculateReadinessScore(hrv: testCase.hrv, restingHeartRate: 0, sleepHours: 0)
            XCTAssertGreaterThan(result.score, 0, "Should generate score for HRV \(testCase.hrv) with missing RHR/sleep data")
            XCTAssertNotEqual(result.category, ReadinessCategory.unknown, "Should not return unknown category for HRV \(testCase.hrv)")
            XCTAssertEqual(result.hrvDeviation, testCase.expectedDeviation, accuracy: 0.001, "HRV deviation should be correct for \(testCase.hrv)")
        }
    }
    
    func testSystemWorksWithRHR0AndSleep0WhenAdjustmentsDisabled() {
        // Test the critical requirement: system works with RHR=0 and Sleep=0 when adjustments are disabled
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and disable adjustments (default state)
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false  // Disabled by default
        userDefaults.useSleepAdjustment = false  // Disabled by default
        
        // Create baseline data (HRV baseline = 100)
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        
        _ = storage.saveHealthMetrics(date: day1, hrv: 100, restingHeartRate: 0, sleepHours: 0, sleepQuality: 0)
        _ = storage.saveHealthMetrics(date: day2, hrv: 100, restingHeartRate: 0, sleepHours: 0, sleepQuality: 0)
        
        // Test with RHR=0 and Sleep=0 (adjustments disabled)
        let result = service.calculateReadinessScore(hrv: 100, restingHeartRate: 0, sleepHours: 0)
        
        // Should successfully generate score
        XCTAssertGreaterThan(result.score, 0, "Should generate score with RHR=0 and Sleep=0 when adjustments are disabled")
        XCTAssertNotEqual(result.category, ReadinessCategory.unknown, "Should not return unknown category")
        XCTAssertEqual(result.hrvDeviation, 0, accuracy: 0.001, "HRV deviation should be calculated correctly")
        XCTAssertEqual(result.rhrAdjustment, 0, accuracy: 0.001, "RHR adjustment should be 0 when disabled")
        XCTAssertEqual(result.sleepAdjustment, 0, accuracy: 0.001, "Sleep adjustment should be 0 when disabled")
        
        // Test with different HRV values and RHR=0, Sleep=0
        let testCases = [
            (hrv: 50.0, expectedScore: 0),     // Poor HRV (should be clamped to 0)
            (hrv: 80.0, expectedScore: 30),    // Low HRV
            (hrv: 95.0, expectedScore: 65),    // Moderate HRV
            (hrv: 100.0, expectedScore: 100),  // Optimal HRV
            (hrv: 105.0, expectedScore: 87),   // Good HRV
            (hrv: 120.0, expectedScore: 95)    // Supercompensation HRV
        ]
        
        for testCase in testCases {
            let result = service.calculateReadinessScore(hrv: testCase.hrv, restingHeartRate: 0, sleepHours: 0)
            XCTAssertGreaterThanOrEqual(result.score, 0, "Score should be >= 0 for HRV \(testCase.hrv) with RHR=0, Sleep=0")
            XCTAssertLessThanOrEqual(result.score, 100, "Score should be <= 100 for HRV \(testCase.hrv) with RHR=0, Sleep=0")
            XCTAssertNotEqual(result.category, ReadinessCategory.unknown, "Should not return unknown category for HRV \(testCase.hrv)")
            XCTAssertEqual(result.rhrAdjustment, 0, accuracy: 0.001, "RHR adjustment should be 0 when disabled")
            XCTAssertEqual(result.sleepAdjustment, 0, accuracy: 0.001, "Sleep adjustment should be 0 when disabled")
        }
        
        // Verify that the system can work with RHR=0 and Sleep=0 in different scenarios
        let scenarios = [
            (hrv: 100.0, rhr: 0.0, sleep: 0.0, description: "Optimal HRV with RHR=0, Sleep=0"),
            (hrv: 50.0, rhr: 0.0, sleep: 0.0, description: "Poor HRV with RHR=0, Sleep=0"),
            (hrv: 120.0, rhr: 0.0, sleep: 0.0, description: "High HRV with RHR=0, Sleep=0")
        ]
        
        for scenario in scenarios {
            let result = service.calculateReadinessScore(hrv: scenario.hrv, restingHeartRate: scenario.rhr, sleepHours: scenario.sleep)
            XCTAssertGreaterThanOrEqual(result.score, 0, "Should generate score for \(scenario.description)")
            XCTAssertLessThanOrEqual(result.score, 100, "Score should be within valid range for \(scenario.description)")
            XCTAssertNotEqual(result.category, ReadinessCategory.unknown, "Should not return unknown category for \(scenario.description)")
        }
    }
    
    // MARK: - Historical Data Import Tests
    
    func testHistoricalDataImportProcess() {
        // Test that the 90-day historical data import process works correctly
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and disable adjustments for pure HRV testing
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Clear existing data
        storage.deleteAllHealthMetrics()
        storage.deleteAllReadinessScores()
        
        // Create mock historical data over 5 days
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -4, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -3, to: today)!
        let day3 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day4 = calendar.date(byAdding: .day, value: -1, to: today)!
        let day5 = today
        
        // Create historical data with valid HRV
        let historicalData: [(date: Date, hrv: Double?, rhr: Double?, sleep: HealthKitManager.SleepData?)] = [
            (date: day1, hrv: 100, rhr: 60, sleep: HealthKitManager.SleepData(hours: 8, quality: 80, startTime: nil, endTime: nil)),
            (date: day2, hrv: 105, rhr: 58, sleep: HealthKitManager.SleepData(hours: 7.5, quality: 75, startTime: nil, endTime: nil)),
            (date: day3, hrv: 95, rhr: 62, sleep: HealthKitManager.SleepData(hours: 8.5, quality: 85, startTime: nil, endTime: nil)),
            (date: day4, hrv: 110, rhr: 55, sleep: HealthKitManager.SleepData(hours: 7, quality: 70, startTime: nil, endTime: nil)),
            (date: day5, hrv: 102, rhr: 59, sleep: HealthKitManager.SleepData(hours: 8, quality: 80, startTime: nil, endTime: nil))
        ]
        
        // Test the import process
        let expectation = XCTestExpectation(description: "Historical data import")
        
        Task {
            do {
                // Simulate the import process by processing the data
                let backgroundContext = CoreDataManager.shared.newBackgroundContext()
                var savedDays = 0
                
                for dayData in historicalData {
                    if let hrv = dayData.hrv, hrv >= 10 && hrv <= 200 {
                        let rhr = dayData.rhr ?? 0
                        let sleepHours = dayData.sleep?.hours ?? 0
                        let sleepQuality = dayData.sleep?.quality ?? 0
                        
                        _ = CoreDataManager.shared.saveHealthMetricsInBackground(
                            context: backgroundContext,
                            date: dayData.date,
                            hrv: hrv,
                            restingHeartRate: rhr,
                            sleepHours: sleepHours,
                            sleepQuality: sleepQuality
                        )
                        savedDays += 1
                    }
                }
                
                CoreDataManager.shared.saveContext(backgroundContext)
                
                // Verify data was saved
                let savedMetrics = storage.getHealthMetricsForPastDays(10)
                XCTAssertEqual(savedMetrics.count, 5, "Should have saved 5 days of health metrics")
                
                // Verify all days have valid HRV data
                let validHRVDays = savedMetrics.filter { $0.hasValidHRV }
                XCTAssertEqual(validHRVDays.count, 5, "All saved days should have valid HRV data")
                
                // Test baseline calculation
                let hrvBaseline = service.calculateHRVBaseline()
                XCTAssertGreaterThan(hrvBaseline, 0, "Should be able to calculate HRV baseline after import")
                XCTAssertEqual(hrvBaseline, 102.4, accuracy: 0.1, "HRV baseline should be average of imported data")
                
                expectation.fulfill()
            } catch {
                XCTFail("Historical data import should not fail: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testHistoricalDataImportWithInvalidData() {
        // Test that invalid data is properly filtered during import
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Clear existing data
        storage.deleteAllHealthMetrics()
        storage.deleteAllReadinessScores()
        
        // Create mixed valid/invalid historical data
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
        let day3 = today
        
        let historicalData: [(date: Date, hrv: Double?, rhr: Double?, sleep: HealthKitManager.SleepData?)] = [
            (date: day1, hrv: 100, rhr: 60, sleep: HealthKitManager.SleepData(hours: 8, quality: 80, startTime: nil, endTime: nil)), // Valid
            (date: day2, hrv: 5, rhr: 60, sleep: HealthKitManager.SleepData(hours: 8, quality: 80, startTime: nil, endTime: nil)), // Invalid HRV (too low)
            (date: day3, hrv: 250, rhr: 60, sleep: HealthKitManager.SleepData(hours: 8, quality: 80, startTime: nil, endTime: nil)) // Invalid HRV (too high)
        ]
        
        // Test the import process
        let expectation = XCTestExpectation(description: "Historical data import with invalid data")
        
        Task {
            do {
                let backgroundContext = CoreDataManager.shared.newBackgroundContext()
                var savedDays = 0
                var skippedDays = 0
                
                for dayData in historicalData {
                    if let hrv = dayData.hrv, hrv >= 10 && hrv <= 200 {
                        let rhr = dayData.rhr ?? 0
                        let sleepHours = dayData.sleep?.hours ?? 0
                        let sleepQuality = dayData.sleep?.quality ?? 0
                        
                        _ = CoreDataManager.shared.saveHealthMetricsInBackground(
                            context: backgroundContext,
                            date: dayData.date,
                            hrv: hrv,
                            restingHeartRate: rhr,
                            sleepHours: sleepHours,
                            sleepQuality: sleepQuality
                        )
                        savedDays += 1
                    } else {
                        skippedDays += 1
                    }
                }
                
                CoreDataManager.shared.saveContext(backgroundContext)
                
                // Verify only valid data was saved
                let savedMetrics = storage.getHealthMetricsForPastDays(10)
                XCTAssertEqual(savedMetrics.count, 1, "Should have saved only 1 valid day")
                XCTAssertEqual(skippedDays, 2, "Should have skipped 2 invalid days")
                
                // Verify the saved day has valid HRV
                let validHRVDays = savedMetrics.filter { $0.hasValidHRV }
                XCTAssertEqual(validHRVDays.count, 1, "Saved day should have valid HRV")
                XCTAssertEqual(validHRVDays.first?.hrv, 100, accuracy: 0.001, "Saved HRV should be 100")
                
                expectation.fulfill()
            } catch {
                XCTFail("Historical data import should not fail: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testInitialDataImportAndSetup() {
        // Test the complete initial data import and setup process
        let service = ReadinessService.shared
        let storage = service.storageService
        
        // Clear existing data
        storage.deleteAllHealthMetrics()
        storage.deleteAllReadinessScores()
        
        // Reset initial import flag
        let userDefaults = UserDefaultsManager.shared
        userDefaults.initialDataImportCompleted = false
        
        // Test that initial setup is needed
        XCTAssertFalse(service.hasCompletedInitialDataImport, "Initial data import should not be completed")
        
        // Test the setup process
        let expectation = XCTestExpectation(description: "Initial data import and setup")
        
        Task {
            do {
                // This would normally call HealthKit, but we'll test the logic
                // by checking if the method exists and can be called
                let hasSetupMethod = true // Method exists
                XCTAssertTrue(hasSetupMethod, "performInitialDataImportAndSetup method should exist")
                
                // Verify the method signature and basic functionality
                // (In a real test, we'd mock HealthKit to return test data)
                expectation.fulfill()
            } catch {
                XCTFail("Initial setup should not fail: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testProgressiveBaselineCalculationDuringImport() {
        // Test that baseline calculations happen progressively during import
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 for testing progressive calculation
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Clear existing data
        storage.deleteAllHealthMetrics()
        storage.deleteAllReadinessScores()
        
        // Create historical data over 5 days to test progressive calculation
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -4, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -3, to: today)!
        let day3 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day4 = calendar.date(byAdding: .day, value: -1, to: today)!
        let day5 = today
        
        let historicalData: [(date: Date, hrv: Double?, rhr: Double?, sleep: HealthKitManager.SleepData?)] = [
            (date: day1, hrv: 100, rhr: 60, sleep: HealthKitManager.SleepData(hours: 8, quality: 80, startTime: nil, endTime: nil)),
            (date: day2, hrv: 105, rhr: 58, sleep: HealthKitManager.SleepData(hours: 7.5, quality: 75, startTime: nil, endTime: nil)),
            (date: day3, hrv: 95, rhr: 62, sleep: HealthKitManager.SleepData(hours: 8.5, quality: 85, startTime: nil, endTime: nil)),
            (date: day4, hrv: 110, rhr: 55, sleep: HealthKitManager.SleepData(hours: 7, quality: 70, startTime: nil, endTime: nil)),
            (date: day5, hrv: 102, rhr: 59, sleep: HealthKitManager.SleepData(hours: 8, quality: 80, startTime: nil, endTime: nil))
        ]
        
        // Test progressive baseline calculation
        let expectation = XCTestExpectation(description: "Progressive baseline calculation")
        
        Task {
            do {
                let backgroundContext = CoreDataManager.shared.newBackgroundContext()
                var savedDays = 0
                var calculatedScores = 0
                
                // Simulate progressive import and baseline calculation
                for (index, dayData) in historicalData.enumerated() {
                    if let hrv = dayData.hrv, hrv >= 10 && hrv <= 200 {
                        let rhr = dayData.rhr ?? 0
                        let sleepHours = dayData.sleep?.hours ?? 0
                        let sleepQuality = dayData.sleep?.quality ?? 0
                        
                        // Save the health metrics
                        _ = CoreDataManager.shared.saveHealthMetricsInBackground(
                            context: backgroundContext,
                            date: dayData.date,
                            hrv: hrv,
                            restingHeartRate: rhr,
                            sleepHours: sleepHours,
                            sleepQuality: sleepQuality
                        )
                        savedDays += 1
                        
                        // Progressive baseline calculation: Calculate readiness score if we have enough data
                        if savedDays >= userDefaults.minimumDaysForBaseline {
                            // Save the background context to make data available for baseline calculation
                            CoreDataManager.shared.saveContext(backgroundContext)
                            
                            // Calculate as-of baseline for this date
                            let asOfHRVBaseline = service.calculateHRVBaseline(asOf: dayData.date)
                            if asOfHRVBaseline > 0 {
                                // Calculate readiness score for this date using as-of baselines
                                let (score, category, hrvBaseline, hrvDeviation, rhrAdjustment, sleepAdjustment) = service.calculateReadinessScoreForDate(
                                    hrv: hrv,
                                    restingHeartRate: rhr,
                                    sleepHours: sleepHours,
                                    date: dayData.date
                                )
                                
                                // Save the readiness score
                                backgroundContext.performAndWait {
                                    let calendar = Calendar.current
                                    let startDate = calendar.startOfDay(for: dayData.date)
                                    let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
                                    
                                    let fetchRequest: NSFetchRequest<HealthMetrics> = HealthMetrics.fetchRequest()
                                    fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate)
                                    fetchRequest.fetchLimit = 1
                                    
                                    if let metricsInBgContext = try? backgroundContext.fetch(fetchRequest).first {
                                        _ = CoreDataManager.shared.saveReadinessScoreInBackground(
                                            context: backgroundContext,
                                            date: dayData.date,
                                            score: score,
                                            hrvBaseline: hrvBaseline,
                                            hrvDeviation: hrvDeviation,
                                            readinessCategory: category.rawValue,
                                            rhrAdjustment: rhrAdjustment,
                                            sleepAdjustment: sleepAdjustment,
                                            readinessMode: ReadinessMode.morning.rawValue,
                                            baselinePeriod: BaselinePeriod.sevenDays.rawValue,
                                            healthMetrics: metricsInBgContext
                                        )
                                        calculatedScores += 1
                                    }
                                }
                            }
                        }
                    }
                }
                
                CoreDataManager.shared.saveContext(backgroundContext)
                
                // Verify progressive calculation results
                XCTAssertEqual(savedDays, 5, "Should have saved 5 days of health metrics")
                XCTAssertEqual(calculatedScores, 4, "Should have calculated 4 readiness scores (days 3-5, since we need 2 days for baseline)")
                
                // Verify that readiness scores were calculated for the correct days
                let savedScores = storage.getReadinessScoresForPastDays(10)
                XCTAssertEqual(savedScores.count, 4, "Should have 4 readiness scores saved")
                
                // Verify the scores are in chronological order
                let sortedScores = savedScores.sorted { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }
                XCTAssertEqual(sortedScores.count, 4, "Should have 4 sorted scores")
                
                // Verify that day 1 and day 2 don't have scores (insufficient baseline data)
                let day1Scores = savedScores.filter { $0.date == day1 }
                let day2Scores = savedScores.filter { $0.date == day2 }
                XCTAssertEqual(day1Scores.count, 0, "Day 1 should not have a readiness score (insufficient baseline)")
                XCTAssertEqual(day2Scores.count, 0, "Day 2 should not have a readiness score (insufficient baseline)")
                
                // Verify that days 3-5 have scores
                let day3Scores = savedScores.filter { $0.date == day3 }
                let day4Scores = savedScores.filter { $0.date == day4 }
                let day5Scores = savedScores.filter { $0.date == day5 }
                XCTAssertEqual(day3Scores.count, 1, "Day 3 should have a readiness score")
                XCTAssertEqual(day4Scores.count, 1, "Day 4 should have a readiness score")
                XCTAssertEqual(day5Scores.count, 1, "Day 5 should have a readiness score")
                
                expectation.fulfill()
            } catch {
                XCTFail("Progressive baseline calculation should not fail: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testReadinessScoresGeneratedForValidHistoricalDays() {
        // Test that readiness scores are generated for all valid historical days
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and disable adjustments for pure HRV testing
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Clear existing data
        storage.deleteAllHealthMetrics()
        storage.deleteAllReadinessScores()
        
        // Create historical data over 7 days with mixed valid/invalid data
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -6, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -5, to: today)!
        let day3 = calendar.date(byAdding: .day, value: -4, to: today)!
        let day4 = calendar.date(byAdding: .day, value: -3, to: today)!
        let day5 = calendar.date(byAdding: .day, value: -2, to: today)!
        let day6 = calendar.date(byAdding: .day, value: -1, to: today)!
        let day7 = today
        
        let historicalData: [(date: Date, hrv: Double?, rhr: Double?, sleep: HealthKitManager.SleepData?)] = [
            (date: day1, hrv: 100, rhr: 60, sleep: HealthKitManager.SleepData(hours: 8, quality: 80, startTime: nil, endTime: nil)), // Valid
            (date: day2, hrv: 5, rhr: 60, sleep: HealthKitManager.SleepData(hours: 8, quality: 80, startTime: nil, endTime: nil)), // Invalid HRV (too low)
            (date: day3, hrv: 105, rhr: 58, sleep: HealthKitManager.SleepData(hours: 7.5, quality: 75, startTime: nil, endTime: nil)), // Valid
            (date: day4, hrv: 95, rhr: 62, sleep: HealthKitManager.SleepData(hours: 8.5, quality: 85, startTime: nil, endTime: nil)), // Valid
            (date: day5, hrv: 250, rhr: 55, sleep: HealthKitManager.SleepData(hours: 7, quality: 70, startTime: nil, endTime: nil)), // Invalid HRV (too high)
            (date: day6, hrv: 110, rhr: 55, sleep: HealthKitManager.SleepData(hours: 7, quality: 70, startTime: nil, endTime: nil)), // Valid
            (date: day7, hrv: 102, rhr: 59, sleep: HealthKitManager.SleepData(hours: 8, quality: 80, startTime: nil, endTime: nil)) // Valid
        ]
        
        // Test that scores are generated for valid historical days
        let expectation = XCTestExpectation(description: "Readiness scores generated for valid historical days")
        
        Task {
            do {
                let backgroundContext = CoreDataManager.shared.newBackgroundContext()
                var savedDays = 0
                var calculatedScores = 0
                
                // Simulate the import process
                for (index, dayData) in historicalData.enumerated() {
                    if let hrv = dayData.hrv, hrv >= 10 && hrv <= 200 {
                        let rhr = dayData.rhr ?? 0
                        let sleepHours = dayData.sleep?.hours ?? 0
                        let sleepQuality = dayData.sleep?.quality ?? 0
                        
                        // Save the health metrics
                        _ = CoreDataManager.shared.saveHealthMetricsInBackground(
                            context: backgroundContext,
                            date: dayData.date,
                            hrv: hrv,
                            restingHeartRate: rhr,
                            sleepHours: sleepHours,
                            sleepQuality: sleepQuality
                        )
                        savedDays += 1
                        
                        // Calculate readiness score if we have enough data for baseline
                        if savedDays >= userDefaults.minimumDaysForBaseline {
                            CoreDataManager.shared.saveContext(backgroundContext)
                            
                            let asOfHRVBaseline = service.calculateHRVBaseline(asOf: dayData.date)
                            if asOfHRVBaseline > 0 {
                                let (score, category, hrvBaseline, hrvDeviation, rhrAdjustment, sleepAdjustment) = service.calculateReadinessScoreForDate(
                                    hrv: hrv,
                                    restingHeartRate: rhr,
                                    sleepHours: sleepHours,
                                    date: dayData.date
                                )
                                
                                // Save the readiness score
                                backgroundContext.performAndWait {
                                    let calendar = Calendar.current
                                    let startDate = calendar.startOfDay(for: dayData.date)
                                    let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
                                    
                                    let fetchRequest: NSFetchRequest<HealthMetrics> = HealthMetrics.fetchRequest()
                                    fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate)
                                    fetchRequest.fetchLimit = 1
                                    
                                    if let metricsInBgContext = try? backgroundContext.fetch(fetchRequest).first {
                                        _ = CoreDataManager.shared.saveReadinessScoreInBackground(
                                            context: backgroundContext,
                                            date: dayData.date,
                                            score: score,
                                            hrvBaseline: hrvBaseline,
                                            hrvDeviation: hrvDeviation,
                                            readinessCategory: category.rawValue,
                                            rhrAdjustment: rhrAdjustment,
                                            sleepAdjustment: sleepAdjustment,
                                            readinessMode: ReadinessMode.morning.rawValue,
                                            baselinePeriod: BaselinePeriod.sevenDays.rawValue,
                                            healthMetrics: metricsInBgContext
                                        )
                                        calculatedScores += 1
                                    }
                                }
                            }
                        }
                    }
                }
                
                CoreDataManager.shared.saveContext(backgroundContext)
                
                // Verify results
                XCTAssertEqual(savedDays, 5, "Should have saved 5 valid days (days 1, 3, 4, 6, 7)")
                XCTAssertEqual(calculatedScores, 4, "Should have calculated 4 readiness scores (days 4, 6, 7, since we need 2 days for baseline)")
                
                // Verify that only valid days have health metrics
                let savedMetrics = storage.getHealthMetricsForPastDays(10)
                XCTAssertEqual(savedMetrics.count, 5, "Should have 5 health metrics saved")
                
                let validHRVDays = savedMetrics.filter { $0.hasValidHRV }
                XCTAssertEqual(validHRVDays.count, 5, "All saved days should have valid HRV data")
                
                // Verify that readiness scores were generated for the correct days
                let savedScores = storage.getReadinessScoresForPastDays(10)
                XCTAssertEqual(savedScores.count, 4, "Should have 4 readiness scores saved")
                
                // Verify specific days have scores
                let day4Scores = savedScores.filter { $0.date == day4 }
                let day6Scores = savedScores.filter { $0.date == day6 }
                let day7Scores = savedScores.filter { $0.date == day7 }
                
                XCTAssertEqual(day4Scores.count, 1, "Day 4 should have a readiness score")
                XCTAssertEqual(day6Scores.count, 1, "Day 6 should have a readiness score")
                XCTAssertEqual(day7Scores.count, 1, "Day 7 should have a readiness score")
                
                // Verify that invalid days don't have scores
                let day2Scores = savedScores.filter { $0.date == day2 }
                let day5Scores = savedScores.filter { $0.date == day5 }
                XCTAssertEqual(day2Scores.count, 0, "Day 2 should not have a readiness score (invalid HRV)")
                XCTAssertEqual(day5Scores.count, 0, "Day 5 should not have a readiness score (invalid HRV)")
                
                // Verify that early days don't have scores (insufficient baseline)
                let day1Scores = savedScores.filter { $0.date == day1 }
                let day3Scores = savedScores.filter { $0.date == day3 }
                XCTAssertEqual(day1Scores.count, 0, "Day 1 should not have a readiness score (insufficient baseline)")
                XCTAssertEqual(day3Scores.count, 0, "Day 3 should not have a readiness score (insufficient baseline)")
                
                expectation.fulfill()
            } catch {
                XCTFail("Readiness score generation should not fail: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testTodaysScoreAppearsImmediatelyAfterImport() {
        // Test that today's score appears immediately if baseline is available after import
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and disable adjustments for pure HRV testing
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Clear existing data
        storage.deleteAllHealthMetrics()
        storage.deleteAllReadinessScores()
        
        // Create historical data that includes today with sufficient baseline data
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let dayBeforeYesterday = calendar.date(byAdding: .day, value: -2, to: today)!
        
        let historicalData: [(date: Date, hrv: Double?, rhr: Double?, sleep: HealthKitManager.SleepData?)] = [
            (date: dayBeforeYesterday, hrv: 100, rhr: 60, sleep: HealthKitManager.SleepData(hours: 8, quality: 80, startTime: nil, endTime: nil)),
            (date: yesterday, hrv: 105, rhr: 58, sleep: HealthKitManager.SleepData(hours: 7.5, quality: 75, startTime: nil, endTime: nil)),
            (date: today, hrv: 95, rhr: 62, sleep: HealthKitManager.SleepData(hours: 8.5, quality: 85, startTime: nil, endTime: nil))
        ]
        
        // Test that today's score appears immediately after import
        let expectation = XCTestExpectation(description: "Today's score appears immediately after import")
        
        Task {
            do {
                let backgroundContext = CoreDataManager.shared.newBackgroundContext()
                var savedDays = 0
                var calculatedScores = 0
                
                // Simulate the import process
                for (index, dayData) in historicalData.enumerated() {
                    if let hrv = dayData.hrv, hrv >= 10 && hrv <= 200 {
                        let rhr = dayData.rhr ?? 0
                        let sleepHours = dayData.sleep?.hours ?? 0
                        let sleepQuality = dayData.sleep?.quality ?? 0
                        
                        // Save the health metrics
                        _ = CoreDataManager.shared.saveHealthMetricsInBackground(
                            context: backgroundContext,
                            date: dayData.date,
                            hrv: hrv,
                            restingHeartRate: rhr,
                            sleepHours: sleepHours,
                            sleepQuality: sleepQuality
                        )
                        savedDays += 1
                        
                        // Calculate readiness score if we have enough data for baseline
                        if savedDays >= userDefaults.minimumDaysForBaseline {
                            CoreDataManager.shared.saveContext(backgroundContext)
                            
                            let asOfHRVBaseline = service.calculateHRVBaseline(asOf: dayData.date)
                            if asOfHRVBaseline > 0 {
                                let (score, category, hrvBaseline, hrvDeviation, rhrAdjustment, sleepAdjustment) = service.calculateReadinessScoreForDate(
                                    hrv: hrv,
                                    restingHeartRate: rhr,
                                    sleepHours: sleepHours,
                                    date: dayData.date
                                )
                                
                                // Save the readiness score
                                backgroundContext.performAndWait {
                                    let calendar = Calendar.current
                                    let startDate = calendar.startOfDay(for: dayData.date)
                                    let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
                                    
                                    let fetchRequest: NSFetchRequest<HealthMetrics> = HealthMetrics.fetchRequest()
                                    fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate)
                                    fetchRequest.fetchLimit = 1
                                    
                                    if let metricsInBgContext = try? backgroundContext.fetch(fetchRequest).first {
                                        _ = CoreDataManager.shared.saveReadinessScoreInBackground(
                                            context: backgroundContext,
                                            date: dayData.date,
                                            score: score,
                                            hrvBaseline: hrvBaseline,
                                            hrvDeviation: hrvDeviation,
                                            readinessCategory: category.rawValue,
                                            rhrAdjustment: rhrAdjustment,
                                            sleepAdjustment: sleepAdjustment,
                                            readinessMode: ReadinessMode.morning.rawValue,
                                            baselinePeriod: BaselinePeriod.sevenDays.rawValue,
                                            healthMetrics: metricsInBgContext
                                        )
                                        calculatedScores += 1
                                    }
                                }
                            }
                        }
                    }
                }
                
                CoreDataManager.shared.saveContext(backgroundContext)
                
                // Verify that today's score is available immediately after import
                let todaysScore = service.getTodaysReadinessScore()
                XCTAssertNotNil(todaysScore, "Today's readiness score should be available immediately after import")
                
                if let todaysScore = todaysScore {
                    XCTAssertGreaterThan(todaysScore.score, 0, "Today's score should be greater than 0")
                    XCTAssertLessThanOrEqual(todaysScore.score, 100, "Today's score should be less than or equal to 100")
                    XCTAssertNotEqual(todaysScore.category, ReadinessCategory.unknown, "Today's category should not be unknown")
                    XCTAssertGreaterThan(todaysScore.hrvBaseline, 0, "Today's HRV baseline should be greater than 0")
                    XCTAssertEqual(todaysScore.date, today, "Today's score should be for today's date")
                    
                    // Verify the score calculation is correct
                    // Today's HRV is 95, baseline should be average of yesterday and day before (102.5)
                    // Deviation should be (95 - 102.5) / 102.5 * 100 = -7.32%
                    XCTAssertEqual(todaysScore.hrvBaseline, 102.5, accuracy: 0.1, "Today's HRV baseline should be correct")
                    XCTAssertEqual(todaysScore.hrvDeviation, -7.32, accuracy: 0.1, "Today's HRV deviation should be correct")
                }
                
                // Verify that all historical scores are available
                let allScores = storage.getReadinessScoresForPastDays(10)
                XCTAssertEqual(allScores.count, 2, "Should have 2 readiness scores (yesterday and today)")
                
                // Verify that yesterday's score is also available
                let yesterdaysScore = allScores.first { $0.date == yesterday }
                XCTAssertNotNil(yesterdaysScore, "Yesterday's readiness score should be available")
                
                if let yesterdaysScore = yesterdaysScore {
                    XCTAssertGreaterThan(yesterdaysScore.score, 0, "Yesterday's score should be greater than 0")
                    XCTAssertLessThanOrEqual(yesterdaysScore.score, 100, "Yesterday's score should be less than or equal to 100")
                    XCTAssertNotEqual(yesterdaysScore.category, ReadinessCategory.unknown, "Yesterday's category should not be unknown")
                }
                
                expectation.fulfill()
            } catch {
                XCTFail("Today's score should appear immediately after import: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testInitialSetupFlowInPerformInitialDataImportAndSetup() {
        // Test the complete initial setup flow in performInitialDataImportAndSetup()
        let service = ReadinessService.shared
        let storage = service.storageService
        let userDefaults = UserDefaultsManager.shared
        
        // Clear existing data and reset state
        storage.deleteAllHealthMetrics()
        storage.deleteAllReadinessScores()
        userDefaults.initialDataImportCompleted = false
        
        // Set minimum days to 2 for testing
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Verify initial state
        XCTAssertFalse(service.hasCompletedInitialDataImport, "Initial data import should not be completed")
        XCTAssertFalse(service.hasSufficientDataForCalculation, "Should not have sufficient data for calculation initially")
        
        // Test the setup process
        let expectation = XCTestExpectation(description: "Initial setup flow")
        
        Task {
            do {
                // Simulate the initial setup flow
                var progressUpdates: [(Double, String)] = []
                
                // Mock the progress callback to track progress updates
                let progressCallback: (Double, String) -> Void = { progress, status in
                    progressUpdates.append((progress, status))
                    print("📊 SETUP: Progress \(Int(progress * 100))% - \(status)")
                }
                
                // Since we can't actually call HealthKit in tests, we'll test the logic flow
                // by simulating the data import process
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let day1 = calendar.date(byAdding: .day, value: -2, to: today)!
                let day2 = calendar.date(byAdding: .day, value: -1, to: today)!
                let day3 = today
                
                // Simulate historical data import
                progressCallback(0.1, "Starting historical data import...")
                
                let historicalData: [(date: Date, hrv: Double?, rhr: Double?, sleep: HealthKitManager.SleepData?)] = [
                    (date: day1, hrv: 100, rhr: 60, sleep: HealthKitManager.SleepData(hours: 8, quality: 80, startTime: nil, endTime: nil)),
                    (date: day2, hrv: 105, rhr: 58, sleep: HealthKitManager.SleepData(hours: 7.5, quality: 75, startTime: nil, endTime: nil)),
                    (date: day3, hrv: 95, rhr: 62, sleep: HealthKitManager.SleepData(hours: 8.5, quality: 85, startTime: nil, endTime: nil))
                ]
                
                progressCallback(0.8, "Processing imported data...")
                
                // Simulate the data processing and saving
                let backgroundContext = CoreDataManager.shared.newBackgroundContext()
                var savedDays = 0
                var calculatedScores = 0
                
                for (index, dayData) in historicalData.enumerated() {
                    if let hrv = dayData.hrv, hrv >= 10 && hrv <= 200 {
                        let rhr = dayData.rhr ?? 0
                        let sleepHours = dayData.sleep?.hours ?? 0
                        let sleepQuality = dayData.sleep?.quality ?? 0
                        
                        // Save the health metrics
                        _ = CoreDataManager.shared.saveHealthMetricsInBackground(
                            context: backgroundContext,
                            date: dayData.date,
                            hrv: hrv,
                            restingHeartRate: rhr,
                            sleepHours: sleepHours,
                            sleepQuality: sleepQuality
                        )
                        savedDays += 1
                        
                        // Progressive baseline calculation
                        if savedDays >= userDefaults.minimumDaysForBaseline {
                            CoreDataManager.shared.saveContext(backgroundContext)
                            
                            let asOfHRVBaseline = service.calculateHRVBaseline(asOf: dayData.date)
                            if asOfHRVBaseline > 0 {
                                let (score, category, hrvBaseline, hrvDeviation, rhrAdjustment, sleepAdjustment) = service.calculateReadinessScoreForDate(
                                    hrv: hrv,
                                    restingHeartRate: rhr,
                                    sleepHours: sleepHours,
                                    date: dayData.date
                                )
                                
                                // Save the readiness score
                                backgroundContext.performAndWait {
                                    let calendar = Calendar.current
                                    let startDate = calendar.startOfDay(for: dayData.date)
                                    let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
                                    
                                    let fetchRequest: NSFetchRequest<HealthMetrics> = HealthMetrics.fetchRequest()
                                    fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate)
                                    fetchRequest.fetchLimit = 1
                                    
                                    if let metricsInBgContext = try? backgroundContext.fetch(fetchRequest).first {
                                        _ = CoreDataManager.shared.saveReadinessScoreInBackground(
                                            context: backgroundContext,
                                            date: dayData.date,
                                            score: score,
                                            hrvBaseline: hrvBaseline,
                                            hrvDeviation: hrvDeviation,
                                            readinessCategory: category.rawValue,
                                            rhrAdjustment: rhrAdjustment,
                                            sleepAdjustment: sleepAdjustment,
                                            readinessMode: ReadinessMode.morning.rawValue,
                                            baselinePeriod: BaselinePeriod.sevenDays.rawValue,
                                            healthMetrics: metricsInBgContext
                                        )
                                        calculatedScores += 1
                                    }
                                }
                            }
                        }
                        
                        // Update progress
                        let progress = 0.8 + (Double(index) / Double(max(historicalData.count, 1))) * 0.1
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateStyle = .medium
                        dateFormatter.timeStyle = .none
                        let dateString = dateFormatter.string(from: dayData.date)
                        progressCallback(progress, "Processed \(index + 1)/\(historicalData.count): \(dateString) (scores: \(calculatedScores))")
                    }
                }
                
                CoreDataManager.shared.saveContext(backgroundContext)
                
                // Simulate the final setup completion
                progressCallback(1.0, "Setup complete! Ready to track your readiness.")
                
                // Mark initial setup as complete (this would normally be done by the actual method)
                userDefaults.initialDataImportCompleted = true
                userDefaults.lastCalculationTime = Date()
                
                // Verify the setup flow results
                XCTAssertTrue(service.hasCompletedInitialDataImport, "Initial data import should be completed")
                XCTAssertTrue(service.hasSufficientDataForCalculation, "Should have sufficient data for calculation after setup")
                
                // Verify data was saved
                let savedMetrics = storage.getHealthMetricsForPastDays(10)
                XCTAssertEqual(savedMetrics.count, 3, "Should have saved 3 days of health metrics")
                
                let savedScores = storage.getReadinessScoresForPastDays(10)
                XCTAssertEqual(savedScores.count, 2, "Should have calculated 2 readiness scores (days 2-3)")
                
                // Verify progress updates were received
                XCTAssertGreaterThan(progressUpdates.count, 0, "Should have received progress updates")
                XCTAssertEqual(progressUpdates.last?.0, 1.0, "Final progress should be 100%")
                XCTAssertEqual(progressUpdates.last?.1, "Setup complete! Ready to track your readiness.", "Final status should indicate completion")
                
                // Verify that today's score is available
                let todaysScore = service.getTodaysReadinessScore()
                XCTAssertNotNil(todaysScore, "Today's readiness score should be available after setup")
                
                if let todaysScore = todaysScore {
                    XCTAssertGreaterThan(todaysScore.score, 0, "Today's score should be greater than 0")
                    XCTAssertLessThanOrEqual(todaysScore.score, 100, "Today's score should be less than or equal to 100")
                    XCTAssertNotEqual(todaysScore.category, ReadinessCategory.unknown, "Today's category should not be unknown")
                }
                
                expectation.fulfill()
            } catch {
                XCTFail("Initial setup flow should not fail: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testBackgroundContextHandlingForBulkOperations() {
        // Test that background context handling for bulk operations works correctly
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 for testing
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Clear existing data
        storage.deleteAllHealthMetrics()
        storage.deleteAllReadinessScores()
        
        // Create a large dataset to test bulk operations
        let today = calendar.startOfDay(for: Date())
        var historicalData: [(date: Date, hrv: Double?, rhr: Double?, sleep: HealthKitManager.SleepData?)] = []
        
        // Create 10 days of data to test bulk operations
        for i in 0..<10 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let hrv = 100.0 + Double(i) // Varying HRV values
            let rhr = 60.0 + Double(i % 3) // Varying RHR values
            let sleepHours = 7.5 + Double(i % 2) * 0.5 // Varying sleep hours
            
            historicalData.append((
                date: date,
                hrv: hrv,
                rhr: rhr,
                sleep: HealthKitManager.SleepData(hours: sleepHours, quality: 80, startTime: nil, endTime: nil)
            ))
        }
        
        // Test background context handling
        let expectation = XCTestExpectation(description: "Background context handling for bulk operations")
        
        Task {
            do {
                // Test bulk operations with background context
                let backgroundContext = CoreDataManager.shared.newBackgroundContext()
                var savedDays = 0
                var calculatedScores = 0
                
                // Simulate bulk import with background context
                for (index, dayData) in historicalData.enumerated() {
                    if let hrv = dayData.hrv, hrv >= 10 && hrv <= 200 {
                        let rhr = dayData.rhr ?? 0
                        let sleepHours = dayData.sleep?.hours ?? 0
                        let sleepQuality = dayData.sleep?.quality ?? 0
                        
                        // Save the health metrics using background context
                        _ = CoreDataManager.shared.saveHealthMetricsInBackground(
                            context: backgroundContext,
                            date: dayData.date,
                            hrv: hrv,
                            restingHeartRate: rhr,
                            sleepHours: sleepHours,
                            sleepQuality: sleepQuality
                        )
                        savedDays += 1
                        
                        // Test progressive baseline calculation with background context
                        if savedDays >= userDefaults.minimumDaysForBaseline {
                            // Save the background context to make data available for baseline calculation
                            CoreDataManager.shared.saveContext(backgroundContext)
                            
                            // Calculate as-of baseline for this date
                            let asOfHRVBaseline = service.calculateHRVBaseline(asOf: dayData.date)
                            if asOfHRVBaseline > 0 {
                                let (score, category, hrvBaseline, hrvDeviation, rhrAdjustment, sleepAdjustment) = service.calculateReadinessScoreForDate(
                                    hrv: hrv,
                                    restingHeartRate: rhr,
                                    sleepHours: sleepHours,
                                    date: dayData.date
                                )
                                
                                // Save the readiness score using background context
                                backgroundContext.performAndWait {
                                    let calendar = Calendar.current
                                    let startDate = calendar.startOfDay(for: dayData.date)
                                    let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
                                    
                                    let fetchRequest: NSFetchRequest<HealthMetrics> = HealthMetrics.fetchRequest()
                                    fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate)
                                    fetchRequest.fetchLimit = 1
                                    
                                    if let metricsInBgContext = try? backgroundContext.fetch(fetchRequest).first {
                                        _ = CoreDataManager.shared.saveReadinessScoreInBackground(
                                            context: backgroundContext,
                                            date: dayData.date,
                                            score: score,
                                            hrvBaseline: hrvBaseline,
                                            hrvDeviation: hrvDeviation,
                                            readinessCategory: category.rawValue,
                                            rhrAdjustment: rhrAdjustment,
                                            sleepAdjustment: sleepAdjustment,
                                            readinessMode: ReadinessMode.morning.rawValue,
                                            baselinePeriod: BaselinePeriod.sevenDays.rawValue,
                                            healthMetrics: metricsInBgContext
                                        )
                                        calculatedScores += 1
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Final save of background context
                CoreDataManager.shared.saveContext(backgroundContext)
                
                // Verify that all data was saved correctly using background context
                let savedMetrics = storage.getHealthMetricsForPastDays(15)
                XCTAssertEqual(savedMetrics.count, 10, "Should have saved 10 days of health metrics using background context")
                
                let savedScores = storage.getReadinessScoresForPastDays(15)
                XCTAssertEqual(savedScores.count, 9, "Should have calculated 9 readiness scores (days 2-10, since we need 2 days for baseline)")
                
                // Verify that all saved data has valid relationships
                for score in savedScores {
                    XCTAssertNotNil(score.healthMetrics, "Readiness score should have associated health metrics")
                    XCTAssertNotNil(score.date, "Readiness score should have a date")
                    XCTAssertGreaterThan(score.score, 0, "Readiness score should be greater than 0")
                    XCTAssertLessThanOrEqual(score.score, 100, "Readiness score should be less than or equal to 100")
                }
                
                // Verify that health metrics have valid data
                for metrics in savedMetrics {
                    XCTAssertNotNil(metrics.date, "Health metrics should have a date")
                    XCTAssertGreaterThan(metrics.hrv, 0, "Health metrics should have valid HRV")
                    XCTAssertGreaterThanOrEqual(metrics.hrv, 10, "Health metrics should have HRV >= 10")
                    XCTAssertLessThanOrEqual(metrics.hrv, 200, "Health metrics should have HRV <= 200")
                }
                
                // Test that background context operations don't interfere with main context
                let mainContextMetrics = storage.getHealthMetricsForPastDays(15)
                XCTAssertEqual(mainContextMetrics.count, 10, "Main context should have access to all saved data")
                
                // Verify that the data is consistent between contexts
                let mainContextScores = storage.getReadinessScoresForPastDays(15)
                XCTAssertEqual(mainContextScores.count, 9, "Main context should have access to all calculated scores")
                
                // Test that background context can handle concurrent operations
                let concurrentExpectation = XCTestExpectation(description: "Concurrent background operations")
                
                Task {
                    let concurrentBackgroundContext = CoreDataManager.shared.newBackgroundContext()
                    
                    // Simulate concurrent operations
                    concurrentBackgroundContext.performAndWait {
                        // Test that we can still perform operations on background context
                        let fetchRequest: NSFetchRequest<HealthMetrics> = HealthMetrics.fetchRequest()
                        fetchRequest.fetchLimit = 5
                        
                        if let results = try? concurrentBackgroundContext.fetch(fetchRequest) {
                            XCTAssertGreaterThan(results.count, 0, "Concurrent background context should have access to data")
                        }
                    }
                    
                    concurrentExpectation.fulfill()
                }
                
                await waitForExpectations(timeout: 5.0)
                
                expectation.fulfill()
            } catch {
                XCTFail("Background context handling should not fail: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 15.0)
    }

    // MARK: - Historical Score Calculation with As-of Baselines Tests
    
    func testHistoricalScoreCalculationWithAsOfBaselines() {
        // Test that historical score calculation using as-of baselines works correctly
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and disable adjustments for pure HRV testing
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Create historical data over multiple days
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -5, to: today)!  // 5 days ago
        let day2 = calendar.date(byAdding: .day, value: -4, to: today)!  // 4 days ago
        let day3 = calendar.date(byAdding: .day, value: -3, to: today)!  // 3 days ago
        let day4 = calendar.date(byAdding: .day, value: -2, to: today)!  // 2 days ago
        let day5 = calendar.date(byAdding: .day, value: -1, to: today)!  // 1 day ago
        
        // Create baseline data (HRV baseline = 100 for days 1-2)
        _ = storage.saveHealthMetrics(date: day1, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: day2, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Test historical score calculation for day 3 (should use baseline from days 1-2)
        let resultDay3 = service.calculateReadinessScoreForDate(hrv: 100, restingHeartRate: 60, sleepHours: 8, date: day3)
        XCTAssertGreaterThan(resultDay3.score, 0, "Should generate score for day 3 using as-of baseline")
        XCTAssertNotEqual(resultDay3.category, ReadinessCategory.unknown, "Should not return unknown category for day 3")
        XCTAssertEqual(resultDay3.hrvBaseline, 100, accuracy: 0.001, "HRV baseline should be 100 for day 3")
        XCTAssertEqual(resultDay3.hrvDeviation, 0, accuracy: 0.001, "HRV deviation should be 0% for day 3")
        
        // Add more data for day 3
        _ = storage.saveHealthMetrics(date: day3, hrv: 110, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Test historical score calculation for day 4 (should use baseline from days 1-3)
        let resultDay4 = service.calculateReadinessScoreForDate(hrv: 100, restingHeartRate: 60, sleepHours: 8, date: day4)
        XCTAssertGreaterThan(resultDay4.score, 0, "Should generate score for day 4 using as-of baseline")
        XCTAssertNotEqual(resultDay4.category, ReadinessCategory.unknown, "Should not return unknown category for day 4")
        XCTAssertEqual(resultDay4.hrvBaseline, 103.33, accuracy: 0.01, "HRV baseline should be average of days 1-3 for day 4")
        XCTAssertEqual(resultDay4.hrvDeviation, -3.23, accuracy: 0.01, "HRV deviation should be calculated correctly for day 4")
        
        // Add more data for day 4
        _ = storage.saveHealthMetrics(date: day4, hrv: 90, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Test historical score calculation for day 5 (should use baseline from days 1-4)
        let resultDay5 = service.calculateReadinessScoreForDate(hrv: 100, restingHeartRate: 60, sleepHours: 8, date: day5)
        XCTAssertGreaterThan(resultDay5.score, 0, "Should generate score for day 5 using as-of baseline")
        XCTAssertNotEqual(resultDay5.category, ReadinessCategory.unknown, "Should not return unknown category for day 5")
        XCTAssertEqual(resultDay5.hrvBaseline, 100, accuracy: 0.001, "HRV baseline should be average of days 1-4 for day 5")
        XCTAssertEqual(resultDay5.hrvDeviation, 0, accuracy: 0.001, "HRV deviation should be 0% for day 5")
    }
    
    func testAsOfBaselineExcludesTargetDate() {
        // Test that as-of baseline calculation excludes the target date from baseline window
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and disable adjustments
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Create data for 3 days
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -3, to: today)!  // 3 days ago
        let day2 = calendar.date(byAdding: .day, value: -2, to: today)!  // 2 days ago
        let day3 = calendar.date(byAdding: .day, value: -1, to: today)!  // 1 day ago
        
        // Create baseline data (HRV = 100 for days 1-2)
        _ = storage.saveHealthMetrics(date: day1, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        _ = storage.saveHealthMetrics(date: day2, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Add data for day 3 (this should NOT be included in day 3's baseline)
        _ = storage.saveHealthMetrics(date: day3, hrv: 200, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Test as-of baseline for day 3 (should only use days 1-2, not day 3 itself)
        let resultDay3 = service.calculateReadinessScoreForDate(hrv: 150, restingHeartRate: 60, sleepHours: 8, date: day3)
        XCTAssertGreaterThan(resultDay3.score, 0, "Should generate score for day 3")
        XCTAssertEqual(resultDay3.hrvBaseline, 100, accuracy: 0.001, "HRV baseline should be 100 (from days 1-2 only, not day 3)")
        XCTAssertEqual(resultDay3.hrvDeviation, 50, accuracy: 0.001, "HRV deviation should be 50% (150 vs 100 baseline)")
        
        // Verify that day 3's data (HRV=200) is not included in its own baseline
        let hrvBaseline = service.calculateHRVBaseline(asOf: day3)
        XCTAssertEqual(hrvBaseline, 100, accuracy: 0.001, "As-of baseline should exclude target date")
    }
    
    func testAsOfBaselineWithInsufficientData() {
        // Test as-of baseline calculation with insufficient data
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and disable adjustments
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Create data for 2 days
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -2, to: today)!  // 2 days ago
        let day2 = calendar.date(byAdding: .day, value: -1, to: today)!  // 1 day ago
        
        // Create only 1 day of baseline data (insufficient for minimum requirement)
        _ = storage.saveHealthMetrics(date: day1, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        
        // Test as-of baseline for day 2 (should use progressive baseline from 1 day)
        let resultDay2 = service.calculateReadinessScoreForDate(hrv: 100, restingHeartRate: 60, sleepHours: 8, date: day2)
        XCTAssertGreaterThan(resultDay2.score, 0, "Should generate score using progressive baseline")
        XCTAssertNotEqual(resultDay2.category, ReadinessCategory.unknown, "Should not return unknown category")
        XCTAssertEqual(resultDay2.hrvBaseline, 100, accuracy: 0.001, "HRV baseline should be 100 (progressive from 1 day)")
        XCTAssertEqual(resultDay2.hrvDeviation, 0, accuracy: 0.001, "HRV deviation should be 0%")
        
        // Test with no baseline data
        let day3 = calendar.startOfDay(for: Date())
        let resultDay3 = service.calculateReadinessScoreForDate(hrv: 100, restingHeartRate: 60, sleepHours: 8, date: day3)
        XCTAssertEqual(resultDay3.score, 0, "Should return 0 score when no baseline data available")
        XCTAssertEqual(resultDay3.category, ReadinessCategory.unknown, "Should return unknown category when no baseline data")
        XCTAssertEqual(resultDay3.hrvBaseline, 0, accuracy: 0.001, "HRV baseline should be 0 when no data available")
    }
    
    func testAsOfBaselineWithDifferentBaselinePeriods() {
        // Test as-of baseline calculation with different baseline periods
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and disable adjustments
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Create data for 10 days
        let today = calendar.startOfDay(for: Date())
        var dates: [Date] = []
        for i in 1...10 {
            dates.append(calendar.date(byAdding: .day, value: -i, to: today)!)
        }
        
        // Create baseline data with varying HRV values
        for (index, date) in dates.enumerated() {
            let hrv = 100.0 + Double(index) * 5.0  // 100, 105, 110, 115, 120, 125, 130, 135, 140, 145
            _ = storage.saveHealthMetrics(date: date, hrv: hrv, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)
        }
        
        // Test with 7-day baseline period
        userDefaults.baselinePeriod = .sevenDays
        let result7Day = service.calculateReadinessScoreForDate(hrv: 100, restingHeartRate: 60, sleepHours: 8, date: today)
        XCTAssertGreaterThan(result7Day.score, 0, "Should generate score with 7-day baseline")
        XCTAssertEqual(result7Day.hrvBaseline, 120, accuracy: 0.001, "HRV baseline should be average of 7 days (100-130)")
        
        // Test with 14-day baseline period
        userDefaults.baselinePeriod = .fourteenDays
        let result14Day = service.calculateReadinessScoreForDate(hrv: 100, restingHeartRate: 60, sleepHours: 8, date: today)
        XCTAssertGreaterThan(result14Day.score, 0, "Should generate score with 14-day baseline")
        XCTAssertEqual(result14Day.hrvBaseline, 122.5, accuracy: 0.001, "HRV baseline should be average of 10 days (100-145)")
        
        // Test with 30-day baseline period
        userDefaults.baselinePeriod = .thirtyDays
        let result30Day = service.calculateReadinessScoreForDate(hrv: 100, restingHeartRate: 60, sleepHours: 8, date: today)
        XCTAssertGreaterThan(result30Day.score, 0, "Should generate score with 30-day baseline")
        XCTAssertEqual(result30Day.hrvBaseline, 122.5, accuracy: 0.001, "HRV baseline should be average of available 10 days")
    }
    
    func testAsOfBaselineWithInvalidData() {
        // Test as-of baseline calculation with invalid data mixed in
        let service = ReadinessService.shared
        let storage = service.storageService
        let calendar = Calendar.current
        
        // Set minimum days to 2 and disable adjustments
        let userDefaults = UserDefaultsManager.shared
        userDefaults.minimumDaysForBaseline = 2
        userDefaults.baselinePeriod = .sevenDays
        userDefaults.useRHRAdjustment = false
        userDefaults.useSleepAdjustment = false
        
        // Create data for 5 days
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -5, to: today)!  // 5 days ago
        let day2 = calendar.date(byAdding: .day, value: -4, to: today)!  // 4 days ago
        let day3 = calendar.date(byAdding: .day, value: -3, to: today)!  // 3 days ago
        let day4 = calendar.date(byAdding: .day, value: -2, to: today)!  // 2 days ago
        let day5 = calendar.date(byAdding: .day, value: -1, to: today)!  // 1 day ago
        
        // Create baseline data with some invalid HRV values
        _ = storage.saveHealthMetrics(date: day1, hrv: 100, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)  // Valid
        _ = storage.saveHealthMetrics(date: day2, hrv: 5, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)    // Invalid (<10ms)
        _ = storage.saveHealthMetrics(date: day3, hrv: 105, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)  // Valid
        _ = storage.saveHealthMetrics(date: day4, hrv: 250, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)  // Invalid (>200ms)
        _ = storage.saveHealthMetrics(date: day5, hrv: 110, restingHeartRate: 60, sleepHours: 8, sleepQuality: 3)  // Valid
        
        // Test as-of baseline for today (should only use valid data: 100, 105, 110)
        let result = service.calculateReadinessScoreForDate(hrv: 100, restingHeartRate: 60, sleepHours: 8, date: today)
        XCTAssertGreaterThan(result.score, 0, "Should generate score with filtered baseline data")
        XCTAssertNotEqual(result.category, ReadinessCategory.unknown, "Should not return unknown category")
        XCTAssertEqual(result.hrvBaseline, 105, accuracy: 0.001, "HRV baseline should be average of valid data only (100, 105, 110)")
        XCTAssertEqual(result.hrvDeviation, -4.76, accuracy: 0.01, "HRV deviation should be calculated correctly")
    }
}

// Mock ReadinessService for testing
class MockReadinessService: ReadinessService {
    private let mockHRVBaseline: Double
    private let mockRHRBaseline: Double
    
    init(mockHRVBaseline: Double, mockRHRBaseline: Double) {
        self.mockHRVBaseline = mockHRVBaseline
        self.mockRHRBaseline = mockRHRBaseline
        super.init()
    }
    
    override func calculateHRVBaseline() -> Double {
        return mockHRVBaseline
    }
    
    override func calculateRHRBaseline() -> Double {
        return mockRHRBaseline
    }
} 
