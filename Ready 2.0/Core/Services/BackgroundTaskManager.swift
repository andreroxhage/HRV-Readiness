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
                var rhr: Double = 0
                var sleepHours: Double = 0
                var sleepQuality: Int = 0

                if readinessService.useRHRAdjustment {
                    do {
                        rhr = try await healthKitManager.fetchRestingHeartRate()
                    } catch {
                        print("⚠️ BACKGROUND: RHR fetch failed: \(error). Continuing without RHR.")
                    }
                }

                if readinessService.useSleepAdjustment {
                    do {
                        let sleepData = try await healthKitManager.fetchSleepData()
                        sleepHours = sleepData.hours
                        sleepQuality = sleepData.quality
                    } catch {
                        print("⚠️ BACKGROUND: Sleep fetch failed: \(error). Continuing without Sleep.")
                    }
                }

                let score = try await readinessService.processAndSaveTodaysDataForCurrentMode(
                    restingHeartRate: rhr,
                    sleepHours: sleepHours,
                    sleepQuality: sleepQuality
                )
                
                if let score = score {
                    // Update widget data
                    updateWidgetData(
                        score: score.score,
                        category: ReadinessCategory.forScore(score.score),
                        timestamp: Date()
                    )
                    let appGroupDefaults = UserDefaults(suiteName: "group.andreroxhage.Ready-2-0")
                    appGroupDefaults?.set(true, forKey: "hasCurrentReadiness")
                    
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
            // Attempt to update widget with latest known data even on failure
            if readinessService.updateWidgetWithLatestScoreIfAvailable() {
                print("ℹ️ BACKGROUND: Updated widget with latest known score despite failure")
                return true
            }
            return false
        }
    }
    
    // MARK: - Background Task Scheduling
    
    func scheduleAppRefresh() {
        print("📅 BACKGROUND: Scheduling next app refresh")
        let calendar = Calendar.current
        let now = Date()

        // Compute the next local 06:00 (today if in the future, otherwise tomorrow)
        let todaySix = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: calendar.startOfDay(for: now))
        let targetDate: Date
        if let todaySix = todaySix, todaySix > now {
            targetDate = todaySix
        } else {
            let tomorrowStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
            targetDate = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: tomorrowStart) ?? now.addingTimeInterval(24*3600)
        }

        BGTaskScheduler.shared.getPendingTaskRequests { requests in
            // Avoid submitting a duplicate if an existing request is close to the target time (within 30 minutes)
            let hasSimilar = requests.contains { req in
                guard req.identifier == Self.refreshIdentifier, let begin = req.earliestBeginDate else { return false }
                return abs(begin.timeIntervalSince(targetDate)) < 1800
            }

            if hasSimilar {
                print("ℹ️ BACKGROUND: Similar refresh request already pending around \(targetDate), skipping submit")
                return
            }

            let request = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
            request.earliestBeginDate = targetDate
            do {
                try BGTaskScheduler.shared.submit(request)
                print("✅ BACKGROUND: Scheduled app refresh for \(targetDate)")
            } catch {
                print("❌ BACKGROUND: Failed to schedule app refresh: \(error)")
            }
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
