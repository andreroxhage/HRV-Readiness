import Foundation
import SwiftUI
import Combine
import UIKit

class AppearanceViewModel: ObservableObject {
    static let shared = AppearanceViewModel()
    
    @Published var useSystemAppearance: Bool = true
    @Published var appAppearance: String = "light"
    @Published var showParticles: Bool = true
    
    private let appearanceService = AppearanceService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Check accessibility settings
        if UIAccessibility.isReduceMotionEnabled {
            showParticles = false
            appearanceService.updateAppearanceSettings(showParticles: false)
        }
        
        loadSettings()
        setupBindings()
        setupAccessibilityObserver()
    }
    
    private func loadSettings() {
        let settings = appearanceService.getAppearanceSettings()
        useSystemAppearance = settings.useSystemAppearance
        appAppearance = settings.appAppearance ?? "light"
        // Only update particles if reduce motion is not enabled
        if !UIAccessibility.isReduceMotionEnabled {
            showParticles = settings.showParticles
        }
    }
    
    private func setupAccessibilityObserver() {
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .sink { [weak self] _ in
                if UIAccessibility.isReduceMotionEnabled {
                    self?.showParticles = false
                    self?.appearanceService.updateAppearanceSettings(showParticles: false)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupBindings() {
        // Observe changes
        $useSystemAppearance
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] newValue in
                self?.appearanceService.updateAppearanceSettings(useSystemAppearance: newValue)
            }
            .store(in: &cancellables)
        
        $appAppearance
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] newValue in
                self?.appearanceService.updateAppearanceSettings(appAppearance: newValue)
            }
            .store(in: &cancellables)
        
        $showParticles
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] newValue in
                self?.appearanceService.updateAppearanceSettings(showParticles: newValue)
            }
            .store(in: &cancellables)
    }
    
    func resetToDefaults() {
        appearanceService.resetAppearanceSettings()
        loadSettings()
    }
    
    // Helper for determining color scheme
    var colorScheme: ColorScheme? {
        if useSystemAppearance {
            return nil // Use system setting
        }
        return appAppearance == "dark" ? .dark : .light
    }
}

private struct AppearanceViewModelKey: EnvironmentKey {
    static let defaultValue = AppearanceViewModel.shared
}

extension EnvironmentValues {
    var appearanceViewModel: AppearanceViewModel {
        get { self[AppearanceViewModelKey.self] }
        set { self[AppearanceViewModelKey.self] = newValue }
    }
} 