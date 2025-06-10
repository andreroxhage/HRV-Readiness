import Foundation
import BackgroundTasks
import WidgetKit

// BackgroundTaskManager
// Responsible for:
// - Managing background app refresh tasks
// - Scheduling automatic readiness calculations
// - Coordinating background HealthKit data sync
// - Updating widgets when data changes

class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    // MARK: - Constants
    
    static let refreshIdentifier = "com.andreroxhage.Ready-2-0.refresh"
    
    // MARK: - Dependencies
    
    private let readinessService = ReadinessService.shared
    private let healthKitManager = HealthKitManager.shared
    private let userDefaultsManager = UserDefaultsManager.shared
    
    // MARK: - Initialization
    
    private init() {
        // Private initializer for singleton pattern
    }
    
    // MARK: - Background Task Registration
    
    func registerBackgroundTasks() {
        print("🔄 BACKGROUND: Registering background tasks")
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshIdentifier,
            using: nil
        ) { task in
            print("🔄 BACKGROUND: Background refresh task started")
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    // MARK: - Background Task Handling
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        print("🔄 BACKGROUND: Handling app refresh task")
        
        // Schedule the next background task
        scheduleAppRefresh()
        
        // Set expiration handler
        task.expirationHandler = {
            print("⏰ BACKGROUND: Task expired")
            task.setTaskCompleted(success: false)
        }
        
        // Perform background work
        Task {
            let success = await performBackgroundWork()
            print("✅ BACKGROUND: Background work completed with success: \(success)")
            task.setTaskCompleted(success: success)
        }
    }
    
    private func performBackgroundWork() async -> Bool {
        do {
            print("🔄 BACKGROUND: Starting background readiness calculation")
            
            // Check if we need to calculate today's readiness
            let existingScore = readinessService.getTodaysReadinessScore()
            
            // Only calculate if we don't have today's score or it's outdated
            let shouldCalculate = existingScore == nil || 
                (existingScore?.calculationTimestamp?.timeIntervalSinceNow ?? -86400) < -3600 // Older than 1 hour
            
            if shouldCalculate {
                // Try to fetch fresh health data and calculate
                let rhr = try await healthKitManager.fetchRestingHeartRate()
                let sleepData = try await healthKitManager.fetchSleepData()
                
                let score = try await readinessService.processAndSaveTodaysDataForCurrentMode(
                    restingHeartRate: rhr,
                    sleepHours: sleepData.hours,
                    sleepQuality: sleepData.quality
                )
                
                if let score = score {
                    // Update widget data
                    updateWidgetData(
                        score: score.score,
                        category: ReadinessCategory.forScore(score.score),
                        timestamp: Date()
                    )
                    
                    print("✅ BACKGROUND: Successfully calculated and updated readiness score: \(score.score)")
                    return true
                }
            } else {
                print("ℹ️ BACKGROUND: Today's score is up to date, skipping calculation")
                return true
            }
            
            return false
        } catch {
            print("❌ BACKGROUND: Background calculation failed: \(error)")
            return false
        }
    }
    
    // MARK: - Background Task Scheduling
    
    func scheduleAppRefresh() {
        print("📅 BACKGROUND: Scheduling next app refresh")
        
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
        
        // Schedule for early morning (6 AM next day)
        let calendar = Calendar.current
        let now = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let morningTime = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: tomorrow)!
        
        request.earliestBeginDate = morningTime
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ BACKGROUND: Successfully scheduled app refresh for \(morningTime)")
        } catch {
            print("❌ BACKGROUND: Failed to schedule app refresh: \(error)")
        }
    }
    
    // MARK: - Widget Data Management
    
    private func updateWidgetData(score: Double, category: ReadinessCategory, timestamp: Date) {
        print("🔄 BACKGROUND: Updating widget data - Score: \(score), Category: \(category.rawValue)")
        
        let appGroupDefaults = UserDefaults(suiteName: "group.andreroxhage.Ready-2-0")
        
        appGroupDefaults?.set(score, forKey: "currentReadinessScore")
        appGroupDefaults?.set(category.rawValue, forKey: "currentReadinessCategory")
        appGroupDefaults?.set(timestamp, forKey: "lastUpdateTimestamp")
        appGroupDefaults?.set(category.emoji, forKey: "currentReadinessEmoji")
        appGroupDefaults?.set(category.description, forKey: "currentReadinessDescription")
        
        // Force widget timeline refresh
        WidgetCenter.shared.reloadAllTimelines()
        
        print("✅ BACKGROUND: Widget data updated and timeline refreshed")
    }
} 
