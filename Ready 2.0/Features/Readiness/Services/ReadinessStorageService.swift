import Foundation
import CoreData

// ReadinessStorageService
// Responsible for:
// - Managing persistence of readiness data
// - Abstracting CoreData operations for readiness feature
// - Providing data access methods with proper error handling
// - Not responsible for business logic or UI

class ReadinessStorageService {
    static let shared = ReadinessStorageService()
    
    // MARK: - Dependencies
    
    private let coreDataManager: CoreDataManager
    
    // MARK: - Initialization
    
    init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        self.coreDataManager = coreDataManager
    }
    
    // MARK: - Data Storage Methods
    
    // Save operations
    func saveReadinessScore(
        date: Date,
        score: Double,
        hrvBaseline: Double,
        hrvDeviation: Double,
        readinessCategory: String,
        rhrAdjustment: Double,
        sleepAdjustment: Double,
        readinessMode: String,
        baselinePeriod: Int,
        healthMetrics: HealthMetrics
    ) -> ReadinessScore {
        return coreDataManager.saveReadinessScore(
            date: date,
            score: score,
            hrvBaseline: hrvBaseline,
            hrvDeviation: hrvDeviation,
            readinessCategory: readinessCategory,
            rhrAdjustment: rhrAdjustment,
            sleepAdjustment: sleepAdjustment,
            readinessMode: readinessMode,
            baselinePeriod: baselinePeriod,
            healthMetrics: healthMetrics
        )
    }
    
    func saveHealthMetrics(
        date: Date,
        hrv: Double,
        restingHeartRate: Double,
        sleepHours: Double,
        sleepQuality: Int
    ) -> HealthMetrics {
        return coreDataManager.saveHealthMetrics(
            date: date,
            hrv: hrv,
            restingHeartRate: restingHeartRate,
            sleepHours: sleepHours,
            sleepQuality: sleepQuality
        )
    }
    
    // MARK: - Data Retrieval Methods
    
    // Fetch operations
    func getReadinessScoreForDate(_ date: Date) -> ReadinessScore? {
        return coreDataManager.getReadinessScoreForDate(date)
    }
    
    func getReadinessScoresForPastDays(_ days: Int) -> [ReadinessScore] {
        return coreDataManager.getReadinessScoresForPastDays(days)
    }
    
    func getHealthMetricsForDate(_ date: Date) -> HealthMetrics? {
        return coreDataManager.getHealthMetricsForDate(date)
    }
    
    func getHealthMetricsForPastDays(_ days: Int) -> [HealthMetrics] {
        print("💾 STORAGE: Fetching health metrics for past \(days) days")
        let metrics = coreDataManager.getHealthMetricsForPastDays(days)
        print("💾 STORAGE: Retrieved \(metrics.count) health metric records")
        
        // Debug: let's see what dates we have data for
        for (index, metric) in metrics.enumerated() {
            if let date = metric.date {
                print("💾 STORAGE: Record \(index + 1): Date=\(date), HRV=\(metric.hrv), RHR=\(metric.restingHeartRate)")
            } else {
                print("💾 STORAGE: Record \(index + 1): Date=nil, HRV=\(metric.hrv), RHR=\(metric.restingHeartRate)")
            }
        }
        
        return metrics
    }

    func getHealthMetrics(from startDate: Date, to endDate: Date) -> [HealthMetrics] {
        return coreDataManager.getHealthMetrics(from: startDate, to: endDate)
    }
    
    // MARK: - Utility Methods
    
    func saveContext() {
        coreDataManager.saveContext()
    }
} 
