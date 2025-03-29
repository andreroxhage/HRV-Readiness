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
        
        // We'll handle HealthKit authorization during onboarding instead of here
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Schedule background task when app enters background
        Task {
            await HealthKitManager.shared.updateSharedHealthData()
        }
    }
} 