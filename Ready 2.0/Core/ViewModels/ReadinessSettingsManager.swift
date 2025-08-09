import Foundation
import SwiftUI
import Combine

/// ReadinessSettingsManager
/// Manages settings with deferred save pattern to eliminate race conditions
/// - Local state management with @Published properties
/// - Explicit save operations on user action
/// - No observers or automatic saves
/// - Thread-safe operations with actor isolation

@MainActor
class ReadinessSettingsManager: ObservableObject {
    
    // MARK: - Published Settings (Local State)
    
    @Published var readinessMode: ReadinessMode
    @Published var baselinePeriod: BaselinePeriod
    @Published var useRHRAdjustment: Bool
    @Published var useSleepAdjustment: Bool
    @Published var minimumDaysForBaseline: Int
    @Published var morningEndHour: Int
    
    // MARK: - State Management
    
    @Published var hasUnsavedChanges: Bool = false
    @Published var isSaving: Bool = false
    
    // MARK: - Dependencies
    
    private let userDefaultsManager: UserDefaultsManager
    private let onSettingsChanged: ((ReadinessSettingsChange) -> Void)?
    
    // MARK: - Initialization
    
    init(userDefaultsManager: UserDefaultsManager = UserDefaultsManager.shared,
         onSettingsChanged: ((ReadinessSettingsChange) -> Void)? = nil) {
        self.userDefaultsManager = userDefaultsManager
        self.onSettingsChanged = onSettingsChanged
        
        // Load current values from UserDefaults
        self.readinessMode = userDefaultsManager.readinessMode
        self.baselinePeriod = userDefaultsManager.baselinePeriod
        self.useRHRAdjustment = userDefaultsManager.useRHRAdjustment
        self.useSleepAdjustment = userDefaultsManager.useSleepAdjustment
        self.minimumDaysForBaseline = userDefaultsManager.minimumDaysForBaseline
        self.morningEndHour = userDefaultsManager.morningEndHour
        
        // Monitor changes to published properties
        setupChangeDetection()
    }
    
    // MARK: - Change Detection
    
