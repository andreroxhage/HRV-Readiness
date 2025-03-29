import Foundation
import CoreData

// Import project dependencies
import HealthKit

// ReadinessService
// Core business logic service for readiness calculations
// Responsible for:
// - Coordinating between data sources
// - Implementing business rules for readiness calculations
// - Managing settings and configuration
// - Not responsible for UI state or persistence details

class ReadinessService {
    static let shared = ReadinessService()
    
    // MARK: - Dependencies
    
    private let storageService: ReadinessStorageService
    private let healthKitManager: HealthKitManager
    private let userDefaultsManager: UserDefaultsManager
   
    // MARK: - Initialization
    
    init(storageService: ReadinessStorageService = ReadinessStorageService.shared,
         healthKitManager: HealthKitManager = HealthKitManager.shared,
         userDefaultsManager: UserDefaultsManager = UserDefaultsManager.shared) {
        self.storageService = storageService
        self.healthKitManager = healthKitManager
        self.userDefaultsManager = userDefaultsManager
    }
    
    // MARK: - Settings Properties
    
    // Configuration properties
    var readinessMode: ReadinessMode {
        return userDefaultsManager.readinessMode
    }
    
    var baselinePeriod: BaselinePeriod {
        return userDefaultsManager.baselinePeriod
    }
    
    var minimumDaysForBaseline: Int {
        return userDefaultsManager.minimumDaysForBaseline
    }
    
    var useRHRAdjustment: Bool {
        return userDefaultsManager.useRHRAdjustment
    }
    
    var useSleepAdjustment: Bool {
        return userDefaultsManager.useSleepAdjustment
    }
    
    // MARK: - Data Processing Methods
    
    // Current day processing
    func processAndSaveTodaysDataForCurrentMode(
        restingHeartRate: Double,
        sleepHours: Double,
        sleepQuality: Int,
        forceRecalculation: Bool = false
    ) async throws -> ReadinessScore? {
        // Get today's HRV data from HealthKit
        let timeRange = readinessMode.getTimeRange()
        let hrv = try await healthKitManager.fetchHRVForTimeRange(startTime: timeRange.start, endTime: timeRange.end)
        
        // Get the date for today
        let today = Calendar.current.startOfDay(for: Date())
        
        // Calculate HRV baseline
        let hrvBaseline = calculateHRVBaseline()
        
        // If we don't have enough data for a baseline, throw an error
        if hrvBaseline <= 0 {
            let daysAvailable = storageService.getHealthMetricsForPastDays(baselinePeriod.rawValue).count
            throw ReadinessError.hrvBaselineNotAvailable(daysAvailable: daysAvailable, daysNeeded: minimumDaysForBaseline)
        }
        
        // Calculate the readiness score
        let (score, category, _, hrvDeviation, rhrAdjustment, sleepAdjustment) = calculateReadinessScore(
            hrv: hrv,
            restingHeartRate: restingHeartRate,
            sleepHours: sleepHours
        )
        
        // Check if we already have data for today
        if let existingMetrics = storageService.getHealthMetricsForDate(today) {
            // Update the existing health metrics
            existingMetrics.hrv = hrv
            existingMetrics.restingHeartRate = restingHeartRate
            existingMetrics.sleepHours = sleepHours
            existingMetrics.sleepQuality = Int16(sleepQuality)
            
            storageService.saveContext()
            
            // Check if we already have a readiness score for today
            if let existingScore = storageService.getReadinessScoreForDate(today) {
                // Only update if forced or values are different
                if forceRecalculation || scoreDataChanged(existingScore, score, category, hrvBaseline) {
                    existingScore.score = score
                    existingScore.hrvBaseline = hrvBaseline
                    existingScore.hrvDeviation = hrvDeviation
                    existingScore.readinessCategory = category.rawValue
                    existingScore.rhrAdjustment = rhrAdjustment
                    existingScore.sleepAdjustment = sleepAdjustment
                    existingScore.readinessMode = readinessMode.rawValue
                    existingScore.baselinePeriod = Int16(baselinePeriod.rawValue)
                    existingScore.calculationTimestamp = Date()
                    
                    storageService.saveContext()
                }
                
                return existingScore
            } else {
                // Create a new readiness score with existing metrics
                return storageService.saveReadinessScore(
                    date: today,
                    score: score,
                    hrvBaseline: hrvBaseline,
                    hrvDeviation: hrvDeviation,
                    readinessCategory: category.rawValue,
                    rhrAdjustment: rhrAdjustment,
                    sleepAdjustment: sleepAdjustment,
                    readinessMode: readinessMode.rawValue,
                    baselinePeriod: baselinePeriod.rawValue,
                    healthMetrics: existingMetrics
                )
            }
        } else {
            // Create new health metrics
            let healthMetrics = storageService.saveHealthMetrics(
                date: today,
                hrv: hrv,
                restingHeartRate: restingHeartRate,
                sleepHours: sleepHours,
                sleepQuality: sleepQuality
            )
            
            // Create new readiness score
            return storageService.saveReadinessScore(
                date: today,
                score: score,
                hrvBaseline: hrvBaseline,
                hrvDeviation: hrvDeviation,
                readinessCategory: category.rawValue,
                rhrAdjustment: rhrAdjustment,
                sleepAdjustment: sleepAdjustment,
                readinessMode: readinessMode.rawValue,
                baselinePeriod: baselinePeriod.rawValue,
                healthMetrics: healthMetrics
            )
        }
    }
    
