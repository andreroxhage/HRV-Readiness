import Foundation
import SwiftUI
import Combine

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
        
        // Setup observers for settings changes
        setupObservers()
        
        // Load settings from UserDefaults but don't trigger initial setup yet
        // Initial setup will be triggered when ContentView appears for users who completed onboarding
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Observe changes to UserDefaults
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                print("⚙️ VIEWMODEL: UserDefaults changed, checking for setting updates...")
                
                // Check for readiness mode changes
                let newMode = self.userDefaultsManager.readinessMode
                if newMode != self.readinessMode {
                    print("🔄 VIEWMODEL: Readiness mode changed from \(self.readinessMode.rawValue) to \(newMode.rawValue)")
                    self.readinessMode = newMode
                    self.recalculateReadiness()
                }
                
                // Check for baseline period changes
                let newPeriod = self.userDefaultsManager.baselinePeriod
                if newPeriod != self.baselinePeriod {
                    print("🔄 VIEWMODEL: Baseline period changed from \(self.baselinePeriod.rawValue) to \(newPeriod.rawValue)")
                    self.baselinePeriod = newPeriod
                    self.scheduleHistoricalRecalculation(reason: "baseline period change")
                }
                
                // Check for adjustment toggles
                let newUseRHR = self.userDefaultsManager.useRHRAdjustment
                if newUseRHR != self.useRHRAdjustment {
                    print("💓 VIEWMODEL: RHR adjustment changed from \(self.useRHRAdjustment) to \(newUseRHR)")
                    self.useRHRAdjustment = newUseRHR
                    self.scheduleHistoricalRecalculation(reason: "RHR adjustment change")
                }
                
                let newUseSleep = self.userDefaultsManager.useSleepAdjustment
                if newUseSleep != self.useSleepAdjustment {
                    print("😴 VIEWMODEL: Sleep adjustment changed from \(self.useSleepAdjustment) to \(newUseSleep)")
                    self.useSleepAdjustment = newUseSleep
                    self.scheduleHistoricalRecalculation(reason: "sleep adjustment change")
                }
            }
            .store(in: &cancellables)
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
    
    // MARK: - Settings Management
    
    func updateReadinessMode(_ modeString: String) {
        if let mode = ReadinessMode(rawValue: modeString), mode != self.readinessMode {
            self.readinessMode = mode
            userDefaultsManager.readinessMode = mode
            // The observer will handle recalculation
        }
    }
    
    func updateBaselinePeriod(_ period: BaselinePeriod) {
        if period != self.baselinePeriod {
            self.baselinePeriod = period
            userDefaultsManager.baselinePeriod = period
            // The observer will handle recalculation
        }
    }
    
    func updateBaselinePeriod(_ days: Int) {
        let period: BaselinePeriod
        switch days {
        case 14:
            period = .fourteenDays
        case 30:
            period = .thirtyDays
        default:
            period = .sevenDays
        }
        updateBaselinePeriod(period)
    }
    
    func updateRHRAdjustment(_ enabled: Bool) {
        if enabled != self.useRHRAdjustment {
            self.useRHRAdjustment = enabled
            userDefaultsManager.useRHRAdjustment = enabled
            // The observer will handle recalculation
        }
    }
    
    func updateSleepAdjustment(_ enabled: Bool) {
        if enabled != self.useSleepAdjustment {
            self.useSleepAdjustment = enabled
            userDefaultsManager.useSleepAdjustment = enabled
            // The observer will handle recalculation
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
    
    // MARK: - Debounced Recalculation
    
    /// Schedules a historical recalculation with debouncing to avoid excessive recalculation
    private func scheduleHistoricalRecalculation(reason: String) {
        print("⏱️ VIEWMODEL: Scheduling debounced recalculation for: \(reason)")
        
        // Set loading state immediately for user feedback
        Task { @MainActor in
            self.isLoading = true
            self.error = nil
        }
        
        // Cancel any existing timer
        recalculationTimer?.invalidate()
        
        // Schedule new recalculation after 1 second delay
        recalculationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            print("🔄 VIEWMODEL: Executing debounced historical recalculation")
            
            Task { @MainActor in
                // First recalculate today's score for immediate feedback
                await self.performQuickRecalculation()
                
                // Then do the expensive historical recalculation in the background
                Task.detached {
                    do {
                        try await self.readinessService.recalculateAllReadinessScores()
                        
                        // Update UI on main thread
                        await MainActor.run {
                            Task {
                                await self.loadTodaysReadinessScore()
                                await self.loadPastScores()
                                self.isLoading = false
                            }
                        }
                    } catch {
                        await MainActor.run {
                            self.error = error as? ReadinessError ?? .unknownError(error)
                            self.isLoading = false
                            print("❌ VIEWMODEL: Historical recalculation failed: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    /// Quick recalculation for immediate user feedback
    @MainActor
    private func performQuickRecalculation() async {
        do {
            if let score = try await calculationViewModel.recalculateReadinessForDate(Date()) {
                self.readinessScore = score.score
                self.readinessCategory = score.category
                self.hrvBaseline = score.hrvBaseline
                self.hrvDeviation = score.hrvDeviation
                self.rhrAdjustment = score.rhrAdjustment
                self.sleepAdjustment = score.sleepAdjustment
                self.lastCalculationTime = score.calculationTimestamp
            }
        } catch {
            print("⚠️ VIEWMODEL: Quick recalculation failed, will be updated after full recalculation")
        }
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
            
        } catch {
            self.error = error as? ReadinessError ?? .unknownError(error)
            print("❌ VIEWMODEL: Initial data import failed: \(error)")
        }
        
        isPerformingInitialSetup = false
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