    private func setupChangeDetection() {
        // Use Publishers.CombineLatest to detect any setting changes
        Publishers.CombineLatest4(
            $readinessMode,
            $baselinePeriod,
            $useRHRAdjustment,
            $useSleepAdjustment
        )
        .combineLatest($minimumDaysForBaseline)
        .combineLatest($morningEndHour)
        .dropFirst() // Ignore initial values
        .sink { [weak self] _ in
            self?.hasUnsavedChanges = true
        }
        .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Settings Operations
    
    /// Save all settings to UserDefaults and trigger business logic
    func saveSettings() async throws {
        guard hasUnsavedChanges else { return }
        
        isSaving = true
        defer { isSaving = false }
        
        // Calculate what changed
        let changes: ReadinessSettingsChange = calculateChanges()
        
        // Save to UserDefaults atomically
        await saveToUserDefaults()
        
        // Mark as saved
        hasUnsavedChanges = false
        
        // Notify of changes for business logic updates
        if !changes.isEmpty {
            print("📤 SETTINGS: Notifying of changes: \(changes.types)")
            print("📤 SETTINGS: Historical recalc needed: \(changes.requiresHistoricalRecalculation)")
            onSettingsChanged?(changes)
        } else {
            print("ℹ️ SETTINGS: No changes to notify about")
        }
        
        print("✅ SETTINGS: Saved settings with changes: \(changes)")
    }
    
    /// Discard changes and reload from UserDefaults
    func discardChanges() {
        readinessMode = userDefaultsManager.readinessMode
        baselinePeriod = userDefaultsManager.baselinePeriod
        useRHRAdjustment = userDefaultsManager.useRHRAdjustment
        useSleepAdjustment = userDefaultsManager.useSleepAdjustment
        minimumDaysForBaseline = userDefaultsManager.minimumDaysForBaseline
        
        hasUnsavedChanges = false
        print("🔄 SETTINGS: Discarded unsaved changes")
    }
    
    /// Reset settings to defaults
    func resetToDefaults() {
        readinessMode = .morning
        baselinePeriod = .sevenDays
        useRHRAdjustment = false
        useSleepAdjustment = false
        minimumDaysForBaseline = 3
        
        hasUnsavedChanges = true
        print("🎯 SETTINGS: Reset to default values")
    }
    
    // MARK: - Private Methods
    
    private func calculateChanges() -> ReadinessSettingsChange {
        var changeTypes: Set<SettingsChangeType> = []
        
        if readinessMode != userDefaultsManager.readinessMode {
            changeTypes.insert(.readinessMode)
        }
        
        if baselinePeriod != userDefaultsManager.baselinePeriod {
            changeTypes.insert(.baselinePeriod)
        }
        
        if useRHRAdjustment != userDefaultsManager.useRHRAdjustment {
            changeTypes.insert(.rhrAdjustment)
        }
        
        if useSleepAdjustment != userDefaultsManager.useSleepAdjustment {
            changeTypes.insert(.sleepAdjustment)
        }
        
        if minimumDaysForBaseline != userDefaultsManager.minimumDaysForBaseline {
            changeTypes.insert(.minimumDays)
        }
        
        if morningEndHour != userDefaultsManager.morningEndHour {
            changeTypes.insert(.morningEndHour)
        }
        
        return ReadinessSettingsChange(
            types: changeTypes,
            previousValues: SettingsValues(
                mode: userDefaultsManager.readinessMode,
                period: userDefaultsManager.baselinePeriod,
                rhrEnabled: userDefaultsManager.useRHRAdjustment,
                sleepEnabled: userDefaultsManager.useSleepAdjustment,
                minimumDays: userDefaultsManager.minimumDaysForBaseline,
                morningEndHour: userDefaultsManager.morningEndHour
            ),
            newValues: SettingsValues(
                mode: readinessMode,
                period: baselinePeriod,
                rhrEnabled: useRHRAdjustment,
                sleepEnabled: useSleepAdjustment,
                minimumDays: minimumDaysForBaseline,
                morningEndHour: morningEndHour
            )
        )
    }
    
    private func saveToUserDefaults() async {
        // Save atomically - all or nothing
        await Task.detached { [weak self] in
            guard let self = self else { return }
            
            await MainActor.run {
                self.userDefaultsManager.readinessMode = self.readinessMode
                self.userDefaultsManager.baselinePeriod = self.baselinePeriod
                self.userDefaultsManager.useRHRAdjustment = self.useRHRAdjustment
                self.userDefaultsManager.useSleepAdjustment = self.useSleepAdjustment
                self.userDefaultsManager.minimumDaysForBaseline = self.minimumDaysForBaseline
                self.userDefaultsManager.morningEndHour = self.morningEndHour
            }
        }.value
    }
}

// MARK: - Supporting Types

struct ReadinessSettingsChange {
    let types: Set<SettingsChangeType>
    let previousValues: SettingsValues
    let newValues: SettingsValues
    
    var isEmpty: Bool { types.isEmpty }
    
    var requiresHistoricalRecalculation: Bool {
        // Any baseline-related change requires full historical recalculation
        // because it affects how all past scores are calculated
        types.contains(.baselinePeriod) || 
        types.contains(.rhrAdjustment) || 
        types.contains(.sleepAdjustment) ||
        types.contains(.minimumDays)
    }
    
    var requiresCurrentRecalculation: Bool {
        types.contains(.readinessMode) || types.contains(.morningEndHour) || requiresHistoricalRecalculation
    }
}

enum SettingsChangeType: CaseIterable {
    case readinessMode
    case baselinePeriod
    case rhrAdjustment
    case sleepAdjustment
    case minimumDays
    case morningEndHour
}

struct SettingsValues {
    let mode: ReadinessMode
    let period: BaselinePeriod
    let rhrEnabled: Bool
    let sleepEnabled: Bool
    let minimumDays: Int
    let morningEndHour: Int
} 