    // Historical data processing
    func recalculateReadinessForDate(_ date: Date) async throws -> ReadinessScore? {
        // Get metrics for the requested date
        guard let existingMetrics = storageService.getHealthMetricsForDate(date) else {
            throw ReadinessError.historicalDataMissing(date: date, missingMetrics: ["All metrics"])
        }
        
        // Check if metrics are valid
        if !existingMetrics.hasRequiredMetrics {
            throw ReadinessError.historicalDataIncomplete(
                date: date,
                missingMetrics: existingMetrics.missingMetricsDescription,
                partialResult: false
            )
        }
        
        // Calculate HRV baseline
        let hrvBaseline = calculateHRVBaseline()
        
        // If we don't have enough data for a baseline, throw an error
        if hrvBaseline <= 0 {
            let daysAvailable = storageService.getHealthMetricsForPastDays(baselinePeriod.rawValue).count
            throw ReadinessError.hrvBaselineNotAvailable(daysAvailable: daysAvailable, daysNeeded: minimumDaysForBaseline)
        }
        
        // Calculate readiness score
        let (score, category, _, hrvDeviation, rhrAdjustment, sleepAdjustment) = calculateReadinessScore(
            hrv: existingMetrics.hrv,
            restingHeartRate: existingMetrics.restingHeartRate,
            sleepHours: existingMetrics.sleepHours
        )
        
        // Check if we already have a readiness score for this date
        if let existingScore = storageService.getReadinessScoreForDate(date) {
            // Update the existing score
            existingScore.score = score
            existingScore.hrvBaseline = hrvBaseline
            existingScore.hrvDeviation = hrvDeviation
            existingScore.readinessCategory = category.rawValue
            existingScore.rhrAdjustment = rhrAdjustment
            existingScore.sleepAdjustment = sleepAdjustment
            existingScore.readinessMode = readinessMode.rawValue
            existingScore.baselinePeriod = Int16(baselinePeriod.rawValue)
            existingScore.calculationTimestamp = Date()
            
            storageService.saveContext()
            return existingScore
        } else {
            // Create a new readiness score
            return storageService.saveReadinessScore(
                date: date,
                score: score,
                hrvBaseline: hrvBaseline,
                hrvDeviation: hrvDeviation,
                readinessCategory: category.rawValue,
                rhrAdjustment: rhrAdjustment,
                sleepAdjustment: sleepAdjustment,
                readinessMode: readinessMode.rawValue,
                baselinePeriod: baselinePeriod.rawValue,
                healthMetrics: existingMetrics
            )
        }
    }
    
    func recalculateTodaysReadiness() async throws -> ReadinessScore? {
        // Get today's health metrics
        let today = Calendar.current.startOfDay(for: Date())
        guard let existingMetrics = storageService.getHealthMetricsForDate(today) else {
            throw ReadinessError.notAvailable
        }
        
        // Check if we have the required metrics
        if !existingMetrics.hasRequiredMetrics {
            throw ReadinessError.insufficientData(
                missingMetrics: existingMetrics.missingMetricsDescription,
                availableMetrics: existingMetrics.availableMetricsDescription
            )
        }
        
        // Recalculate readiness for today
        return try await recalculateReadinessForDate(today)
    }
    
    // MARK: - Calculation Methods
    
