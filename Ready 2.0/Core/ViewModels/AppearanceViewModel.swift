import Foundation
import SwiftUI
import Combine

// AppearanceViewModel
// Responsible for:
// - Managing appearance-related UI state (@Published properties)
// - Coordinating between UI and AppearanceService
// - Providing computed properties for appearance settings

class AppearanceViewModel: ObservableObject {
    // MARK: - Published Properties (UI State)
    
    @Published var useSystemAppearance: Bool
    @Published var appAppearance: String
    @Published var showParticles: Bool
    
    // MARK: - Dependencies
    
    private let appearanceService: AppearanceService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(appearanceService: AppearanceService = AppearanceService.shared) {
        self.appearanceService = appearanceService
        
        // Load initial values from service
        let settings = appearanceService.getAppearanceSettings()
        self.useSystemAppearance = settings.useSystemAppearance
        self.appAppearance = settings.safeAppAppearance
        self.showParticles = settings.showParticles
        
        // Setup publishers to save changes
        setupObservers()
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe changes to useSystemAppearance
        $useSystemAppearance
            .dropFirst() // Skip initial value
            .debounce(for: 0.2, scheduler: RunLoop.main) // Debounce to avoid rapid updates
            .sink { [weak self] value in
                self?.appearanceService.updateAppearanceSettings(useSystemAppearance: value)
            }
            .store(in: &cancellables)
        
        // Observe changes to appAppearance
        $appAppearance
            .dropFirst()
            .debounce(for: 0.2, scheduler: RunLoop.main)
            .sink { [weak self] value in
                self?.appearanceService.updateAppearanceSettings(appAppearance: value)
            }
            .store(in: &cancellables)
        
        // Observe changes to showParticles
        $showParticles
            .dropFirst()
            .debounce(for: 0.2, scheduler: RunLoop.main)
            .sink { [weak self] value in
                self?.appearanceService.updateAppearanceSettings(showParticles: value)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func resetToDefaults() {
        appearanceService.resetAppearanceSettings()
        
        // Update local state
        let settings = appearanceService.getAppearanceSettings()
        self.useSystemAppearance = settings.useSystemAppearance
        self.appAppearance = settings.safeAppAppearance
        self.showParticles = settings.showParticles
    }
    
    // MARK: - Computed Properties
    
    var colorScheme: ColorScheme? {
        if useSystemAppearance {
            return nil // Use system setting
        } else {
            return appAppearance == "dark" ? .dark : .light
        }
    }
} 
