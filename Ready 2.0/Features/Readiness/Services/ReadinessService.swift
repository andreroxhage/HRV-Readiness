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
    
    let storageService: ReadinessStorageService // Made public for onboarding access
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
    
    // Current day processing - simple and permissive approach that always works
    func processAndSaveTodaysDataForCurrentMode(
        restingHeartRate: Double,
        sleepHours: Double,
        sleepQuality: Int,
        forceRecalculation: Bool = false
    ) async throws -> ReadinessScore? {
        let today = Calendar.current.startOfDay(for: Date())
        
        // Step 1: Get HRV data (required)
        let timeRange = readinessMode.getTimeRange()
        print("⏰ READINESS: Using time range for \(readinessMode.rawValue) mode: \(timeRange.start) to \(timeRange.end)")
        
        let hrv: Double
        do {
            hrv = try await healthKitManager.fetchHRVForTimeRange(startTime: timeRange.start, endTime: timeRange.end)
            print("✅ READINESS: Successfully fetched HRV: \(hrv) ms")
        } catch {
            print("❌ READINESS: Failed to fetch HRV data from primary time range: \(error)")
            print("🔄 READINESS: Trying fallback: last 24 hours")
            
            // Fallback: try to get HRV data from the last 24 hours
            let now = Date()
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
            
            do {
                hrv = try await healthKitManager.fetchHRVForTimeRange(startTime: yesterday, endTime: now)
                print("✅ READINESS: Successfully fetched HRV from 24h fallback: \(hrv) ms")
            } catch {
                print("❌ READINESS: Even 24h fallback failed: \(error)")
                print("💡 READINESS: This will cause the calculation to fail with notAvailable error")
                throw ReadinessError.notAvailable
            }
        }
        
        // Debug logging
        print("🧮 READINESS: Processing data with HRV=\(hrv), RHR=\(restingHeartRate), Sleep=\(sleepHours)h")
        print("⚙️ READINESS: Settings - RHR enabled: \(useRHRAdjustment), Sleep enabled: \(useSleepAdjustment)")
        
        // Step 2: Calculate readiness score (this method handles all the logic)
        let (score, category, hrvBaseline, hrvDeviation, rhrAdjustment, sleepAdjustment) = calculateReadinessScore(
            hrv: hrv,
            restingHeartRate: restingHeartRate,
            sleepHours: sleepHours
        )
        
        print("📊 READINESS: Calculated score: \(score), category: \(category.rawValue)")
        print("📈 READINESS: HRV baseline: \(hrvBaseline), deviation: \(hrvDeviation)%")
        print("🔧 READINESS: Adjustments - RHR: \(rhrAdjustment), Sleep: \(sleepAdjustment)")
        
        // Step 3: Save the data
        let healthMetrics = storageService.saveHealthMetrics(
            date: today,
            hrv: hrv,
            restingHeartRate: restingHeartRate,
            sleepHours: sleepHours,
            sleepQuality: sleepQuality
        )
        
        // Create or update readiness score
        if let existingScore = storageService.getReadinessScoreForDate(today) {
            if forceRecalculation || abs(existingScore.score - score) > 0.1 {
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
    
    // Historical data processing - simplified
    func recalculateReadinessForDate(_ date: Date) async throws -> ReadinessScore? {
        guard let existingMetrics = storageService.getHealthMetricsForDate(date) else {
            throw ReadinessError.historicalDataMissing(date: date, missingMetrics: ["HRV"])
        }
        
        // Only require HRV data
        if !existingMetrics.hasValidHRV {
            throw ReadinessError.historicalDataIncomplete(
                date: date,
                missingMetrics: ["HRV"],
                partialResult: false
            )
        }
        
        // Calculate scores using the main calculation method
        let (score, category, hrvBaseline, hrvDeviation, rhrAdjustment, sleepAdjustment) = calculateReadinessScore(
            hrv: existingMetrics.hrv,
            restingHeartRate: existingMetrics.restingHeartRate,
            sleepHours: existingMetrics.sleepHours
        )
        
        // Update or create score
        if let existingScore = storageService.getReadinessScoreForDate(date) {
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
        let today = Calendar.current.startOfDay(for: Date())
        
        if let existingMetrics = storageService.getHealthMetricsForDate(today) {
            return try await recalculateReadinessForDate(today)
        } else {
            throw ReadinessError.notAvailable
        }
    }
    
    // MARK: - Calculation Methods
    
    // Main calculation logic - simple and permissive like the original working version
    func calculateReadinessScore(
        hrv: Double,
        restingHeartRate: Double,
        sleepHours: Double
    ) -> (score: Double, category: ReadinessCategory, hrvBaseline: Double, hrvDeviation: Double, rhrAdjustment: Double, sleepAdjustment: Double) {
        
        // Calculate HRV baseline
        let hrvBaseline = calculateHRVBaseline()
        
        print("🧮 READINESS: Calculating readiness with HRV=\(hrv), RHR=\(restingHeartRate), Sleep=\(sleepHours), Baseline=\(hrvBaseline)")
        print("⚙️ READINESS: Adjustment settings - RHR: \(useRHRAdjustment), Sleep: \(useSleepAdjustment)")
        
        // Check if we have sufficient data for baseline calculation
        if hrvBaseline <= 0 {
            print("❌ READINESS: No baseline available, cannot calculate readiness score")
            print("📊 READINESS: Need at least \(minimumDaysForBaseline) days of valid HRV data for baseline")
            // Return a neutral score that indicates insufficient data
            return (0, .unknown, 0, 0, 0, 0)
        }
        
        // Calculate HRV deviation percentage
        let hrvDeviation = ((hrv - hrvBaseline) / hrvBaseline) * 100
        
        // Convert HRV deviation to a 0-100 score using FR-3 research-backed thresholds
        var baseScore: Double
        
        // Calculate score based on FR-3 algorithm thresholds
            switch hrvDeviation {
            case ...(-10):
                // >10% below baseline → Poor/Fatigue (0-29)
                // Map very low HRV to lower end of range
                let severityFactor = min(abs(hrvDeviation) - 10, 20) / 20 // 0-1 scale for severity
                baseScore = 29 - (severityFactor * 29) // 29 down to 0 as it gets worse
                print("📉 READINESS: >10% below baseline (\(hrvDeviation)%) - Poor/Fatigue: \(baseScore)")
            case -10...(-7):
                // 7-10% below baseline → Low (30-49)
                // Linear interpolation within the range
                let rangePosition = (abs(hrvDeviation) - 7) / 3 // 0-1 within 7-10% range
                baseScore = 49 - (rangePosition * 19) // 49 down to 30
                print("📉 READINESS: 7-10% below baseline (\(hrvDeviation)%) - Low: \(baseScore)")
            case -7...(-3):
                // 3-7% below baseline → Moderate (50-79)
                // Linear interpolation within the range
                let rangePosition = (abs(hrvDeviation) - 3) / 4 // 0-1 within 3-7% range
                baseScore = 79 - (rangePosition * 29) // 79 down to 50
                print("📊 READINESS: 3-7% below baseline (\(hrvDeviation)%) - Moderate: \(baseScore)")
            case -3...3:
                // Within ±3% of baseline → Optimal (80-100)
                // Score closer to 100 when closer to baseline
                let deviationFromPerfect = abs(hrvDeviation) / 3 // 0-1 scale
                baseScore = 100 - (deviationFromPerfect * 20) // 100 down to 80
                print("✅ READINESS: Within ±3% of baseline (\(hrvDeviation)%) - Optimal: \(baseScore)")
            case 10...:
                // >10% above baseline → Supercompensation (90-100)
                // Higher scores for higher HRV
                let bonusFactor = min((hrvDeviation - 10) / 10, 1.0) // 0-1 scale for bonus
                baseScore = 90 + (bonusFactor * 10) // 90 up to 100
                print("🚀 READINESS: >10% above baseline (\(hrvDeviation)%) - Supercompensation: \(baseScore)")
            default:
                // 3-10% above baseline → Good Optimal range
                // Linear interpolation between optimal and supercompensation
                let rangePosition = (hrvDeviation - 3) / 7 // 0-1 within 3-10% range  
                baseScore = 80 + (rangePosition * 10) // 80 up to 90
                print("✅ READINESS: 3-10% above baseline (\(hrvDeviation)%) - Good Optimal: \(baseScore)")
            }
        
        // Calculate adjustments based on other metrics (only if enabled and valid)
        var rhrAdjustment: Double = 0
        var sleepAdjustment: Double = 0
        
        // Apply FR-3 RHR adjustment: >5 bpm over baseline = -10% reduction
        if useRHRAdjustment {
            print("💓 READINESS: RHR adjustment ENABLED - processing RHR data")
            if restingHeartRate > 0 {
                print("💓 READINESS: Current RHR: \(restingHeartRate) bpm")
                let rhrBaseline = calculateRHRBaseline()
                print("💓 READINESS: RHR baseline: \(rhrBaseline) bpm")
                
                if rhrBaseline > 0 {
                    // FR-3 Algorithm: If RHR >5 bpm over baseline → Reduce readiness score by 10%
                    if restingHeartRate > (rhrBaseline + 5) {
                        rhrAdjustment = -10.0  // Exactly -10% as specified in FR-3
                        print("💓 READINESS: RHR elevated >5 bpm over baseline (\(restingHeartRate) > \(rhrBaseline + 5))")
                        print("💓 READINESS: Applying -10% RHR adjustment as per FR-3")
                    } else {
                        rhrAdjustment = 0.0
                        print("💓 READINESS: RHR within normal range (≤5 bpm over baseline), no adjustment")
                    }
                    print("💓 READINESS: RHR adjustment applied: \(rhrAdjustment) points")
                } else {
                    print("💓 READINESS: RHR baseline not available (0 or insufficient data), skipping adjustment")
                    print("💓 READINESS: Need at least \(minimumDaysForBaseline) days of RHR data for baseline")
                }
            } else {
                print("💓 READINESS: RHR data not available (0 or invalid), skipping adjustment")
                print("💓 READINESS: Valid RHR range is 30-200 bpm")
            }
        } else {
            print("💓 READINESS: RHR adjustment DISABLED in settings")
        }
        
        // Apply FR-3 Sleep adjustment: <6 hours = -15% reduction
        if useSleepAdjustment {
            print("😴 READINESS: Sleep adjustment ENABLED - processing sleep data")
            if sleepHours > 0 {
                print("😴 READINESS: Current sleep: \(sleepHours) hours")
                
                // FR-3 Algorithm: If sleep <6 hours or fragmented → Reduce readiness score by 15%
                if sleepHours < 6.0 {
                    sleepAdjustment = -15.0  // Exactly -15% as specified in FR-3
                    print("😴 READINESS: Poor sleep detected (<6 hours: \(sleepHours))")
                    print("😴 READINESS: Applying -15% sleep adjustment as per FR-3")
                } else {
                    sleepAdjustment = 0.0
                    print("😴 READINESS: Sleep duration adequate (≥6 hours), no adjustment")
                }
                print("😴 READINESS: Sleep adjustment applied: \(sleepAdjustment) points")
            } else {
                print("😴 READINESS: Sleep data not available (0 or invalid), skipping adjustment")
                print("😴 READINESS: Valid sleep range is 1-12 hours")
            }
        } else {
            print("😴 READINESS: Sleep adjustment DISABLED in settings")
        }
        
        // Calculate final score
        var finalScore = baseScore + rhrAdjustment + sleepAdjustment
        finalScore = min(max(finalScore, 0), 100) // Clamp to 0-100
        
        // Determine category based on final score
        let category = ReadinessCategory.forScore(finalScore)
        
        print("🎯 READINESS: Final score: \(finalScore), category: \(category.rawValue)")
        print("📊 READINESS: Score breakdown - Base: \(baseScore), RHR adj: \(rhrAdjustment), Sleep adj: \(sleepAdjustment)")
        
        // Save the calculation timestamp
        userDefaultsManager.lastCalculationTime = Date()
        
        return (finalScore, category, hrvBaseline, hrvDeviation, rhrAdjustment, sleepAdjustment)
    }
    
    // MARK: - Baseline Calculations
    
    func calculateHRVBaseline() -> Double {
        let days = baselinePeriod.rawValue
        print("📊 READINESS: Calculating HRV baseline using \(days) days, minimum required: \(minimumDaysForBaseline)")
        
        let healthMetrics = storageService.getHealthMetricsForPastDays(days)
        print("💾 READINESS: Found \(healthMetrics.count) health metric records in past \(days) days")
        
        // If we don't have enough data, return 0
        if healthMetrics.count < minimumDaysForBaseline {
            print("❌ READINESS: Not enough health records (\(healthMetrics.count) < \(minimumDaysForBaseline))")
            return 0
        }
        
        // Debug: let's see what HRV values we have
        let allHRVValues = healthMetrics.map { $0.hrv }
        print("📈 READINESS: All HRV values: \(allHRVValues)")
        
        // Remove any potentially bad data (very low HRV values that might be errors)
        let validHRVValues = healthMetrics.map { $0.hrv }.filter { $0 >= 10 }
        print("✅ READINESS: Valid HRV values (>= 10): \(validHRVValues)")
        
        if validHRVValues.count < minimumDaysForBaseline {
            print("❌ READINESS: Not enough valid HRV values (\(validHRVValues.count) < \(minimumDaysForBaseline))")
            return 0
        }
        
        let sum = validHRVValues.reduce(0, +)
        let average = sum / Double(validHRVValues.count)
        print("🎯 READINESS: Calculated HRV baseline: \(average) ms from \(validHRVValues.count) values")
        
        // Save the baseline calculation timestamp
        userDefaultsManager.lastHRVBaselineCalculation = Date()
        
        return average
    }
    
    func calculateRHRBaseline() -> Double {
        let days = baselinePeriod.rawValue
        print("💓 READINESS: Calculating RHR baseline using \(days) days, minimum required: \(minimumDaysForBaseline)")
        
        let healthMetrics = storageService.getHealthMetricsForPastDays(days)
        print("💓 READINESS: Found \(healthMetrics.count) health metric records for RHR baseline")
        
        // If we don't have enough data, return 0
        if healthMetrics.count < minimumDaysForBaseline {
            print("❌ READINESS: Not enough health records for RHR baseline (\(healthMetrics.count) < \(minimumDaysForBaseline))")
            return 0
        }
        
        // Debug: let's see what RHR values we have
        let allRHRValues = healthMetrics.map { $0.restingHeartRate }
        print("💓 READINESS: All RHR values: \(allRHRValues)")
        
        // Remove any potentially bad data (expanded range to 30-120 for RHR)
        let validRHRValues = healthMetrics.map { $0.restingHeartRate }.filter { $0 >= 30 && $0 <= 120 }
        print("✅ READINESS: Valid RHR values (30-120 bpm): \(validRHRValues)")
        
        if validRHRValues.count < minimumDaysForBaseline {
            print("❌ READINESS: Not enough valid RHR values (\(validRHRValues.count) < \(minimumDaysForBaseline))")
            return 0
        }
        
        let sum = validRHRValues.reduce(0, +)
        let average = sum / Double(validRHRValues.count)
        print("🎯 READINESS: Calculated RHR baseline: \(average) bpm from \(validRHRValues.count) values")
        
        // Save the baseline calculation timestamp
        userDefaultsManager.lastRHRBaselineCalculation = Date()
        
        return average
    }
    
    func calculateSleepBaseline() -> Double {
        let days = baselinePeriod.rawValue
        print("😴 READINESS: Calculating sleep baseline using \(days) days, minimum required: \(minimumDaysForBaseline)")
        
        let healthMetrics = storageService.getHealthMetricsForPastDays(days)
        print("😴 READINESS: Found \(healthMetrics.count) health metric records for sleep baseline")
        
        // If we don't have enough data, return 0
        if healthMetrics.count < minimumDaysForBaseline {
            print("❌ READINESS: Not enough health records for sleep baseline (\(healthMetrics.count) < \(minimumDaysForBaseline))")
            return 0
        }
        
        // Debug: let's see what sleep values we have
        let allSleepValues = healthMetrics.map { $0.sleepHours }
        print("😴 READINESS: All sleep values: \(allSleepValues)")
        
        // Remove any potentially bad data (sleep should be between 1-12 hours)
        let validSleepValues = healthMetrics.map { $0.sleepHours }.filter { $0 > 0 && $0 <= 12 }
        print("✅ READINESS: Valid sleep values (1-12 hours): \(validSleepValues)")
        
        if validSleepValues.count < minimumDaysForBaseline {
            print("❌ READINESS: Not enough valid sleep values (\(validSleepValues.count) < \(minimumDaysForBaseline))")
            return 0
        }
        
        let sum = validSleepValues.reduce(0, +)
        let average = sum / Double(validSleepValues.count)
        print("🎯 READINESS: Calculated sleep baseline: \(average) hours from \(validSleepValues.count) values")
        
        // Save the baseline calculation timestamp
        userDefaultsManager.lastSleepBaselineCalculation = Date()
        
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
    
    // MARK: - Recalculation Methods
    
    func recalculateAllReadinessScores() async throws {
        // Get all health metrics that have some data
        let allMetrics = storageService.getHealthMetricsForPastDays(365) // Get up to 1 year
        
        for metrics in allMetrics {
            guard let date = metrics.date else { continue }
            
            // Check if this data meets minimum requirements (at least HRV)
            if metrics.hasMinimumMetrics {
                do {
                    _ = try await recalculateReadinessForDate(date)
                } catch {
                    // Continue with other dates if one fails
                    continue
                }
            }
        }
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
    
    // MARK: - Initial Setup Methods
    
    /// Imports historical data and establishes baseline for first-time app usage
    func performInitialDataImportAndSetup(progressCallback: @escaping (Double, String) -> Void) async throws {
        print("🚀 READINESS: Starting initial data import and setup")
        
        // Check if we already have sufficient data
        let existingData = storageService.getHealthMetricsForPastDays(90)
        if existingData.count >= minimumDaysForBaseline {
            print("✅ READINESS: Already have \(existingData.count) days of data, skipping import")
            progressCallback(1.0, "Historical data already available")
            return
        }
        
        // Import last 90 days of raw data from HealthKit
        progressCallback(0.1, "Starting historical data import...")
        let historicalData = try await healthKitManager.importHistoricalData(days: 90) { progress, status in
            // Convert import progress to overall progress (0.1 to 0.8)
            let overallProgress = 0.1 + (progress * 0.7)
            progressCallback(overallProgress, status)
        }
        
        progressCallback(0.8, "Processing imported data...")
        print("📊 READINESS: Imported \(historicalData.count) days of historical data")
        
        // Process and save the historical data
        var savedDays = 0
        for dayData in historicalData {
            // Only save if we have at least HRV data
            if let hrv = dayData.hrv, hrv >= 10 {
                let rhr = dayData.rhr ?? 0
                let sleepHours = dayData.sleep?.hours ?? 0
                let sleepQuality = dayData.sleep?.quality ?? 0
                
                // Save the health metrics
                _ = storageService.saveHealthMetrics(
                    date: dayData.date,
                    hrv: hrv,
                    restingHeartRate: rhr,
                    sleepHours: sleepHours,
                    sleepQuality: sleepQuality
                )
                savedDays += 1
            }
        }
        
        print("💾 READINESS: Saved \(savedDays) days of valid health data")
        progressCallback(0.9, "Establishing baseline calculations...")
        
        // Now calculate baselines and readiness scores for valid days
        let currentBaselinePeriod = baselinePeriod.rawValue
        let validMetrics = storageService.getHealthMetricsForPastDays(90)
            .filter { $0.hasValidHRV }
            .sorted { $0.date ?? Date.distantPast < $1.date ?? Date.distantPast }
        
        print("📈 READINESS: Found \(validMetrics.count) days with valid HRV data")
        
        // Only calculate readiness scores for days where we have sufficient baseline data
        var calculatedScores = 0
        for (index, metrics) in validMetrics.enumerated() {
            guard let date = metrics.date else { continue }
            
            // Check if we have enough preceding data for a baseline (at least minimumDaysForBaseline days before this date)
            let precedingData = validMetrics.prefix(index).filter { precedingMetric in
                guard let precedingDate = precedingMetric.date else { return false }
                let daysBetween = Calendar.current.dateComponents([.day], from: precedingDate, to: date).day ?? 0
                return daysBetween >= 0 && daysBetween <= currentBaselinePeriod
            }
            
            if precedingData.count >= minimumDaysForBaseline {
                // Calculate readiness score for this date
                let (score, category, hrvBaseline, hrvDeviation, rhrAdjustment, sleepAdjustment) = calculateReadinessScore(
                    hrv: metrics.hrv,
                    restingHeartRate: metrics.restingHeartRate,
                    sleepHours: metrics.sleepHours
                )
                
                // Save the readiness score
                _ = storageService.saveReadinessScore(
                    date: date,
                    score: score,
                    hrvBaseline: hrvBaseline,
                    hrvDeviation: hrvDeviation,
                    readinessCategory: category.rawValue,
                    rhrAdjustment: rhrAdjustment,
                    sleepAdjustment: sleepAdjustment,
                    readinessMode: readinessMode.rawValue,
                    baselinePeriod: baselinePeriod.rawValue,
                    healthMetrics: metrics
                )
                calculatedScores += 1
            }
        }
        
        print("🎯 READINESS: Calculated readiness scores for \(calculatedScores) days")
        progressCallback(1.0, "Setup complete! Ready to track your readiness.")
        
        // Mark initial setup as complete
        userDefaultsManager.initialDataImportCompleted = true
        userDefaultsManager.lastCalculationTime = Date()
    }
    
    /// Checks if initial data import has been completed
    var hasCompletedInitialDataImport: Bool {
        return userDefaultsManager.initialDataImportCompleted
    }
    
    /// Checks if we have sufficient data to calculate readiness scores
    var hasSufficientDataForCalculation: Bool {
        let availableData = storageService.getHealthMetricsForPastDays(baselinePeriod.rawValue)
            .filter { $0.hasValidHRV }
        return availableData.count >= minimumDaysForBaseline
    }
}