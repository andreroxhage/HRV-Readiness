import Foundation
import CoreData

enum ReadinessCategory: String, CaseIterable {
    case optimal = "Optimal"
    case moderate = "Moderate"
    case low = "Low"
    case fatigue = "Fatigue"
    
    var range: ClosedRange<Double> {
        switch self {
        case .optimal: return 80...100
        case .moderate: return 50...79
        case .low: return 30...49
        case .fatigue: return 0...29
        }
    }
    
    var emoji: String {
        switch self {
        case .optimal: return "✅"
        case .moderate: return "🟡"
        case .low: return "🔴"
        case .fatigue: return "💀"
        }
    }
    
    var description: String {
        switch self {
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

class ReadinessService {
    static let shared = ReadinessService()
    
    private let coreDataManager = CoreDataManager.shared
    private let healthKitManager = HealthKitManager.shared
    
    // UserDefaults for settings
    private let userDefaults = UserDefaults.standard
    
    init() {
        // Default initializer, now accessible for testing
    }
    
    // Get the current readiness mode from UserDefaults
    var readinessMode: ReadinessMode {
        let modeString = userDefaults.string(forKey: "readinessMode") ?? ReadinessMode.morning.rawValue
        return ReadinessMode(rawValue: modeString) ?? .morning
    }
    
    // Calculate the 7-day rolling HRV baseline
    func calculateHRVBaseline() -> Double {
        let healthMetrics = coreDataManager.getHealthMetricsForPastDays(7)
        
        print("DEBUG: Found \(healthMetrics.count) health metrics for HRV baseline calculation")
        
        // If we don't have enough data, return 0
        if healthMetrics.count < 3 {
            print("DEBUG: Not enough data points for HRV baseline (need at least 3, found \(healthMetrics.count))")
            
            // Print what we have for debugging
            if !healthMetrics.isEmpty {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                
                print("DEBUG: Available HRV data points:")
                for (index, metric) in healthMetrics.enumerated() {
                    if let date = metric.date {
                        print("DEBUG: Data point \(index+1): Date=\(formatter.string(from: date)), HRV=\(metric.hrv)")
                    }
                }
                
                print("DEBUG: Please add more data points to calculate a baseline")
            } else {
                print("DEBUG: No HRV data points available. Please add at least 3 data points.")
            }
            
            return 0
        }
        
        // Calculate the average HRV from the past 7 days
        let hrvValues = healthMetrics.map { $0.hrv }
        
        // Check for zero or very low values that might indicate bad data
        let zeroOrLowValues = hrvValues.filter { $0 < 10 }
        if !zeroOrLowValues.isEmpty {
            print("DEBUG: WARNING - Found \(zeroOrLowValues.count) suspiciously low HRV values (< 10ms): \(zeroOrLowValues)")
        }
        
        print("DEBUG: HRV values for baseline: \(hrvValues)")
        
        let sum = hrvValues.reduce(0, +)
        let average = sum / Double(hrvValues.count)
        print("DEBUG: Calculated HRV baseline: \(average)")
        
        return average
    }
    
    // Calculate the 7-day rolling RHR baseline
    func calculateRHRBaseline() -> Double {
        let healthMetrics = coreDataManager.getHealthMetricsForPastDays(7)
        
        print("DEBUG: Found \(healthMetrics.count) health metrics for RHR baseline calculation")
        
        // If we don't have enough data, return 0
        if healthMetrics.count < 3 {
            print("DEBUG: Not enough data points for RHR baseline (need at least 3, found \(healthMetrics.count))")
            
            // Print what we have for debugging
            if !healthMetrics.isEmpty {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                
                print("DEBUG: Available RHR data points:")
                for (index, metric) in healthMetrics.enumerated() {
                    if let date = metric.date {
                        print("DEBUG: Data point \(index+1): Date=\(formatter.string(from: date)), RHR=\(metric.restingHeartRate)")
                    }
                }
                
                print("DEBUG: Please add more data points to calculate a baseline")
            } else {
                print("DEBUG: No RHR data points available. Please add at least 3 data points.")
            }
            
            return 0
        }
        
        // Calculate the average RHR from the past 7 days
        let rhrValues = healthMetrics.map { $0.restingHeartRate }
        
        // Check for zero or very high/low values that might indicate bad data
        let zeroValues = rhrValues.filter { $0 <= 0 }
        if !zeroValues.isEmpty {
            print("DEBUG: WARNING - Found \(zeroValues.count) zero or negative RHR values: \(zeroValues)")
        }
        
        let extremeValues = rhrValues.filter { $0 < 30 || $0 > 120 }
        if !extremeValues.isEmpty {
            print("DEBUG: WARNING - Found \(extremeValues.count) extreme RHR values (< 30 or > 120 bpm): \(extremeValues)")
        }
        
        print("DEBUG: RHR values for baseline: \(rhrValues)")
        
        let sum = rhrValues.reduce(0, +)
        let average = sum / Double(rhrValues.count)
        print("DEBUG: Calculated RHR baseline: \(average)")
        
        return average
    }
    
    // Fetch morning HRV data (00:00-10:00)
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
    
    // Calculate readiness score based on HRV, RHR, and sleep
    func calculateReadinessScore(hrv: Double, restingHeartRate: Double, sleepHours: Double) -> (score: Double, category: ReadinessCategory, hrvBaseline: Double, hrvDeviation: Double, rhrAdjustment: Double, sleepAdjustment: Double) {
        print("DEBUG: Calculating readiness score with HRV=\(hrv), RHR=\(restingHeartRate), Sleep=\(sleepHours)h")
        
        // Calculate HRV baseline
        let hrvBaseline = calculateHRVBaseline()
        
        // If we don't have enough data for a baseline, return a moderate score
        if hrvBaseline == 0 {
            print("DEBUG: No HRV baseline available, returning default moderate score")
            return (score: 65, category: .moderate, hrvBaseline: 0, hrvDeviation: 0, rhrAdjustment: 0, sleepAdjustment: 0)
        }
        
        // Calculate HRV deviation from baseline
        let hrvDeviation = (hrv - hrvBaseline) / hrvBaseline * 100
        print("DEBUG: HRV deviation from baseline: \(hrvDeviation)%")
        
        // Determine base score based on HRV deviation
        var baseScore: Double
        
        if abs(hrvDeviation) <= 3 {
            // ±3% of baseline → Optimal (Score: 80–100)
            baseScore = 90 // Middle of the optimal range
            print("DEBUG: HRV deviation within ±3%, setting optimal base score: \(baseScore)")
        } else if hrvDeviation < -3 && hrvDeviation >= -7 {
            // 3–7% lower → Moderate (Score: 50–79)
            baseScore = 65 // Middle of the moderate range
            print("DEBUG: HRV deviation between -3% and -7%, setting moderate base score: \(baseScore)")
        } else if hrvDeviation < -7 && hrvDeviation >= -10 {
            // 7–10% lower → Low (Score: 30–49)
            baseScore = 40 // Middle of the low range
            print("DEBUG: HRV deviation between -7% and -10%, setting low base score: \(baseScore)")
        } else if hrvDeviation < -10 {
            // >10% lower → Fatigue (Score: 0–29)
            baseScore = 15 // Middle of the fatigue range
            print("DEBUG: HRV deviation below -10%, setting fatigue base score: \(baseScore)")
        } else {
            // HRV is higher than baseline by more than 3%
            // This could indicate good recovery or potential overcompensation
            // We'll treat it as optimal but with a slightly lower score
            baseScore = 85
            print("DEBUG: HRV deviation above +3%, setting slightly reduced optimal base score: \(baseScore)")
        }
        
        // Adjust score based on RHR
        let rhrBaseline = calculateRHRBaseline()
        var rhrAdjustment = 0.0
        
        if rhrBaseline > 0 && restingHeartRate > (rhrBaseline + 5) {
            // If RHR is elevated (>5 bpm above baseline), reduce score by 10%
            rhrAdjustment = -0.1 * baseScore
            print("DEBUG: RHR elevated by \(restingHeartRate - rhrBaseline) bpm, applying adjustment: \(rhrAdjustment)")
        } else {
            print("DEBUG: No RHR adjustment needed")
        }
        
        // Adjust score based on sleep
        var sleepAdjustment = 0.0
        
        if sleepHours < 6 {
            // If sleep is poor (<6 hours), reduce score by 15%
            sleepAdjustment = -0.15 * baseScore
            print("DEBUG: Sleep below 6 hours, applying adjustment: \(sleepAdjustment)")
        } else {
            print("DEBUG: No sleep adjustment needed")
        }
        
        // Calculate final score
        let finalScore = baseScore + rhrAdjustment + sleepAdjustment
        print("DEBUG: Final score calculation: \(baseScore) + \(rhrAdjustment) + \(sleepAdjustment) = \(finalScore)")
        
        // Ensure score is within valid range (0-100)
        let clampedScore = max(0, min(100, finalScore))
        
        // Determine final category based on the clamped score
        let finalCategory = ReadinessCategory.allCases.first { $0.range.contains(clampedScore) } ?? .moderate
        print("DEBUG: Final readiness category: \(finalCategory.rawValue)")
        
        return (score: clampedScore, category: finalCategory, hrvBaseline: hrvBaseline, hrvDeviation: hrvDeviation, rhrAdjustment: rhrAdjustment, sleepAdjustment: sleepAdjustment)
    }
    
    // Calculate readiness score based on the selected mode
    func calculateReadinessScoreForCurrentMode(restingHeartRate: Double, sleepHours: Double) async throws -> (score: Double, category: ReadinessCategory, hrvBaseline: Double, hrvDeviation: Double, rhrAdjustment: Double, sleepAdjustment: Double) {
        let hrv: Double
        
        switch readinessMode {
        case .morning:
            hrv = try await fetchMorningHRV()
        case .rolling:
            hrv = try await fetchRollingHRV()
        }
        
        return calculateReadinessScore(hrv: hrv, restingHeartRate: restingHeartRate, sleepHours: sleepHours)
    }
    
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
        
        // Check if we already have data for today
        if let existingMetrics = coreDataManager.getHealthMetricsForDate(today) {
            print("DEBUG: Found existing health metrics for today, updating")
            
            // Log changes to help with debugging
            if existingMetrics.hrv != hrv {
                print("DEBUG: Updating HRV from \(existingMetrics.hrv) to \(hrv)")
            }
            
            if existingMetrics.restingHeartRate != restingHeartRate {
                print("DEBUG: Updating RHR from \(existingMetrics.restingHeartRate) to \(restingHeartRate)")
            }
            
            if existingMetrics.sleepHours != sleepHours {
                print("DEBUG: Updating Sleep Hours from \(existingMetrics.sleepHours) to \(sleepHours)")
            }
            
            // Update existing metrics
            existingMetrics.hrv = hrv
            existingMetrics.restingHeartRate = restingHeartRate
            existingMetrics.sleepHours = sleepHours
            existingMetrics.sleepQuality = Int16(sleepQuality)
            
            coreDataManager.saveContext()
            
            // Check if we already have a readiness score for today
            if let existingScore = coreDataManager.getReadinessScoreForDate(today) {
                print("DEBUG: Found existing readiness score for today, updating")
                
                // Log changes to help with debugging
                if existingScore.score != score {
                    print("DEBUG: Updating score from \(existingScore.score) to \(score)")
                }
                
                if existingScore.readinessCategory != category.rawValue {
                    print("DEBUG: Updating category from \(existingScore.readinessCategory ?? "unknown") to \(category.rawValue)")
                }
                
                if existingScore.readinessMode != readinessMode.rawValue {
                    print("DEBUG: Updating mode from \(existingScore.readinessMode ?? "unknown") to \(readinessMode.rawValue)")
                }
                
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
                healthMetrics: healthMetrics
            )
        }
    }
    
    // Process and save readiness data based on the current mode
    func processAndSaveTodaysDataForCurrentMode(restingHeartRate: Double, sleepHours: Double, sleepQuality: Int, forceRecalculation: Bool = false) async throws -> ReadinessScore? {
        let hrv: Double
        
        print("DEBUG: Processing readiness data for mode: \(readinessMode)")
        print("DEBUG: Force recalculation: \(forceRecalculation)")
        
        // Check for missing or invalid data
        var missingData: [String] = []
        
        if restingHeartRate <= 0 {
            missingData.append("Resting Heart Rate")
        }
        
        if sleepHours <= 0 {
            missingData.append("Sleep Hours")
        }
        
        if !missingData.isEmpty {
            print("DEBUG: WARNING - Missing or invalid data: \(missingData.joined(separator: ", "))")
        }
        
        // If we're forcing a recalculation due to mode change, we need to fetch new HRV data
        switch readinessMode {
        case .morning:
            print("DEBUG: Using morning HRV calculation")
            hrv = try await fetchMorningHRV()
        case .rolling:
            print("DEBUG: Using rolling HRV calculation")
            hrv = try await fetchRollingHRV()
        }
        
        if hrv <= 0 {
            print("DEBUG: WARNING - No HRV data available for the selected time range")
        }
        
        print("DEBUG: HRV value for readiness calculation: \(hrv)")
        
        // Always recalculate when mode changes or when forced
        if forceRecalculation {
            print("DEBUG: Forcing recalculation of readiness score for mode: \(readinessMode.rawValue)")
            
            // Calculate a new score
            let (score, category, hrvBaseline, hrvDeviation, rhrAdjustment, sleepAdjustment) = 
                calculateReadinessScore(hrv: hrv, restingHeartRate: restingHeartRate, sleepHours: sleepHours)
            
            let today = Date()
            
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
                    healthMetrics: healthMetrics
                )
            }
        } else {
            // Check if we already have a readiness score for today with the current mode
            let today = Date()
            if let existingScore = coreDataManager.getReadinessScoreForDate(today) {
                // If the mode is different, force a recalculation
                if existingScore.readinessMode != readinessMode.rawValue {
                    print("DEBUG: Existing score has different mode (\(existingScore.readinessMode ?? "unknown")), forcing recalculation for current mode (\(readinessMode.rawValue))")
                    
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
                    print("DEBUG: Using existing score with matching mode: \(readinessMode.rawValue)")
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
    
    // Get readiness score for today
    func getTodaysReadinessScore() -> ReadinessScore? {
        return coreDataManager.getReadinessScoreForDate(Date())
    }
    
    // Get readiness scores for the past N days
    func getReadinessScoresForPastDays(_ days: Int) -> [ReadinessScore] {
        return coreDataManager.getReadinessScoresForPastDays(days)
    }
} 
