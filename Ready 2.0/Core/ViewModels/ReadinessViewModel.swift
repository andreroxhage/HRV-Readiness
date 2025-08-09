import Foundation
import SwiftUI
import Combine
import CoreData

// ReadinessViewModel
// Main ViewModel for the Readiness feature UI
// Responsible for:
// - Managing UI state (@Published properties)
// - Handling user interactions
// - Coordinating between UI and business logic
// - Formatting data for display

class ReadinessViewModel: ObservableObject {
    // MARK: - Published Properties (UI State)
    
    // Core readiness data
    @Published var readinessScore: Double = 0
    @Published var readinessCategory: ReadinessCategory = .unknown
    @Published var hrvBaseline: Double = 0
    @Published var hrvDeviation: Double = 0
    @Published var rhrAdjustment: Double = 0
    @Published var sleepAdjustment: Double = 0
    
    // UI state
    @Published var isLoading: Bool = false
    @Published var error: ReadinessError?
    @Published var pastScores: [ReadinessScore] = []
    
    // Enhanced error handling state - leveraging ReadinessError enum
    @Published var showPartialDataWarning: Bool = false
    @Published var canUsePartialData: Bool = false
    
    // Initial setup state
    @Published var isPerformingInitialSetup: Bool = false
    @Published var initialSetupProgress: Double = 0.0
    @Published var initialSetupStatus: String = ""
    
    // Settings - Updated for FR-2 requirements
    @Published var readinessMode: ReadinessMode = .morning
    @Published var baselinePeriod: BaselinePeriod = .sevenDays // FR-2: 7-day rolling baseline default
    @Published var useRHRAdjustment: Bool = false
    @Published var useSleepAdjustment: Bool = false
    @Published var lastCalculationTime: Date?
    
    // MARK: - Dependencies
    
    // Services - should be injected
    let readinessService: ReadinessService
    private let calculationViewModel: ReadinessCalculationViewModel
    private let userDefaultsManager: UserDefaultsManager
    
    // For UserDefaults access
    private var cancellables = Set<AnyCancellable>()
    
    // Debouncing for expensive recalculations
    private var recalculationTimer: Timer?
    
    // Active long-running operation for cooperative cancellation
    private var activeOperationTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(readinessService: ReadinessService = ReadinessService.shared,
         calculationViewModel: ReadinessCalculationViewModel = ReadinessCalculationViewModel(),
         userDefaultsManager: UserDefaultsManager = UserDefaultsManager.shared) {
        self.readinessService = readinessService
        self.calculationViewModel = calculationViewModel
        self.userDefaultsManager = userDefaultsManager
        
        // Load settings from UserDefaults
        self.readinessMode = userDefaultsManager.readinessMode
        self.baselinePeriod = userDefaultsManager.baselinePeriod
        self.useRHRAdjustment = userDefaultsManager.useRHRAdjustment
        self.useSleepAdjustment = userDefaultsManager.useSleepAdjustment
        self.lastCalculationTime = userDefaultsManager.lastCalculationTime
        
        // Note: Settings changes are now handled via explicit handleSettingsChanges() calls
        // This eliminates the race conditions and performance issues from the old observer pattern
    }
    
    // MARK: - Settings Integration
    
    /// Handle settings changes from the ReadinessSettingsManager
    /// This method is called when settings are explicitly saved
    func handleSettingsChanges(_ changes: ReadinessSettingsChange) {
        print("🔄 VIEWMODEL: Received settings changes: \(changes.types)")
        print("📊 VIEWMODEL: Requires historical recalculation: \(changes.requiresHistoricalRecalculation)")
        print("📊 VIEWMODEL: Requires current recalculation: \(changes.requiresCurrentRecalculation)")
        
        // Update local state to match saved values
        updateLocalStateFromSavedSettings()
        
        // Handle business logic based on change types
        Task { @MainActor in
            if changes.requiresHistoricalRecalculation {
                print("🔄 VIEWMODEL: Starting 90-day historical recalculation...")
                await performHistoricalRecalculation()
            } else if changes.requiresCurrentRecalculation {
                print("🔄 VIEWMODEL: Starting current day recalculation...")
                await loadTodaysReadinessScore()
            } else {
                print("ℹ️ VIEWMODEL: No recalculation needed for these changes")
            }
        }
    }
    