    // Core calculation logic
    func calculateReadinessScore(
        hrv: Double,
        restingHeartRate: Double,
        sleepHours: Double
    ) -> (score: Double, category: ReadinessCategory, hrvBaseline: Double, hrvDeviation: Double, rhrAdjustment: Double, sleepAdjustment: Double) {
        // Calculate the HRV baseline
        let hrvBaseline = calculateHRVBaseline()
        
        // If we don't have a valid baseline, return zeros
        if hrvBaseline <= 0 {
            return (0, .unknown, 0, 0, 0, 0)
        }
        
        // Calculate HRV deviation from baseline
        let hrvDeviation = (hrv - hrvBaseline) / hrvBaseline * 100
        
        // Base score calculation from HRV deviation
        var score = 50 + hrvDeviation / 2
        
        // Apply adjustments if enabled
        var rhrAdjustment: Double = 0
        var sleepAdjustment: Double = 0
        
        // Adjust for resting heart rate if enabled
        if useRHRAdjustment {
            let rhrBaseline = calculateRHRBaseline()
            if rhrBaseline > 0 {
                // Calculate RHR deviation
                let rhrDeviation = (rhrBaseline - restingHeartRate) / rhrBaseline * 100
                rhrAdjustment = rhrDeviation * 0.5 // Less weight than HRV
                score += rhrAdjustment
            }
        }
        
        // Adjust for sleep if enabled
        if useSleepAdjustment {
            // Calculate sleep adjustment
            if sleepHours < 7 {
                let sleepDeficit = 7 - sleepHours
                sleepAdjustment = -sleepDeficit * 5 // -5 points per hour under 7
            } else if sleepHours > 9 {
                let sleepExcess = sleepHours - 9
                sleepAdjustment = -sleepExcess * 2 // -2 points per hour over 9
            } else {
                sleepAdjustment = (sleepHours - 7) * 3 // Optimal sleep bonus
            }
            
            score += sleepAdjustment
        }
        
        // Clip score to valid range
        score = min(max(score, 0), 100)
        
        // Determine readiness category
        let category = ReadinessCategory.forScore(score)
        
        // Save the calculation timestamp
        userDefaultsManager.lastCalculationTime = Date()
        
        return (score, category, hrvBaseline, hrvDeviation, rhrAdjustment, sleepAdjustment)
    }
    
    // MARK: - Baseline Calculations
    
    func calculateHRVBaseline() -> Double {
        let days = baselinePeriod.rawValue
        let healthMetrics = storageService.getHealthMetricsForPastDays(days)
        
        // If we don't have enough data, return 0
        if healthMetrics.count < minimumDaysForBaseline {
            return 0
        }
        
        // Remove any potentially bad data (very low HRV values that might be errors)
        let validHRVValues = healthMetrics.map { $0.hrv }.filter { $0 >= 10 }
        
        if validHRVValues.count < minimumDaysForBaseline {
            return 0
        }
        
        let sum = validHRVValues.reduce(0, +)
        let average = sum / Double(validHRVValues.count)
        
        // Save the baseline calculation timestamp
        userDefaultsManager.lastHRVBaselineCalculation = Date()
        
        return average
    }
    
    func calculateRHRBaseline() -> Double {
        let days = baselinePeriod.rawValue
        let healthMetrics = storageService.getHealthMetricsForPastDays(days)
        
        // If we don't have enough data, return 0
        if healthMetrics.count < minimumDaysForBaseline {
            return 0
        }
        
        // Remove any potentially bad data
        let validRHRValues = healthMetrics.map { $0.restingHeartRate }.filter { $0 >= 30 && $0 <= 100 }
        
        if validRHRValues.count < minimumDaysForBaseline {
            return 0
        }
        
        let sum = validRHRValues.reduce(0, +)
        let average = sum / Double(validRHRValues.count)
        
        // Save the baseline calculation timestamp
        userDefaultsManager.lastRHRBaselineCalculation = Date()
        
        return average
    }
    
    // MARK: - Health Data Access Methods
    
    // Methods to fetch health data directly
    func fetchRestingHeartRate() async throws -> Double {
        return try await healthKitManager.fetchRestingHeartRate()
    }
    
    func fetchSleepData() async throws -> HealthKitManager.SleepData {
        return try await healthKitManager.fetchSleepData()
    }
    
    func fetchHRVForTimeRange(startTime: Date, endTime: Date) async throws -> Double {
        return try await healthKitManager.fetchHRVForTimeRange(startTime: startTime, endTime: endTime)
    }
    
    // MARK: - Data Access Methods
    
    // Methods to retrieve readiness data
    func getTodaysReadinessScore() -> ReadinessScore? {
        let today = Calendar.current.startOfDay(for: Date())
        return storageService.getReadinessScoreForDate(today)
    }
    
    func getReadinessScoreForDate(_ date: Date) -> ReadinessScore? {
        return storageService.getReadinessScoreForDate(date)
    }
    
    func getReadinessScoresForPastDays(_ days: Int) -> [ReadinessScore] {
        return storageService.getReadinessScoresForPastDays(days)
    }
    
    // MARK: - Helper Methods
    
    // Helper functions to check if data has changed
    private func scoreDataChanged(_ existingScore: ReadinessScore, _ score: Double, _ category: ReadinessCategory, _ hrvBaseline: Double) -> Bool {
        return existingScore.score != score || 
               existingScore.readinessCategory != category.rawValue ||
               existingScore.hrvBaseline != hrvBaseline
    }
} 