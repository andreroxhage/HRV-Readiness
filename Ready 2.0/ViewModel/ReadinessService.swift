import Foundation
import CoreData

enum ReadinessCategory: String, CaseIterable {
    case unknown = "Unknown"
    case optimal = "Optimal"
    case moderate = "Moderate"
    case low = "Low"
    case fatigue = "Fatigue"
    
    var range: ClosedRange<Double> {
        switch self {
        case .unknown: return 0...0
        case .optimal: return 80...100
        case .moderate: return 50...79
        case .low: return 30...49
        case .fatigue: return 0...29
        }
    }
    
    var emoji: String {
        switch self {
        case .unknown: return "❓"
        case .optimal: return "✅"
        case .moderate: return "🟡"
        case .low: return "🔴"
        case .fatigue: return "💀"
        }
    }
    
    var description: String {
        switch self {
        case .unknown: return "Not enough data to determine readiness"
        case .optimal: return "Your body is well-recovered and ready for high-intensity training."
        case .moderate: return "Your body is moderately recovered. Consider moderate-intensity training."
        case .low: return "Your body shows signs of fatigue. Consider light activity or active recovery."
        case .fatigue: return "Your body needs rest. Focus on recovery and avoid intense training."
        }
    }
}

enum ReadinessMode: String {
    case morning = "morning"
    case rolling = "rolling"
}

enum BaselinePeriod: Int, CaseIterable {
    case sevenDays = 7
    case fourteenDays = 14
    case thirtyDays = 30
    
    var description: String {
        switch self {
        case .sevenDays: return "7 days"
        case .fourteenDays: return "14 days"
        case .thirtyDays: return "30 days"
        }
    }
}

class ReadinessService {
    static let shared = ReadinessService()
    
    private let coreDataManager = CoreDataManager.shared
    private let healthKitManager = HealthKitManager.shared
    
    // UserDefaults for settings
    private let userDefaults = UserDefaults.standard
    
    // Default settings
    private let defaultBaselinePeriod: BaselinePeriod = .sevenDays
    private let defaultMinimumDaysForBaseline = 3
    
    init() {
        // Default initializer, now accessible for testing
    }
    
    // MARK: - Settings
    
    // Get the current readiness mode from UserDefaults
    var readinessMode: ReadinessMode {
        let modeString = userDefaults.string(forKey: "readinessMode") ?? ReadinessMode.morning.rawValue
        return ReadinessMode(rawValue: modeString) ?? .morning
    }
    
    // Get the baseline period from UserDefaults
    var baselinePeriod: BaselinePeriod {
        let days = userDefaults.integer(forKey: "baselinePeriod")
        return BaselinePeriod(rawValue: days) ?? defaultBaselinePeriod
    }
    
    // Get the minimum days required for baseline calculation
    var minimumDaysForBaseline: Int {
        return userDefaults.integer(forKey: "minimumDaysForBaseline") != 0 ?
            userDefaults.integer(forKey: "minimumDaysForBaseline") : defaultMinimumDaysForBaseline
    }
    
    // Whether to use RHR adjustment
    var useRHRAdjustment: Bool {
        return userDefaults.bool(forKey: "useRHRAdjustment")
    }
    
    // Whether to use sleep adjustment
    var useSleepAdjustment: Bool {
        return userDefaults.bool(forKey: "useSleepAdjustment")
    }
    
    // MARK: - Baseline Calculation
    
    // Calculate the HRV baseline for the selected period
    func calculateHRVBaseline() -> Double {
        let days = baselinePeriod.rawValue
        let healthMetrics = coreDataManager.getHealthMetricsForPastDays(days)
        
        print("DEBUG: Found \(healthMetrics.count) health metrics for HRV baseline calculation (period: \(days) days)")
        
        // If we don't have enough data, return 0
        if healthMetrics.count < minimumDaysForBaseline {
            print("DEBUG: Not enough data points for HRV baseline (need at least \(minimumDaysForBaseline), found \(healthMetrics.count))")
            return 0
        }
        
        // Remove any potentially bad data (very low HRV values that might be errors)
        let validHRVValues = healthMetrics.map { $0.hrv }.filter { $0 >= 10 }
        
        if validHRVValues.count < minimumDaysForBaseline {
            print("DEBUG: Not enough valid HRV values after filtering (need \(minimumDaysForBaseline), found \(validHRVValues.count))")
            return 0
        }
        
        print("DEBUG: Valid HRV values for baseline: \(validHRVValues)")
        
        let sum = validHRVValues.reduce(0, +)
        let average = sum / Double(validHRVValues.count)
        print("DEBUG: Calculated HRV baseline: \(average)")
        
        // Save the baseline calculation timestamp
        userDefaults.set(Date(), forKey: "lastHRVBaselineCalculation")
        
        return average
    }
    