    /// Update local state from UserDefaults (after settings are saved)
    private func updateLocalStateFromSavedSettings() {
        self.readinessMode = userDefaultsManager.readinessMode
        self.baselinePeriod = userDefaultsManager.baselinePeriod
        self.useRHRAdjustment = userDefaultsManager.useRHRAdjustment
        self.useSleepAdjustment = userDefaultsManager.useSleepAdjustment
    }
    
    /// Perform 90-day historical recalculation after settings changes
    private func performHistoricalRecalculation() async {
        print("🔄 VIEWMODEL: Starting 90-day historical recalculation...")
        await MainActor.run {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            // Use the same method as the advanced settings
            await recalculateAllScores()
            print("✅ VIEWMODEL: Historical recalculation completed successfully")
        } catch {
            await MainActor.run {
                self.error = error as? ReadinessError ?? .unknownError(error)
                print("❌ VIEWMODEL: Historical recalculation failed: \(error)")
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    

    
    // MARK: - Data Loading
    
    func loadTodaysReadinessScore() async {
        await MainActor.run {
            self.isLoading = true
            self.error = nil
        }
        
        if let score = readinessService.getTodaysReadinessScore() {
            await MainActor.run {
                self.readinessScore = score.score
                self.readinessCategory = score.category
                self.hrvBaseline = score.hrvBaseline
                self.hrvDeviation = score.hrvDeviation
                self.rhrAdjustment = score.rhrAdjustment
                self.sleepAdjustment = score.sleepAdjustment
                self.lastCalculationTime = score.calculationTimestamp
                
                // Also update mode and period if different
                if let mode = score.mode, mode != self.readinessMode {
                    self.readinessMode = mode
                    self.userDefaultsManager.readinessMode = mode
                }
                
                if let period = score.period, period != self.baselinePeriod {
                    self.baselinePeriod = period
                    self.userDefaultsManager.baselinePeriod = period
                }
                
                self.isLoading = false
            }
        } else {
            await MainActor.run {
                self.readinessScore = 0
                self.readinessCategory = .unknown
                self.isLoading = false
            }
        }
    }
    
    func loadPastScores(days: Int = 30) async {
        await MainActor.run {
            self.isLoading = true
            self.error = nil
        }
        
        let scores = readinessService.getReadinessScoresForPastDays(days)
        
        await MainActor.run {
            self.pastScores = scores
            self.isLoading = false
        }
    }
    
    // MARK: - Calculation Actions
    
    func calculateReadiness(restingHeartRate: Double, sleepHours: Double, sleepQuality: Int) {
        print("🎯 VIEWMODEL: calculateReadiness called with RHR=\(restingHeartRate), Sleep=\(sleepHours)h, Quality=\(sleepQuality)")
        
        Task {
            await MainActor.run {
                self.isLoading = true
                self.error = nil
            }
            
            do {
                print("🔄 VIEWMODEL: Calling calculationViewModel.calculateReadiness")
                if let score = try await calculationViewModel.calculateReadiness(
                    restingHeartRate: restingHeartRate,
                    sleepHours: sleepHours,
                    sleepQuality: sleepQuality
                ) {
                    print("✅ VIEWMODEL: Successfully calculated readiness score: \(score.score)")
                    await MainActor.run {
                        self.readinessScore = score.score
                        self.readinessCategory = score.category
                        self.hrvBaseline = score.hrvBaseline
                        self.hrvDeviation = score.hrvDeviation
                        self.rhrAdjustment = score.rhrAdjustment
                        self.sleepAdjustment = score.sleepAdjustment
                        self.lastCalculationTime = score.calculationTimestamp
                        
                        // Reload past scores to include the new one
                        Task {
                            await self.loadPastScores()
                        }
                        
                        self.isLoading = false
                    }
                }
            } catch let error as ReadinessError {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = .unknownError(error)
                    self.isLoading = false
                }
            }
        }
    }
    
    func recalculateReadiness() {
        Task {
            await MainActor.run {
                self.isLoading = true
                self.error = nil
            }
            
            do {
                // Try to recalculate today's readiness
                if let score = try await calculationViewModel.recalculateReadinessForDate(Date()) {
                    await MainActor.run {
                        self.readinessScore = score.score
                        self.readinessCategory = score.category
                        self.hrvBaseline = score.hrvBaseline
                        self.hrvDeviation = score.hrvDeviation
                        self.rhrAdjustment = score.rhrAdjustment
                        self.sleepAdjustment = score.sleepAdjustment
                        self.lastCalculationTime = score.calculationTimestamp
                        self.isLoading = false
                    }
                }
            } catch let error as ReadinessError {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = .unknownError(error)
                    self.isLoading = false
                }
            }
        }
    }
    
    func recalculateAllPastScores(days: Int = 30) {
        Task {
            await MainActor.run {
                self.isLoading = true
                self.error = nil
            }
            
            do {
                let scores = try await calculationViewModel.recalculateHistoricalReadiness(days: days)
                
                await MainActor.run {
                    self.pastScores = scores
                    self.isLoading = false
                    
                    // Also load today's score which might have been updated
                    Task {
                        await self.loadTodaysReadinessScore()
                    }
                }
            } catch let error as ReadinessError {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = .unknownError(error)
                    self.isLoading = false
                }
            }
        }
    }
    
