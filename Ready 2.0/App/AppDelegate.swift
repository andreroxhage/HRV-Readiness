import UIKit
import HealthKit

// AppDelegate
// Responsible for:
// - Handling application lifecycle events
// - Initializing core services at launch
// - Managing background tasks
// - No UI state, primarily hooks into system events

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Initialize core services
        _ = CoreDataManager.shared
        
        // Register background tasks BEFORE app finishes launching
        BackgroundTaskManager.shared.registerBackgroundTasks()
        
        // Enable HealthKit background delivery if authorized
        Task {
            do {
                if await HealthKitManager.shared.isAuthorized() {
                    try await HealthKitManager.shared.enableBackgroundDelivery()
                    print("✅ APP: HealthKit background delivery enabled")
                }
            } catch {
                print("⚠️ APP: Failed to enable HealthKit background delivery: \(error)")
            }
        }
        
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Schedule background task when app enters background
        BackgroundTaskManager.shared.scheduleAppRefresh()
        
        Task {
            await HealthKitManager.shared.updateSharedHealthData()
        }
    }
} 