    // Calculate the RHR baseline for the selected period
    func calculateRHRBaseline() -> Double {
        let days = baselinePeriod.rawValue
        let healthMetrics = coreDataManager.getHealthMetricsForPastDays(days)
        
        print("DEBUG: Found \(healthMetrics.count) health metrics for RHR baseline calculation (period: \(days) days)")
        
        // If we don't have enough data, return 0
        if healthMetrics.count < minimumDaysForBaseline {
            print("DEBUG: Not enough data points for RHR baseline (need at least \(minimumDaysForBaseline), found \(healthMetrics.count))")
            return 0
        }
        
        // Filter out invalid RHR values (zero, negative, or extreme values)
        let validRHRValues = healthMetrics.map { $0.restingHeartRate }.filter { $0 > 30 && $0 < 120 }
        
        if validRHRValues.count < minimumDaysForBaseline {
            print("DEBUG: Not enough valid RHR values after filtering (need \(minimumDaysForBaseline), found \(validRHRValues.count))")
            return 0
        }
        
        print("DEBUG: Valid RHR values for baseline: \(validRHRValues)")
        
        let sum = validRHRValues.reduce(0, +)
        let average = sum / Double(validRHRValues.count)
        print("DEBUG: Calculated RHR baseline: \(average)")
        
        // Save the baseline calculation timestamp
        userDefaults.set(Date(), forKey: "lastRHRBaselineCalculation")
        
        return average
    }
    
    // Calculate average resting heart rate from recent data
    private func calculateAverageRestingHeartRate() -> Double {
        // Get recent health metrics
        let recentMetrics = coreDataManager.getHealthMetricsForPastDays(baselinePeriod.rawValue)
        
        // Filter out zero values and calculate average
        let validRHRValues = recentMetrics.compactMap { $0.restingHeartRate > 0 ? $0.restingHeartRate : nil }
        
        if validRHRValues.isEmpty {
            return 0 // No valid data
        }
        
        let average = validRHRValues.reduce(0, +) / Double(validRHRValues.count)
        print("DEBUG: Average RHR from \(validRHRValues.count) days: \(average) bpm")
        return average
    }
    
    // MARK: - Data Fetching
    
    // Fetch morning HRV data (00:00-10:00) with timezone handling
    func fetchMorningHRV() async throws -> Double {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // Set the time range for morning (00:00-10:00)
        let startTime = today
        let endTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: today) ?? today
        
        // If it's after 10:00 AM, use today's morning data
        // If it's before 10:00 AM and we don't have enough data yet, use yesterday's data
        let currentHour = calendar.component(.hour, from: now)
        