    func recalculateAllScores() async {
        await MainActor.run {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            // Use the ReadinessService to recalculate all scores
            try await readinessService.recalculateAllReadinessScores()
            
            await MainActor.run {
                self.isLoading = false
                
                // Reload all data to reflect the updated scores
                Task {
                    await self.loadTodaysReadinessScore()
                    await self.loadPastScores()
                }
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                print("❌ VIEWMODEL: Recalculate all scores failed: \(error)")
            }
        }
    }
    
    func recalculateReadinessForDate(_ date: Date) {
        Task {
            await MainActor.run {
                self.isLoading = true
                self.error = nil
            }
            
            do {
                // Try to recalculate readiness for the specified date
                if let score = try await calculationViewModel.recalculateReadinessForDate(date) {
                    await MainActor.run {
                        // If the date is today, also update the current score
                        if Calendar.current.isDateInToday(date) {
                            self.readinessScore = score.score
                            self.readinessCategory = score.category
                            self.hrvBaseline = score.hrvBaseline
                            self.hrvDeviation = score.hrvDeviation
                            self.rhrAdjustment = score.rhrAdjustment
                            self.sleepAdjustment = score.sleepAdjustment
                            self.lastCalculationTime = score.calculationTimestamp
                        }
                        
                        // Reload past scores to include the updated one
                        Task {
                            await self.loadPastScores()
                        }
                        
                        self.isLoading = false
                    }
                }
            } catch let error as ReadinessError {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = .unknownError(error)
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Health Data Access
    
    func fetchRestingHeartRate() async throws -> Double {
        return try await readinessService.fetchRestingHeartRate()
    }
    
    func fetchSleepData() async throws -> (hours: Double, quality: Int) {
        let sleepData = try await readinessService.fetchSleepData()
        return (hours: sleepData.hours, quality: sleepData.quality)
    }
    
    // MARK: - Initial Setup Methods
    
    @MainActor
    func checkAndPerformInitialSetup() async {
        // Check if initial data import has been completed
        if !readinessService.hasCompletedInitialDataImport {
            print("🚀 VIEWMODEL: Initial data import needed")
            await performInitialDataImport()
        } else {
            // Initial setup already completed, just load regular data
            await loadTodaysReadinessScore()
            await loadPastScores()
        }
    }
    
    @MainActor
    private func performInitialDataImport() async {
        isPerformingInitialSetup = true
        initialSetupProgress = 0.0
        initialSetupStatus = "Preparing to import historical data..."
        
        do {
            try await readinessService.performInitialDataImportAndSetup { [weak self] progress, status in
                Task { @MainActor in
                    self?.initialSetupProgress = progress
                    self?.initialSetupStatus = status
                }
            }
            
            // After successful import, load the data
            await loadTodaysReadinessScore()
            await loadPastScores()
            
        } catch is CancellationError {
            self.initialSetupStatus = "Cancelled"
        } catch {
            self.error = error as? ReadinessError ?? .unknownError(error)
            print("❌ VIEWMODEL: Initial data import failed: \(error)")
        }
        
        isPerformingInitialSetup = false
    }

    // MARK: - Manual Historical Import & Backfill (Debug/Advanced)
    @MainActor
    func startHistoricalImportAndBackfill() {
        isPerformingInitialSetup = true
        initialSetupProgress = 0.0
        initialSetupStatus = "Preparing to import historical data..."
        
        activeOperationTask?.cancel()
        activeOperationTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                try await self.readinessService.performInitialDataImportAndSetup { [weak self] progress, status in
                    Task { @MainActor in
                        self?.initialSetupProgress = progress
                        self?.initialSetupStatus = status
                    }
                }
                await self.loadTodaysReadinessScore()
                await self.loadPastScores()
            } catch is CancellationError {
                await MainActor.run {
                    self.initialSetupStatus = "Cancelled"
                }
            } catch {
                await MainActor.run {
                    self.error = error as? ReadinessError ?? .unknownError(error)
                }
            }
            await MainActor.run {
                self.isPerformingInitialSetup = false
            }
        }
    }

    @MainActor
    func cancelActiveOperation() {
        initialSetupStatus = "Cancelling..."
        activeOperationTask?.cancel()
    }

    @MainActor
    func startRecalculateAllPastScores(days: Int = 30) {
        isLoading = true
        error = nil
        
        activeOperationTask?.cancel()
        activeOperationTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let scores = try await self.calculationViewModel.recalculateHistoricalReadiness(days: days) { [weak self] progress, status in
                    Task { @MainActor in
                        self?.initialSetupProgress = progress
                        self?.initialSetupStatus = status
                    }
                }
                await MainActor.run {
                    self.pastScores = scores
                    self.isLoading = false
                    Task { await self.loadTodaysReadinessScore() }
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.initialSetupStatus = "Cancelled"
                    self.isLoading = false
                }
            } catch let error as ReadinessError {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = .unknownError(error)
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - UI Helper Properties
    
    var readinessModeDescription: String {
        return readinessMode.description
    }
    
    var baselinePeriodDescription: String {
        return baselinePeriod.description
    }
    
    var readinessColor: Color {
        return readinessCategory.color
    }
    
    var formattedHRVDeviation: String {
        return String(format: "%.1f%%", hrvDeviation)
    }
    
    var hrvDeviationColor: Color {
        // Updated for FR-3 algorithm thresholds
        if hrvDeviation > 10 {
            return .green        // >10% above baseline (Supercompensation)
        } else if hrvDeviation >= -3 {
            return .green        // Within ±3% or up to 10% above (Optimal range)
        } else if hrvDeviation >= -7 {
            return .yellow       // 3-7% below baseline (Moderate)
        } else if hrvDeviation >= -10 {
            return .orange       // 7-10% below baseline (Low)
        } else {
            return .red          // >10% below baseline (Fatigue)
        }
    }
    
    var lastCalculationDescription: String {
        guard let timestamp = lastCalculationTime else {
            return "Not yet calculated"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    var baselineDataStatus: String {
        let daysAvailable = readinessService.getReadinessScoresForPastDays(baselinePeriod.rawValue).count
        let minDays = readinessService.minimumDaysForBaseline
        
        if daysAvailable < minDays {
            return "Need at least \(minDays) days of data for baseline (have \(daysAvailable))"
        } else {
            return "Baseline established with \(daysAvailable) days of data"
        }
    }
    
    var hasBaselineData: Bool {
        let daysAvailable = readinessService.getReadinessScoresForPastDays(baselinePeriod.rawValue).count
        return daysAvailable >= readinessService.minimumDaysForBaseline
    }
    
    // MARK: - Color Management
    
    // Get solid background color for a readiness score
    func getColor(for score: Double, isDarkMode: Bool) -> Color {
        let category = ReadinessCategory.forScore(score)
        
        switch category {
        case .optimal:
            return isDarkMode ? Color.green.opacity(0.8) : Color.green.opacity(0.7)
        case .moderate:
            return isDarkMode ? Color.yellow.opacity(0.8) : Color.yellow.opacity(0.7)
        case .low:
            return isDarkMode ? Color.orange.opacity(0.8) : Color.orange.opacity(0.7)
        case .fatigue:
            return isDarkMode ? Color.red.opacity(0.8) : Color.red.opacity(0.7)
        default:
            return isDarkMode ? Color.gray.opacity(0.6) : Color.gray.opacity(0.4)
        }
    }
    
    // Get gradient for a readiness score (medium opacity for UI elements)
    func getGradient(for score: Double, isDarkMode: Bool) -> LinearGradient {
        let category = ReadinessCategory.forScore(score)
        
        let gradientColors: [Color]
        
        switch category {
        case .optimal:
            gradientColors = isDarkMode ? 
                [Color.green.opacity(0.7), Color.green.opacity(0.3)] :
                [Color.green.opacity(0.6), Color.green.opacity(0.2)]
        case .moderate:
            gradientColors = isDarkMode ?
                [Color.yellow.opacity(0.7), Color.yellow.opacity(0.3)] :
                [Color.yellow.opacity(0.6), Color.yellow.opacity(0.2)]
        case .low:
            gradientColors = isDarkMode ?
                [Color.orange.opacity(0.7), Color.orange.opacity(0.3)] :
                [Color.orange.opacity(0.6), Color.orange.opacity(0.2)]
        case .fatigue:
            gradientColors = isDarkMode ?
                [Color.red.opacity(0.7), Color.red.opacity(0.3)] :
                [Color.red.opacity(0.6), Color.red.opacity(0.2)]
        default:
            gradientColors = isDarkMode ?
                [Color.gray.opacity(0.6), Color.gray.opacity(0.2)] :
                [Color.gray.opacity(0.4), Color.gray.opacity(0.1)]
        }
        
        return LinearGradient(
            gradient: Gradient(colors: gradientColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Get subtle background gradient for screen backgrounds (light opacity)
    func getBackgroundGradient(for score: Double, isDarkMode: Bool) -> LinearGradient {
        let category = ReadinessCategory.forScore(score)
        
        let gradientColors: [Color]
        
        switch category {
        case .optimal:
            gradientColors = [Color.green.opacity(0.1), Color.green.opacity(0.05)]
        case .moderate:
            gradientColors = [Color.yellow.opacity(0.1), Color.yellow.opacity(0.05)]
        case .low:
            gradientColors = [Color.orange.opacity(0.1), Color.orange.opacity(0.05)]
        case .fatigue:
            gradientColors = [Color.red.opacity(0.1), Color.red.opacity(0.05)]
        default:
            gradientColors = [Color.gray.opacity(0.1), Color.gray.opacity(0.05)]
        }
        
        return LinearGradient(
            gradient: Gradient(colors: gradientColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Get text color for score display (ensures good contrast)
    func getTextColor(for score: Double) -> Color {
        let category = ReadinessCategory.forScore(score)
        
        switch category {
        case .optimal, .moderate:
            return .black
        case .low, .fatigue, .unknown:
            return .white
        }
    }
} 
