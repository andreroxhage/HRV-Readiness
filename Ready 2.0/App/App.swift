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
            if hasCompletedOnboarding {
                ContentView(viewModel: readinessViewModel)
                    .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
                    .environment(\.appearanceViewModel, appearanceViewModel)
                    .preferredColorScheme(appearanceViewModel.colorScheme)
            } else {
                OnboardingView(viewModel: readinessViewModel)
                    .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
                    .environment(\.appearanceViewModel, appearanceViewModel)
                    .preferredColorScheme(appearanceViewModel.colorScheme)
            }
        }
    }
} 