        if currentHour < 10 {
            // It's before 10:00 AM, check if we have enough data for today
            let todayHRV = try await healthKitManager.fetchHRVForTimeRange(startTime: startTime, endTime: now)
            
            if todayHRV > 0 {
                return todayHRV
            } else {
                // Not enough data for today yet, use yesterday's morning data
                let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
                let yesterdayStart = yesterday
                let yesterdayEnd = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: yesterday) ?? yesterday
                
                return try await healthKitManager.fetchHRVForTimeRange(startTime: yesterdayStart, endTime: yesterdayEnd)
            }
        } else {
            // It's after 10:00 AM, use today's morning data
            return try await healthKitManager.fetchHRVForTimeRange(startTime: startTime, endTime: endTime)
        }
    }
    
    // Fetch rolling HRV data (last 6 hours)
    func fetchRollingHRV() async throws -> Double {
        let now = Date()
        let sixHoursAgo = Calendar.current.date(byAdding: .hour, value: -6, to: now) ?? now
        
        return try await healthKitManager.fetchHRVForTimeRange(startTime: sixHoursAgo, endTime: now)
    }
    
    // MARK: - Score Calculation
    
    // Calculate readiness score based on available metrics
    func calculateReadinessScore(hrv: Double, restingHeartRate: Double, sleepHours: Double) -> (score: Double, category: ReadinessCategory, hrvBaseline: Double, hrvDeviation: Double, rhrAdjustment: Double, sleepAdjustment: Double) {
        // Calculate HRV baseline for the selected time period
        let hrvBaseline = calculateHRVBaseline()
        
        print("DEBUG: Calculating readiness with HRV=\(hrv), RHR=\(restingHeartRate), Sleep=\(sleepHours), Baseline=\(hrvBaseline)")
        
        // Get user defaults for adjustments
        let useRHRAdjustment = UserDefaults.standard.bool(forKey: "useRHRAdjustment")
        let useSleepAdjustment = UserDefaults.standard.bool(forKey: "useSleepAdjustment")
        
        // Calculate HRV deviation percentage
        let hrvDeviation = hrvBaseline > 0 ? ((hrv - hrvBaseline) / hrvBaseline) * 100 : 0
        
        // Convert HRV deviation to a 0-100 score
        var baseScore: Double
        
        if hrvBaseline <= 0 {
            // No baseline available - use absolute HRV value as a fallback
            print("DEBUG: No baseline available, using absolute HRV")
            baseScore = min(100, max(0, hrv * 1.5)) // Simple linear scaling as a fallback
        } else {
            // Calculate score based on deviation from baseline
            switch hrvDeviation {
            case ...(-15):
                baseScore = 30 // Very poor
            case -15...(-10):
                baseScore = 45 // Poor
            case -10...(-5):
                baseScore = 60 // Below average
            case -5...5:
                baseScore = 70 // Average
            case 5...10:
                baseScore = 85 // Good
            case 10...:
                baseScore = 95 // Excellent
            default:
                baseScore = 70 // Fallback
            }
        }
        
        // Calculate adjustments based on other metrics
        var rhrAdjustment: Double = 0
        var sleepAdjustment: Double = 0
        
        // Only apply RHR adjustment if we have valid data and it's enabled
        if restingHeartRate > 0 && useRHRAdjustment {
            // Get historical resting heart rate data for comparison
            let recentRHR = calculateAverageRestingHeartRate()
            
            if recentRHR > 0 {
                // Calculate the deviation from recent average
                let rhrDeviation = ((restingHeartRate - recentRHR) / recentRHR) * 100
                
                // Apply adjustment based on the deviation
                switch rhrDeviation {
                case ...(-10):
                    rhrAdjustment = 5 // RHR is significantly lower - positive adjustment
                case -10...(-5):
                    rhrAdjustment = 3 // RHR is lower - small positive adjustment
                case -5...5:
                    rhrAdjustment = 0 // RHR is normal - no adjustment
                case 5...10:
                    rhrAdjustment = -3 // RHR is higher - small negative adjustment
                case 10...:
                    rhrAdjustment = -10 // RHR is significantly higher - large negative adjustment
                default:
                    rhrAdjustment = 0
                }
            }
        }
        
        // Only apply sleep adjustment if we have valid data and it's enabled
        if sleepHours > 0 && useSleepAdjustment {
            // Apply adjustment based on sleep hours
            switch sleepHours {
            case 0...4:
                sleepAdjustment = -15 // Very poor sleep
            case 4...6:
                sleepAdjustment = -5 // Below optimal sleep
            case 6...7:
                sleepAdjustment = 0 // Acceptable sleep
            case 7...9:
                sleepAdjustment = 5 // Optimal sleep
            case 9...:
                sleepAdjustment = 0 // Too much sleep - no bonus
            default:
                sleepAdjustment = 0
            }
        }
        
        // Calculate final score with adjustments
        var finalScore = baseScore + rhrAdjustment + sleepAdjustment
        
        // Clamp to 0-100 range
        finalScore = min(100, max(0, finalScore))
        
        // Determine readiness category
        let category: ReadinessCategory
        switch finalScore {
        case 0...40:
            category = .low
        case 40...70:
            category = .moderate
        case 70...100:
            category = .optimal
        default:
            category = .moderate
        }
        
        print("DEBUG: Final score: \(finalScore), Category: \(category.rawValue)")
        print("DEBUG: Base score: \(baseScore), RHR adjustment: \(rhrAdjustment), Sleep adjustment: \(sleepAdjustment)")
        
        return (finalScore, category, hrvBaseline, hrvDeviation, rhrAdjustment, sleepAdjustment)
    }
    
    // Calculate readiness score based on the selected mode
    func calculateReadinessScoreForCurrentMode(restingHeartRate: Double, sleepHours: Double) async throws -> (score: Double, category: ReadinessCategory, hrvBaseline: Double, hrvDeviation: Double, rhrAdjustment: Double, sleepAdjustment: Double) {
        let hrv: Double
        let timeRangeDescription: String
        
        do {
            switch readinessMode {
            case .morning:
                timeRangeDescription = "morning (00:00-10:00)"
                hrv = try await fetchMorningHRV()
            case .rolling:
                timeRangeDescription = "rolling (last 6 hours)"
                hrv = try await fetchRollingHRV()
            }
            
            if hrv <= 0 {
                throw ReadinessError.dataProcessingFailed(
                    component: "HRV", 
                    reason: "No HRV data available for \(timeRangeDescription) time range"
                )
            }
            
            // Calculate HRV baseline
            let hrvBaseline = calculateHRVBaseline()
            
            // If we don't have enough data for a baseline, throw specific error
            if hrvBaseline == 0 {
                let availableMetrics = coreDataManager.getHealthMetricsForPastDays(baselinePeriod.rawValue)
                throw ReadinessError.hrvBaselineNotAvailable(
                    daysAvailable: availableMetrics.count, 
                    daysNeeded: minimumDaysForBaseline
                )
            }
            
            return calculateReadinessScore(hrv: hrv, restingHeartRate: restingHeartRate, sleepHours: sleepHours)
        } catch let error as ReadinessError {
            throw error
        } catch {
            throw ReadinessError.dataProcessingFailed(
                component: "readiness data", 
                reason: error.localizedDescription
            )
        }
    }
    
    // MARK: - Data Storage
    
    // Save today's health metrics and calculate readiness score
    func processAndSaveTodaysData(hrv: Double, restingHeartRate: Double, sleepHours: Double, sleepQuality: Int) -> ReadinessScore? {
        let today = Date()
        
        print("DEBUG: Processing today's data with HRV=\(hrv), RHR=\(restingHeartRate), Sleep=\(sleepHours)h")
        
        // Check for missing or invalid data
        var missingData: [String] = []
        
        if hrv <= 0 {
            missingData.append("HRV")
        }
        
        if restingHeartRate <= 0 {
            missingData.append("Resting Heart Rate")
        }
        
        if sleepHours <= 0 {
            missingData.append("Sleep Hours")
        }
        
        if !missingData.isEmpty {
            print("DEBUG: WARNING - Missing or invalid data: \(missingData.joined(separator: ", "))")
        }
        
        // Calculate readiness score
        let (score, category, hrvBaseline, hrvDeviation, rhrAdjustment, sleepAdjustment) = calculateReadinessScore(hrv: hrv, restingHeartRate: restingHeartRate, sleepHours: sleepHours)
        
        print("DEBUG: Calculated readiness score: \(score), category: \(category.rawValue)")
        print("DEBUG: HRV baseline: \(hrvBaseline), deviation: \(hrvDeviation)%")
        
        // Save to UserDefaults for widget access
        let sharedDefaults = UserDefaults(suiteName: "group.andreroxhage.Ready-2-0")
        sharedDefaults?.set(score, forKey: "readinessScore")
        sharedDefaults?.set(category.rawValue, forKey: "readinessCategory")
        sharedDefaults?.set(readinessMode.rawValue, forKey: "readinessMode")
        sharedDefaults?.set(baselinePeriod.rawValue, forKey: "baselinePeriod")
        sharedDefaults?.set(Date(), forKey: "lastCalculationTime")
        
        // Check if we already have data for today
        if let existingMetrics = coreDataManager.getHealthMetricsForDate(today) {
            print("DEBUG: Found existing health metrics for today, updating")
            
            // Update existing metrics
            existingMetrics.hrv = hrv
            existingMetrics.restingHeartRate = restingHeartRate
            existingMetrics.sleepHours = sleepHours
            existingMetrics.sleepQuality = Int16(sleepQuality)
            
            coreDataManager.saveContext()
            
            // Check if we already have a readiness score for today
            if let existingScore = coreDataManager.getReadinessScoreForDate(today) {
                print("DEBUG: Found existing readiness score for today, updating")
                
                // Update existing score
                existingScore.score = score
                existingScore.hrvBaseline = hrvBaseline
                existingScore.hrvDeviation = hrvDeviation
                existingScore.readinessCategory = category.rawValue
                existingScore.rhrAdjustment = rhrAdjustment
                existingScore.sleepAdjustment = sleepAdjustment
                existingScore.readinessMode = readinessMode.rawValue
                
                coreDataManager.saveContext()
                return existingScore
            } else {
                print("DEBUG: No existing readiness score for today, creating new one")
                // Create new readiness score
                return coreDataManager.saveReadinessScore(
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
            print("DEBUG: No existing health metrics for today, creating new ones")
            // Save new health metrics
            let healthMetrics = coreDataManager.saveHealthMetrics(
                date: today,
                hrv: hrv,
                restingHeartRate: restingHeartRate,
                sleepHours: sleepHours,
                sleepQuality: sleepQuality
            )
            
            print("DEBUG: Creating new readiness score")
            // Save readiness score
            return coreDataManager.saveReadinessScore(
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
    
    // Process and save readiness data based on the current mode
    func processAndSaveTodaysDataForCurrentMode(restingHeartRate: Double, sleepHours: Double, sleepQuality: Int, forceRecalculation: Bool = false) async throws -> ReadinessScore? {
        let hrv: Double
        
        print("DEBUG: Processing readiness data for mode: \(readinessMode)")
        print("DEBUG: Force recalculation: \(forceRecalculation)")
        print("DEBUG: Baseline period: \(baselinePeriod.rawValue) days")
        
        // Fetch HRV data based on current mode
        switch readinessMode {
        case .morning:
            print("DEBUG: Using morning HRV calculation")
            hrv = try await fetchMorningHRV()
        case .rolling:
            print("DEBUG: Using rolling HRV calculation")
            hrv = try await fetchRollingHRV()
        }
        
        if hrv <= 0 {
            throw ReadinessError.dataProcessingFailed(
                component: "HRV",
                reason: "No HRV data available for the selected time range"
            )
        }
        
        print("DEBUG: HRV value for readiness calculation: \(hrv)")
        
        // Validate baseline data
        let hrvBaseline = calculateHRVBaseline()
        if hrvBaseline == 0 {
            let availableMetrics = coreDataManager.getHealthMetricsForPastDays(baselinePeriod.rawValue)
            throw ReadinessError.hrvBaselineNotAvailable(
                daysAvailable: availableMetrics.count,
                daysNeeded: minimumDaysForBaseline
            )
        }
        
        let today = Date()
        
        // Always recalculate when mode changes or when forced
        if forceRecalculation {
            print("DEBUG: Forcing recalculation of readiness score for mode: \(readinessMode.rawValue)")
            
            // Calculate a new score
            let (score, category, hrvBaseline, hrvDeviation, rhrAdjustment, sleepAdjustment) = 
                calculateReadinessScore(hrv: hrv, restingHeartRate: restingHeartRate, sleepHours: sleepHours)
            
            // Save to UserDefaults for widget access
            let sharedDefaults = UserDefaults(suiteName: "group.andreroxhage.Ready-2-0")
            sharedDefaults?.set(score, forKey: "readinessScore")
            sharedDefaults?.set(category.rawValue, forKey: "readinessCategory")
            sharedDefaults?.set(readinessMode.rawValue, forKey: "readinessMode")
            
            // Get or create health metrics
            let healthMetrics = coreDataManager.getHealthMetricsForDate(today) ?? 
                coreDataManager.saveHealthMetrics(
                    date: today,
                    hrv: hrv,
                    restingHeartRate: restingHeartRate,
                    sleepHours: sleepHours,
                    sleepQuality: sleepQuality
                )
            
            // Check if we already have a readiness score for today
            if let existingScore = coreDataManager.getReadinessScoreForDate(today) {
                print("DEBUG: Updating existing readiness score with new calculation")
                // Update existing score
                existingScore.score = score
                existingScore.hrvBaseline = hrvBaseline
                existingScore.hrvDeviation = hrvDeviation
                existingScore.readinessCategory = category.rawValue
                existingScore.rhrAdjustment = rhrAdjustment
                existingScore.sleepAdjustment = sleepAdjustment
                existingScore.readinessMode = readinessMode.rawValue
                
                coreDataManager.saveContext()
                return existingScore
            } else {
                print("DEBUG: Creating new readiness score")
                // Create new readiness score
                return coreDataManager.saveReadinessScore(
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
        } else {
            // Check if we already have a readiness score for today with the current mode
            if let existingScore = coreDataManager.getReadinessScoreForDate(today) {
                // If the mode is different, force a recalculation
                if existingScore.readinessMode != readinessMode.rawValue || 
                   Int(existingScore.baselinePeriod) != baselinePeriod.rawValue {
                    print("DEBUG: Existing score has different settings, forcing recalculation")
                    
                    // Calculate a new score
                    let (score, category, hrvBaseline, hrvDeviation, rhrAdjustment, sleepAdjustment) = 
                        calculateReadinessScore(hrv: hrv, restingHeartRate: restingHeartRate, sleepHours: sleepHours)
                    
                    // Save to UserDefaults for widget access
                    let sharedDefaults = UserDefaults(suiteName: "group.andreroxhage.Ready-2-0")
                    sharedDefaults?.set(score, forKey: "readinessScore")
                    sharedDefaults?.set(category.rawValue, forKey: "readinessCategory")
                    sharedDefaults?.set(readinessMode.rawValue, forKey: "readinessMode")
                    
                    // Update existing score
                    existingScore.score = score
                    existingScore.hrvBaseline = hrvBaseline
                    existingScore.hrvDeviation = hrvDeviation
                    existingScore.readinessCategory = category.rawValue
                    existingScore.rhrAdjustment = rhrAdjustment
                    existingScore.sleepAdjustment = sleepAdjustment
                    existingScore.readinessMode = readinessMode.rawValue
                    
                    coreDataManager.saveContext()
                    return existingScore
                } else {
                    print("DEBUG: Using existing score with matching settings")
                    return existingScore
                }
            }
            
            // Normal flow - use existing data if available
            return processAndSaveTodaysData(
                hrv: hrv,
                restingHeartRate: restingHeartRate,
                sleepHours: sleepHours,
                sleepQuality: sleepQuality
            )
        }
    }
    
    // MARK: - Data Access
    
    // Get readiness score for today
    func getTodaysReadinessScore() -> ReadinessScore? {
        return coreDataManager.getReadinessScoreForDate(Date())
    }
    
    // Get readiness score for a specific date
    func getReadinessScoreForDate(_ date: Date) -> ReadinessScore? {
        return coreDataManager.getReadinessScoreForDate(date)
    }
    
    // Get readiness scores for the past N days
    func getReadinessScoresForPastDays(_ days: Int) -> [ReadinessScore] {
        return coreDataManager.getReadinessScoresForPastDays(days)
    }
    
    // Recalculate readiness for today with current settings
    func recalculateTodaysReadiness() async throws -> ReadinessScore? {
        // Fetch the latest health data
        let restingHeartRate = try await healthKitManager.fetchRestingHeartRate()
        let sleepData = try await healthKitManager.fetchSleepData()
        
        // Force recalculation
        return try await processAndSaveTodaysDataForCurrentMode(
            restingHeartRate: restingHeartRate,
            sleepHours: sleepData.hours,
            sleepQuality: sleepData.quality,
            forceRecalculation: true
        )
    }
    
    // Recalculate readiness for a specific date
    func recalculateReadinessForDate(_ date: Date) async throws -> ReadinessScore? {
        print("DEBUG: Recalculating readiness for date: \(date)")
        
        // Use calendar for date calculations
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Fetch health data for the specific date
        var hrv: Double = 0
        var restingHeartRate: Double = 0
        var sleepData: HealthKitManager.SleepData = HealthKitManager.SleepData(hours: 0, quality: 0, startTime: nil, endTime: nil)
        var missingDataDetails: [String] = []
        var criticalMissingData: [String] = []
        
        // Get user preferences for calculations
        let useRHRInCalculation = useRHRAdjustment
        let useSleepInCalculation = useSleepAdjustment
        
        // Try to get HRV data - this is essential regardless of settings
        do {
            hrv = try await fetchHRVForDate(date)
            if hrv <= 0 {
                missingDataDetails.append("HRV")
                criticalMissingData.append("HRV") // HRV is always critical
            }
        } catch {
            print("DEBUG: Error fetching HRV: \(error.localizedDescription)")
            missingDataDetails.append("HRV (error)")
            criticalMissingData.append("HRV")
        }
        
        // Try to get resting heart rate - but only mark as critical if RHR adjustments are enabled
        do {
            restingHeartRate = try await healthKitManager.fetchRestingHeartRateForTimeRange(
                startTime: startOfDay,
                endTime: endOfDay
            )
            if restingHeartRate <= 0 {
                missingDataDetails.append("Resting Heart Rate")
                if useRHRInCalculation {
                    criticalMissingData.append("Resting Heart Rate")
                }
            }
        } catch {
            print("DEBUG: Error fetching resting heart rate: \(error.localizedDescription)")
            missingDataDetails.append("Resting Heart Rate (error)")
            if useRHRInCalculation {
                criticalMissingData.append("Resting Heart Rate")
            }
        }
        
        // Try to get sleep data - but only mark as critical if sleep adjustments are enabled
        do {
            sleepData = try await healthKitManager.fetchSleepDataForTimeRange(
                startTime: calendar.date(byAdding: .day, value: -1, to: startOfDay)!, // Look at previous day for sleep
                endTime: endOfDay
            )
            if sleepData.hours <= 0 {
                missingDataDetails.append("Sleep")
                if useSleepInCalculation {
                    criticalMissingData.append("Sleep")
                }
            }
        } catch {
            print("DEBUG: Error fetching sleep data: \(error.localizedDescription)")
            missingDataDetails.append("Sleep (error)")
            if useSleepInCalculation {
                criticalMissingData.append("Sleep")
            }
        }
        
        // If there's any missing data, log it but continue
        if !missingDataDetails.isEmpty {
            print("DEBUG: Missing data for date \(date): \(missingDataDetails.joined(separator: ", "))")
            if !criticalMissingData.isEmpty {
                print("DEBUG: Critical missing data: \(criticalMissingData.joined(separator: ", "))")
            }
        }
        
        // We need HRV data to calculate a score
        // If we couldn't get HRV data, log an error but try a fallback method
        if hrv <= 0 {
            // Try using baseline or historical average as a fallback
            let hrvBaseline = calculateHRVBaseline()
            if hrvBaseline > 0 {
                print("DEBUG: Using HRV baseline \(hrvBaseline) as fallback for missing HRV data")
                hrv = hrvBaseline * 0.85 // Apply a penalty as this is not real data
                // Remove HRV from critical missing data since we have a fallback
                if let index = criticalMissingData.firstIndex(of: "HRV") {
                    criticalMissingData.remove(at: index)
                }
            } else {
                print("DEBUG: No HRV data or baseline available for calculation")
                throw ReadinessError.historicalDataMissing(
                    date: date,
                    missingMetrics: criticalMissingData
                )
            }
        }
        
        // Calculate and save score with whatever data we have
        let score = processAndSaveTodaysData(
            hrv: hrv,
            restingHeartRate: restingHeartRate,
            sleepHours: sleepData.hours,
            sleepQuality: sleepData.quality,
            forDate: date,
            forceRecalculation: true
        )
        
        // If we have incomplete data but still calculated a score, throw a specific error
        // ONLY if the missing data is for metrics the user has enabled
        if !criticalMissingData.isEmpty && score != nil {
            throw ReadinessError.historicalDataIncomplete(
                date: date,
                missingMetrics: criticalMissingData,
                partialResult: true
            )
        }
        
        return score
    }
    
    // Fetch HRV for a specific date
    private func fetchHRVForDate(_ date: Date) async throws -> Double {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        switch readinessMode {
        case .morning:
            // Use morning window (00:00-10:00)
            let morningEnd = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: startOfDay)!
            let hrv = try await healthKitManager.fetchHRVForTimeRange(startTime: startOfDay, endTime: morningEnd)
            
            if hrv <= 0 {
                print("DEBUG: No morning HRV data available for \(date), checking full day instead")
                // As a fallback, try full day data
                let fullDayHRV = try await healthKitManager.fetchHRVForTimeRange(startTime: startOfDay, endTime: endOfDay)
                if fullDayHRV > 0 {
                    print("DEBUG: Found full day HRV data: \(fullDayHRV) ms")
                }
                return fullDayHRV
            }
            
            return hrv
            
        case .rolling:
            // Use full day data for historical dates
            let hrv = try await healthKitManager.fetchHRVForTimeRange(startTime: startOfDay, endTime: endOfDay)
            
            if hrv <= 0 {
                // If no data for this day, check for the closest previous day that has data
                print("DEBUG: No HRV data for \(date), checking previous day")
                
                // Look up to 3 days back for data
                for dayOffset in 1...3 {
                    let previousDate = calendar.date(byAdding: .day, value: -dayOffset, to: startOfDay)!
                    let previousStartOfDay = calendar.startOfDay(for: previousDate)
                    let previousEndOfDay = calendar.date(byAdding: .day, value: 1, to: previousStartOfDay)!
                    
                    print("DEBUG: Checking \(dayOffset) day(s) back: \(previousDate)")
                    let previousHRV = try await healthKitManager.fetchHRVForTimeRange(
                        startTime: previousStartOfDay,
                        endTime: previousEndOfDay
                    )
                    
                    if previousHRV > 0 {
                        print("DEBUG: Found HRV data from \(dayOffset) day(s) ago: \(previousHRV) ms")
                        return previousHRV * 0.95 // Apply a small penalty for using older data
                    }
                }
            }
            
            // If we have existing baseline data but no HRV for this day or previous days, use the baseline
            if hrv <= 0 {
                let baseline = calculateHRVBaseline()
                if baseline > 0 {
                    print("DEBUG: Using HRV baseline as fallback: \(baseline) ms")
                    return baseline * 0.9 // Apply a penalty for using baseline instead of actual data
                }
            }
            
            return hrv
        }
    }
    
    // Process and save data for a specific date
    func processAndSaveTodaysData(hrv: Double, restingHeartRate: Double, sleepHours: Double, sleepQuality: Int, forDate date: Date = Date(), forceRecalculation: Bool = false) -> ReadinessScore? {
        print("DEBUG: Processing data for date: \(date), HRV=\(hrv), RHR=\(restingHeartRate), Sleep=\(sleepHours)h")
        
        // Check for missing or invalid data
        var missingData: [String] = []
        var presentData: [String] = []
        
        if hrv <= 0 {
            missingData.append("HRV")
        } else {
            presentData.append("HRV")
        }
        
        if restingHeartRate <= 0 {
            missingData.append("Resting Heart Rate")
        } else {
            presentData.append("Resting Heart Rate")
        }
        
        if sleepHours <= 0 {
            missingData.append("Sleep Hours")
        } else {
            presentData.append("Sleep Hours")
        }
        
        if !missingData.isEmpty {
            print("DEBUG: WARNING - Missing or invalid data: \(missingData.joined(separator: ", "))")
        }
        
        if presentData.isEmpty {
            print("DEBUG: ERROR - No valid health data available for date: \(date)")
            return nil
        }
        
        // If no HRV data available, we cannot calculate a meaningful score
        if hrv <= 0 {
            print("DEBUG: Cannot calculate readiness without HRV data")
            return nil
        }
        
        // Calculate readiness score with whatever data we have
        let (score, category, hrvBaseline, hrvDeviation, rhrAdjustment, sleepAdjustment) = calculateReadinessScore(
            hrv: hrv,
            restingHeartRate: restingHeartRate,
            sleepHours: sleepHours
        )
        
        print("DEBUG: Calculated readiness score for \(date): \(score), category: \(category.rawValue)")
        
        // Save to UserDefaults for widget access (only if it's today's data)
        if Calendar.current.isDateInToday(date) {
            let sharedDefaults = UserDefaults(suiteName: "group.andreroxhage.Ready-2-0")
            sharedDefaults?.set(score, forKey: "readinessScore")
            sharedDefaults?.set(category.rawValue, forKey: "readinessCategory")
            sharedDefaults?.set(readinessMode.rawValue, forKey: "readinessMode")
            sharedDefaults?.set(baselinePeriod.rawValue, forKey: "baselinePeriod")
            sharedDefaults?.set(Date(), forKey: "lastCalculationTime")
        }
        
        // Check if we already have data for this date
        if let existingMetrics = coreDataManager.getHealthMetricsForDate(date) {
            print("DEBUG: Found existing health metrics for date: \(date), updating")
            
            // Only update metrics we have valid data for
            if forceRecalculation || hvdDataChanged(existingMetrics, hrv, restingHeartRate, sleepHours) {
                // Update metrics that are valid
                if hrv > 0 {
                    existingMetrics.hrv = hrv
                }
                
                if restingHeartRate > 0 {
                    existingMetrics.restingHeartRate = restingHeartRate
                }
                
                if sleepHours > 0 {
                    existingMetrics.sleepHours = sleepHours
                    existingMetrics.sleepQuality = Int16(sleepQuality)
                }
                
                coreDataManager.saveContext()
            }
            
            // Check if we already have a readiness score for this date
            if let existingScore = coreDataManager.getReadinessScoreForDate(date) {
                print("DEBUG: Found existing readiness score for date: \(date), updating")
                
                // Only update if forced or values are different
                if forceRecalculation || scoreDataChanged(existingScore, score, category, hrvBaseline) {
                    // Update existing score
                    existingScore.score = score
                    existingScore.hrvBaseline = hrvBaseline
                    existingScore.hrvDeviation = hrvDeviation
                    existingScore.readinessCategory = category.rawValue
                    existingScore.rhrAdjustment = rhrAdjustment
                    existingScore.sleepAdjustment = sleepAdjustment
                    existingScore.readinessMode = readinessMode.rawValue
                    existingScore.baselinePeriod = Int16(baselinePeriod.rawValue)
                    existingScore.calculationTimestamp = Date()
                    
                    coreDataManager.saveContext()
                }
                
                return existingScore
            } else {
                print("DEBUG: No existing readiness score for date: \(date), creating new one")
                // Create new readiness score
                return coreDataManager.saveReadinessScore(
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
        } else {
            print("DEBUG: No existing health metrics for date: \(date), creating new ones")
            // Save new health metrics
            let healthMetrics = coreDataManager.saveHealthMetrics(
                date: date,
                hrv: hrv,
                restingHeartRate: restingHeartRate,
                sleepHours: sleepHours,
                sleepQuality: sleepQuality
            )
            
            print("DEBUG: Creating new readiness score for date: \(date)")
            // Save readiness score
            return coreDataManager.saveReadinessScore(
                date: date,
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
    
    // Helper functions to check if data has changed
    private func hvdDataChanged(_ existingMetrics: HealthMetrics, _ hrv: Double, _ restingHeartRate: Double, _ sleepHours: Double) -> Bool {
        // Only consider valid data for comparison
        return (hrv > 0 && existingMetrics.hrv != hrv) || 
               (restingHeartRate > 0 && existingMetrics.restingHeartRate != restingHeartRate) ||
               (sleepHours > 0 && existingMetrics.sleepHours != sleepHours)
    }
    
    private func scoreDataChanged(_ existingScore: ReadinessScore, _ score: Double, _ category: ReadinessCategory, _ hrvBaseline: Double) -> Bool {
        return existingScore.score != score || 
               existingScore.readinessCategory != category.rawValue ||
               existingScore.hrvBaseline != hrvBaseline
    }
} 
