//
//  Ready_2_0App.swift
//  Ready 2.0
//
//  Created by André Roxhage on 2025-03-13.
//

import SwiftUI
import HealthKit

#if os(iOS)
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Request HealthKit authorization when app launches
        Task {
            do {
                try await HealthKitManager.shared.requestAuthorization()
                // Setup background observers after authorization
                HealthKitManager.shared.setupBackgroundObservers()
            } catch {
                print("Failed to request HealthKit authorization: \(error)")
            }
        }
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Schedule background task when app enters background
        Task {
            await HealthKitManager.shared.updateSharedHealthData()
        }
    }
}
#endif

@main
struct Ready_2_0App: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
