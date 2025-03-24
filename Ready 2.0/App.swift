//
//  Ready_2_0App.swift
//  Ready 2.0
//
//  Created by André Roxhage on 2025-03-13.
//

import SwiftUI
import HealthKit
import CoreData
import Foundation
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Initialize CoreData
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
@main
struct Ready_2_0App: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var viewModel = ReadinessViewModel()
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView(viewModel: viewModel)
                    .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
                    .environment(\.appearanceViewModel, AppearanceViewModel.shared)
            } else {
                OnboardingView(viewModel: viewModel)
                    .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
                    .environment(\.appearanceViewModel, AppearanceViewModel.shared)
            }
        }
    }
}
