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
