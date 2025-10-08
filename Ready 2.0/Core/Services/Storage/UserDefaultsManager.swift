import Foundation
import WidgetKit

// Import the enums needed for defaults
// These should be available since they're in the same module

// UserDefaultsManager
// Responsible for:
// - Managing app settings and preferences
// - Providing type-safe access to UserDefaults
// - Centralizing default values
// - Not responsible for business logic or UI

class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    
    // MARK: - Constants
    
    // Keys for UserDefaults
    private enum Keys {
        static let readinessMode = "readinessMode"
        static let baselinePeriod = "baselinePeriod"
        static let useRHRAdjustment = "useRHRAdjustment"
        static let useSleepAdjustment = "useSleepAdjustment"
        static let minimumDaysForBaseline = "minimumDaysForBaseline"
        static let morningEndHour = "morningEndHour"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let initialDataImportCompleted = "initialDataImportCompleted"
        static let lastCalculationTime = "lastCalculationTime"
        static let lastHRVBaselineCalculation = "lastHRVBaselineCalculation"
        static let lastRHRBaselineCalculation = "lastRHRBaselineCalculation"
        static let lastSleepBaselineCalculation = "lastSleepBaselineCalculation"
    }
    
    // Default values - Updated for FR-2 requirements
    private enum Defaults {
        static let readinessMode = ReadinessMode.morning
        static let baselinePeriod = BaselinePeriod.sevenDays // FR-2: 7-day rolling baseline is primary requirement
        static let useRHRAdjustment = false // Changed to false - RHR adjustment is optional
        static let useSleepAdjustment = false // Changed to false - sleep adjustment is optional
        static let minimumDaysForBaseline = 2
        static let morningEndHour = 11 // Configurable morning window end hour (09-12), default 11:00
        static let hasCompletedOnboarding = false
    }
    
    // MARK: - Properties
    
    private let userDefaults = UserDefaults.standard
    private let appGroupDefaults = UserDefaults(suiteName: "group.andreroxhage.Ready-2-0")
    
    // MARK: - Initialization
    
    private init() {
        // Private initializer for singleton
        setupDefaultValues()
    }
    
    // MARK: - Setup
    
    private func setupDefaultValues() {
        // Set default values if not already set
        if !userDefaults.contains(key: Keys.readinessMode) {
            userDefaults.set(Defaults.readinessMode.rawValue, forKey: Keys.readinessMode)
        }
        
        if !userDefaults.contains(key: Keys.baselinePeriod) {
            userDefaults.set(Defaults.baselinePeriod.rawValue, forKey: Keys.baselinePeriod)
        }
        
        if !userDefaults.contains(key: Keys.useRHRAdjustment) {
            userDefaults.set(Defaults.useRHRAdjustment, forKey: Keys.useRHRAdjustment)
        }
        
        if !userDefaults.contains(key: Keys.useSleepAdjustment) {
            userDefaults.set(Defaults.useSleepAdjustment, forKey: Keys.useSleepAdjustment)
        }
        
        if !userDefaults.contains(key: Keys.minimumDaysForBaseline) {
            userDefaults.set(Defaults.minimumDaysForBaseline, forKey: Keys.minimumDaysForBaseline)
        }

        if !userDefaults.contains(key: Keys.morningEndHour) {
            userDefaults.set(Defaults.morningEndHour, forKey: Keys.morningEndHour)
        }
    }
    
    // MARK: - Readiness Settings
    
    var readinessMode: ReadinessMode {
        get {
            let modeString = userDefaults.string(forKey: Keys.readinessMode) ?? Defaults.readinessMode.rawValue
            return ReadinessMode(rawValue: modeString) ?? Defaults.readinessMode
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Keys.readinessMode)
            
            // Also update app group for widget
            appGroupDefaults?.set(newValue.rawValue, forKey: Keys.readinessMode)
        }
    }
    
    var baselinePeriod: BaselinePeriod {
        get {
            let days = userDefaults.integer(forKey: Keys.baselinePeriod)
            return BaselinePeriod(rawValue: days) ?? Defaults.baselinePeriod
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Keys.baselinePeriod)
            
            // Also update app group for widget
            appGroupDefaults?.set(newValue.rawValue, forKey: Keys.baselinePeriod)
        }
    }
    
    var useRHRAdjustment: Bool {
        get {
            if !userDefaults.contains(key: Keys.useRHRAdjustment) {
                return Defaults.useRHRAdjustment
            }
            return userDefaults.bool(forKey: Keys.useRHRAdjustment)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.useRHRAdjustment)
        }
    }
    
    var useSleepAdjustment: Bool {
        get {
            if !userDefaults.contains(key: Keys.useSleepAdjustment) {
                return Defaults.useSleepAdjustment
            }
            return userDefaults.bool(forKey: Keys.useSleepAdjustment)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.useSleepAdjustment)
        }
    }
    
    var minimumDaysForBaseline: Int {
        get {
            let days = userDefaults.integer(forKey: Keys.minimumDaysForBaseline)
            return days != 0 ? days : Defaults.minimumDaysForBaseline
        }
        set {
            userDefaults.set(newValue, forKey: Keys.minimumDaysForBaseline)
        }
    }

    /// Morning end hour for Morning mode time window.
    /// Clamped to 9-12 inclusive. Default 11 when not set.
    var morningEndHour: Int {
        get {
            let stored = userDefaults.integer(forKey: Keys.morningEndHour)
            let value = stored != 0 ? stored : Defaults.morningEndHour
            return min(max(value, 9), 12)
        }
        set {
            let clamped = min(max(newValue, 9), 12)
            userDefaults.set(clamped, forKey: Keys.morningEndHour)
            // Mirror to app group in case widget needs to reference it later
            appGroupDefaults?.set(clamped, forKey: Keys.morningEndHour)
        }
    }
    
    var hasCompletedOnboarding: Bool {
        get {
            return userDefaults.bool(forKey: Keys.hasCompletedOnboarding)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.hasCompletedOnboarding)
        }
    }
    
    var lastCalculationTime: Date? {
        get {
            return userDefaults.object(forKey: Keys.lastCalculationTime) as? Date
        }
        set {
            userDefaults.set(newValue, forKey: Keys.lastCalculationTime)
            
            // Also update app group for widget
            appGroupDefaults?.set(newValue, forKey: Keys.lastCalculationTime)
        }
    }
    
    var lastHRVBaselineCalculation: Date? {
        get {
            return userDefaults.object(forKey: Keys.lastHRVBaselineCalculation) as? Date
        }
        set {
            userDefaults.set(newValue, forKey: Keys.lastHRVBaselineCalculation)
        }
    }
    
    var lastRHRBaselineCalculation: Date? {
        get {
            return userDefaults.object(forKey: Keys.lastRHRBaselineCalculation) as? Date
        }
        set {
            userDefaults.set(newValue, forKey: Keys.lastRHRBaselineCalculation)
        }
    }
    
    var lastSleepBaselineCalculation: Date? {
        get {
            return userDefaults.object(forKey: Keys.lastSleepBaselineCalculation) as? Date
        }
        set {
            userDefaults.set(newValue, forKey: Keys.lastSleepBaselineCalculation)
        }
    }
    
    var initialDataImportCompleted: Bool {
        get {
            return userDefaults.bool(forKey: Keys.initialDataImportCompleted)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.initialDataImportCompleted)
        }
    }
    
    // MARK: - Widget Data Management
    
    func updateWidgetData(score: Double, category: ReadinessCategory, timestamp: Date) {
        print("🔄 WIDGET: Updating widget data - Score: \(score), Category: \(category.rawValue)")
        
        // Update main UserDefaults
        userDefaults.set(score, forKey: "currentReadinessScore")
        userDefaults.set(category.rawValue, forKey: "currentReadinessCategory")
        userDefaults.set(timestamp, forKey: "currentReadinessTimestamp")
        userDefaults.set(true, forKey: "hasCurrentReadiness")
        
        // Update app group UserDefaults for widget access
        appGroupDefaults?.set(score, forKey: "currentReadinessScore")
        appGroupDefaults?.set(category.rawValue, forKey: "currentReadinessCategory")
        appGroupDefaults?.set(timestamp, forKey: "currentReadinessTimestamp")
        appGroupDefaults?.set(category.emoji, forKey: "currentReadinessEmoji")
        appGroupDefaults?.set(category.description, forKey: "currentReadinessDescription")
        appGroupDefaults?.set(true, forKey: "hasCurrentReadiness")
        
        // Additional widget display data
        let colorData = getWidgetColorData(for: category)
        appGroupDefaults?.set(colorData.red, forKey: "widgetColorRed")
        appGroupDefaults?.set(colorData.green, forKey: "widgetColorGreen")
        appGroupDefaults?.set(colorData.blue, forKey: "widgetColorBlue")
        
        // Force widget timeline refresh
        WidgetCenter.shared.reloadAllTimelines()
        
        print("✅ WIDGET: Widget data updated and timeline refreshed")
    }

    // Store latest health KPIs for widget consumption
    func updateLatestHealthMetrics(hrv: Double, rhr: Double, sleepHours: Double, sleepQuality: Int, timestamp: Date = Date()) {
        // Main defaults (optional)
        userDefaults.set(hrv, forKey: "lastHRV")
        userDefaults.set(rhr, forKey: "lastRestingHeartRate")
        userDefaults.set(sleepHours, forKey: "lastSleepHours")
        userDefaults.set(sleepQuality, forKey: "sleepQuality")
        // Also write legacy/alternate keys
        userDefaults.set(hrv, forKey: "latestHRV")
        userDefaults.set(rhr, forKey: "latestRHR")
        userDefaults.set(sleepHours, forKey: "latestSleepHours")
        userDefaults.set(sleepQuality, forKey: "latestSleepQuality")

        // App group for widget
        appGroupDefaults?.set(hrv, forKey: "lastHRV")
        appGroupDefaults?.set(rhr, forKey: "lastRestingHeartRate")
        appGroupDefaults?.set(sleepHours, forKey: "lastSleepHours")
        appGroupDefaults?.set(sleepQuality, forKey: "sleepQuality")
        appGroupDefaults?.set(hrv, forKey: "latestHRV")
        appGroupDefaults?.set(rhr, forKey: "latestRHR")
        appGroupDefaults?.set(sleepHours, forKey: "latestSleepHours")
        appGroupDefaults?.set(sleepQuality, forKey: "latestSleepQuality")
        appGroupDefaults?.set(timestamp, forKey: "lastHealthDataUpdate")

        WidgetCenter.shared.reloadAllTimelines()
    }
  
  // Store recent readiness history for widget rendering (dates, scores, categories)
  func updateWidgetHistory(entries: [(date: Date, score: Double, category: ReadinessCategory)]) {
      let dates: [Date] = entries.map { $0.date }
      let scores: [Double] = entries.map { $0.score }
      let cats: [String] = entries.map { $0.category.rawValue }
      appGroupDefaults?.set(dates, forKey: "recentReadinessDates")
      appGroupDefaults?.set(scores, forKey: "recentReadinessScores")
      appGroupDefaults?.set(cats, forKey: "recentReadinessCategories")
  }
    
    private func getWidgetColorData(for category: ReadinessCategory) -> (red: Double, green: Double, blue: Double) {
        switch category {
        case .optimal:
            return (red: 0.0, green: 0.8, blue: 0.0) // Green
        case .moderate:
            return (red: 1.0, green: 1.0, blue: 0.0) // Yellow
        case .low:
            return (red: 1.0, green: 0.5, blue: 0.0) // Orange
        case .fatigue:
            return (red: 1.0, green: 0.0, blue: 0.0) // Red
        case .unknown:
            return (red: 0.5, green: 0.5, blue: 0.5) // Gray
        }
    }
    
    func getWidgetData() -> (score: Double, category: String, timestamp: Date?, emoji: String, description: String)? {
        guard let appGroupDefaults = appGroupDefaults else {
            print("⚠️ WIDGET: App group defaults not available")
            return nil
        }
        
        let score = appGroupDefaults.double(forKey: "currentReadinessScore")
        let categoryString = appGroupDefaults.string(forKey: "currentReadinessCategory") ?? "Unknown"
        let timestamp = appGroupDefaults.object(forKey: "currentReadinessTimestamp") as? Date
        let emoji = appGroupDefaults.string(forKey: "currentReadinessEmoji") ?? "❓"
        let description = appGroupDefaults.string(forKey: "currentReadinessDescription") ?? "No data available"
        
        return (score: score, category: categoryString, timestamp: timestamp, emoji: emoji, description: description)
    }
}

// MARK: - Extensions

extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
} 
