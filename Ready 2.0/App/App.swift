import SwiftUI
import HealthKit
import CoreData

// Main App entry point
// Responsible for:
// - App initialization
// - Managing global state (root ViewModels)
// - Coordinating between views based on app state (onboarding vs main app)

@main
struct Ready_2_0App: App {
    // App delegate for handling app lifecycle events
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    // App state
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    // Root ViewModels - these should be initialized here
    @StateObject private var readinessViewModel = ReadinessViewModel()
    @StateObject private var appearanceViewModel = AppearanceViewModel()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasCompletedOnboarding {
                    ContentView(viewModel: readinessViewModel)
                        .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
                        .environment(\.appearanceViewModel, appearanceViewModel)
                        .preferredColorScheme(appearanceViewModel.colorScheme)
                        .onAppear {
                            print("🔄 APP: Showing ContentView - onboarding completed")
                            debugUserDefaults()
                        }
                } else {
                    OnboardingView(viewModel: readinessViewModel)
                        .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
                        .environment(\.appearanceViewModel, appearanceViewModel)
                        .preferredColorScheme(appearanceViewModel.colorScheme)
                        .onAppear {
                            print("📋 APP: Showing OnboardingView - onboarding not completed")
                        }
                }
            }
            .onAppear {
                print("🚀 APP: Ready 2.0 launched")
                print("📊 APP: hasCompletedOnboarding = \(hasCompletedOnboarding)")
                debugCoreDataState()
            }
        }
    }
    
    private func debugUserDefaults() {
        print("📁 APP: Current UserDefaults state:")
        let defaults = UserDefaults.standard
        print("   - hasCompletedOnboarding: \(defaults.bool(forKey: "hasCompletedOnboarding"))")
        print("   - readinessMode: \(defaults.string(forKey: "readinessMode") ?? "not set")")
        print("   - baselinePeriod: \(defaults.integer(forKey: "baselinePeriod"))")
        print("   - useRHRAdjustment: \(defaults.bool(forKey: "useRHRAdjustment"))")
        print("   - useSleepAdjustment: \(defaults.bool(forKey: "useSleepAdjustment"))")
        print("   - lastCalculationTime: \(defaults.object(forKey: "lastCalculationTime") ?? "not set")")
    }
    
    private func debugCoreDataState() {
        print("💾 APP: Core Data state:")
        let context = CoreDataManager.shared.viewContext
        
        // Count health metrics
        let healthMetricsRequest: NSFetchRequest<HealthMetrics> = HealthMetrics.fetchRequest()
        var healthMetricsCount = 0
        do {
            healthMetricsCount = try context.count(for: healthMetricsRequest)
            print("   - HealthMetrics count: \(healthMetricsCount)")
        } catch {
            print("   - HealthMetrics count error: \(error)")
        }
    
        // Count readiness scores
        let readinessScoreRequest: NSFetchRequest<ReadinessScore> = ReadinessScore.fetchRequest()
        var readinessScoreCount = 0
        do {
            readinessScoreCount = try context.count(for: readinessScoreRequest)
            print("   - ReadinessScore count: \(readinessScoreCount)")
        } catch {
            print("   - ReadinessScore count error: \(error)")
        }
        
        // Clean up duplicate data only - no more test data creation
        if healthMetricsCount > 0 {
            print("🧹 APP: Running data cleanup to fix duplicates...")
            CoreDataManager.shared.cleanupDuplicateHealthMetrics()
        }
    }
} 