import XCTest
@testable import Ready_2_0

class ReadinessServiceTests: XCTestCase {
    
    func testOptimalReadinessScore() {
        // Mock a ReadinessService with controlled baseline values
        let service = MockReadinessService(mockHRVBaseline: 50, mockRHRBaseline: 60)
        
        // Test optimal readiness (HRV within ±3% of baseline)
        let result = service.calculateReadinessScore(hrv: 51, restingHeartRate: 60, sleepHours: 8)
        
        XCTAssertEqual(result.category, .optimal)
        XCTAssertTrue(result.score >= 80 && result.score <= 100)
        XCTAssertTrue(result.hrvDeviation > -3 && result.hrvDeviation < 3)
    }
    
    func testModerateReadinessScore() {
        // Mock a ReadinessService with controlled baseline values
        let service = MockReadinessService(mockHRVBaseline: 50, mockRHRBaseline: 60)
        
        // Test moderate readiness (HRV 3-7% lower than baseline)
        let result = service.calculateReadinessScore(hrv: 47, restingHeartRate: 60, sleepHours: 8)
        
        XCTAssertEqual(result.category, .moderate)
        XCTAssertTrue(result.score >= 50 && result.score <= 79)
        XCTAssertTrue(result.hrvDeviation < -3 && result.hrvDeviation >= -7)
    }
    
    func testLowReadinessScore() {
        // Mock a ReadinessService with controlled baseline values
        let service = MockReadinessService(mockHRVBaseline: 50, mockRHRBaseline: 60)
        
        // Test low readiness (HRV 7-10% lower than baseline)
        let result = service.calculateReadinessScore(hrv: 45, restingHeartRate: 60, sleepHours: 8)
        
        XCTAssertEqual(result.category, .low)
        XCTAssertTrue(result.score >= 30 && result.score <= 49)
        XCTAssertTrue(result.hrvDeviation < -7 && result.hrvDeviation >= -10)
    }
    
    func testFatigueReadinessScore() {
        // Mock a ReadinessService with controlled baseline values
        let service = MockReadinessService(mockHRVBaseline: 50, mockRHRBaseline: 60)
        
        // Test fatigue readiness (HRV >10% lower than baseline)
        let result = service.calculateReadinessScore(hrv: 40, restingHeartRate: 60, sleepHours: 8)
        
        XCTAssertEqual(result.category, .fatigue)
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
            XCTAssertEqual(s1.category, .unknown)
        }
        if let s2 = storage.getReadinessScoreForDate(d2) {
            XCTAssertEqual(s2.hrvBaseline, 0, accuracy: 0.001)
            XCTAssertEqual(s2.category, .unknown)
        }
        if let s3 = storage.getReadinessScoreForDate(d3) {
            XCTAssertEqual(s3.hrvBaseline, 0, accuracy: 0.001)
            XCTAssertEqual(s3.category, .unknown)
        }
        
        // d4 should have baseline computed from d1..d3 (avg = 52) and not include d4's own HRV
        if let s4 = storage.getReadinessScoreForDate(d4) {
            XCTAssertEqual(s4.hrvBaseline, 52, accuracy: 0.001)
            XCTAssertNotEqual(s4.category, .unknown)
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
