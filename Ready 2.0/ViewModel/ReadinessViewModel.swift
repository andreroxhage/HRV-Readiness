import Foundation
import SwiftUI
import Combine
import CoreData

// TODO: Import needs to be configured with build settings

class ReadinessViewModel: ObservableObject {
    @Published var readinessScore: Double = 0
    @Published var readinessCategory: ReadinessCategory = .unknown
    @Published var hrvBaseline: Double = 0
    @Published var hrvDeviation: Double = 0
    @Published var rhrAdjustment: Double = 0
    @Published var sleepAdjustment: Double = 0
    @Published var isLoading: Bool = false
    @Published var error: ReadinessError?
    @Published var pastScores: [ReadinessScore] = []
    @Published var readinessMode: ReadinessMode = .morning
    @Published var baselinePeriod: BaselinePeriod = .sevenDays
    @Published var useRHRAdjustment: Bool = true
    @Published var useSleepAdjustment: Bool = true
    @Published var lastCalculationTime: Date?
    
    public let readinessService = ReadinessService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // UserDefaults for settings
    private let userDefaults = UserDefaults.standard
    
    init() {
        // Load the current readiness mode from UserDefaults
        if let modeString = userDefaults.string(forKey: "readinessMode"),
           let mode = ReadinessMode(rawValue: modeString) {
            self.readinessMode = mode
            print("DEBUG: Initialized ReadinessViewModel with mode: \(mode)")
        } else {
            print("DEBUG: Using default readiness mode: \(readinessMode)")
        }
        
        // Load baseline period from UserDefaults
        let baselineDays = userDefaults.integer(forKey: "baselinePeriod")
        if let period = BaselinePeriod(rawValue: baselineDays) {
            self.baselinePeriod = period
            print("DEBUG: Initialized ReadinessViewModel with baseline period: \(period.description)")
        } else {
            // Set default baseline period
            self.baselinePeriod = .sevenDays
            userDefaults.set(BaselinePeriod.sevenDays.rawValue, forKey: "baselinePeriod")
            print("DEBUG: Using default baseline period: \(baselinePeriod.description)")
        }
        
        // Load adjustment settings
        self.useRHRAdjustment = userDefaults.bool(forKey: "useRHRAdjustment")
        self.useSleepAdjustment = userDefaults.bool(forKey: "useSleepAdjustment")
        
        // Default values if not set
        if !userDefaults.contains(key: "useRHRAdjustment") {
            self.useRHRAdjustment = true
            userDefaults.set(true, forKey: "useRHRAdjustment")
        }
        
        if !userDefaults.contains(key: "useSleepAdjustment") {
            self.useSleepAdjustment = true
            userDefaults.set(true, forKey: "useSleepAdjustment")
        }
        
        // Load last calculation time
        if let lastCalcTime = userDefaults.object(forKey: "lastCalculationTime") as? Date {
            self.lastCalculationTime = lastCalcTime
        }
        
        // Observe changes to the readiness mode setting
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                print("DEBUG: UserDefaults changed notification received")
                
                // Check for mode changes
                if let modeString = self.userDefaults.string(forKey: "readinessMode"),
                   let mode = ReadinessMode(rawValue: modeString),
                   mode != self.readinessMode {
                    print("DEBUG: Updating readiness mode from \(self.readinessMode) to \(mode)")
                    self.readinessMode = mode
                    self.recalculateReadiness()
                }
                
                // Check for baseline period changes
                let baselineDays = self.userDefaults.integer(forKey: "baselinePeriod")
                if let period = BaselinePeriod(rawValue: baselineDays),
                   period != self.baselinePeriod {
                    print("DEBUG: Updating baseline period from \(self.baselinePeriod.description) to \(period.description)")
                    self.baselinePeriod = period

                }
                
                // Check for adjustment toggles
                let newUseRHR = self.userDefaults.bool(forKey: "useRHRAdjustment")
                if newUseRHR != self.useRHRAdjustment {
                    print("DEBUG: Updating RHR adjustment setting from \(self.useRHRAdjustment) to \(newUseRHR)")
                    self.useRHRAdjustment = newUseRHR
                    self.recalculateReadiness()
                }
                
                let newUseSleep = self.userDefaults.bool(forKey: "useSleepAdjustment")
                if newUseSleep != self.useSleepAdjustment {
                    print("DEBUG: Updating sleep adjustment setting from \(self.useSleepAdjustment) to \(newUseSleep)")
                    self.useSleepAdjustment = newUseSleep
                    self.recalculateReadiness()
                }
            }
            .store(in: &cancellables)
        
        // Load today's readiness score if available
        loadTodaysReadinessScore()
        
        // Load past scores
        loadPastScores(days: 30)
    }
    
    private func recalculateReadiness() {
        Task {
            do {
                let healthData = HealthKitManager.shared
                
                await MainActor.run {
                    self.isLoading = true
                    // Clear any existing error to prevent stale errors from showing up
                    self.error = nil
                }
                
                // Fetch health data with proper error handling
                var restingHeartRate: Double = 0
                var sleepData = try await healthData.fetchSleepData()
                
                do {
                    restingHeartRate = try await healthData.fetchRestingHeartRate()
                } catch {
                    print("DEBUG: Could not fetch resting heart rate: \(error.localizedDescription)")
                    // Continue with restingHeartRate = 0, which the calculation will handle gracefully
                }
                
                // Only proceed with calculation if we got some valid health data
                let _ = try await readinessService.processAndSaveTodaysDataForCurrentMode(
                    restingHeartRate: restingHeartRate,
                    sleepHours: sleepData.hours,
                    sleepQuality: sleepData.quality,
                    forceRecalculation: true
                )
                
                // Reload score and past data
                await MainActor.run {
                    self.loadTodaysReadinessScore()
                    self.loadPastScores(days: 30)
                    self.isLoading = false
                }
            } catch let healthKitError as HealthKitManager.HealthKitError {
                // Handle specific HealthKit errors
                await MainActor.run {
                    print("DEBUG: HealthKit error: \(healthKitError)")
                    
                    // Don't show an error for common "no data" scenarios
                    if healthKitError.localizedDescription.contains("no data available") {
                        print("DEBUG: No health data available, continuing without showing error")
                        self.isLoading = false
                        
                        // Still try to load whatever data we have
                        self.loadTodaysReadinessScore()
                        self.loadPastScores(days: 30)
                    } else {
                        self.error = .dataProcessingFailed(
                            component: "health data", 
                            reason: "Could not access health data: \(healthKitError.localizedDescription)"
                        )
                        self.isLoading = false
                    }
                }
            } catch let readinessError as ReadinessError {
                await MainActor.run {
                    // Don't show historicalDataIncomplete errors with partialResult=true
                    // as these aren't really errors, just informational
                    if case .historicalDataIncomplete(_, _, let partialResult) = readinessError, partialResult {
                        print("DEBUG: Partial data available, continuing without showing error")
                        self.isLoading = false
                        
                        // Still try to load whatever data we have
                        self.loadTodaysReadinessScore()
                        self.loadPastScores(days: 30)
                    } else {
                        self.error = readinessError
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    // Filter out common "no data" errors that aren't critical
                    if error.localizedDescription.contains("no data available") || 
                       error.localizedDescription.contains("specified predicate") {
                        print("DEBUG: Non-critical error during calculation: \(error.localizedDescription)")
                        self.isLoading = false
                        
                        // Still try to load whatever data we have
                        self.loadTodaysReadinessScore() 
                        self.loadPastScores(days: 30)
                    } else {
                        self.error = .unknownError(error)
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    func loadTodaysReadinessScore() {
        Task { @MainActor in
            print("DEBUG: Loading today's readiness score")
            if let score = readinessService.getTodaysReadinessScore() {
                print("DEBUG: Found readiness score for today: \(score.score)")
                self.readinessScore = score.score
                self.readinessCategory = ReadinessCategory(rawValue: score.readinessCategory ?? "Moderate") ?? .moderate
                self.hrvBaseline = score.hrvBaseline
                self.hrvDeviation = score.hrvDeviation
                self.rhrAdjustment = score.rhrAdjustment
                self.sleepAdjustment = score.sleepAdjustment
                
                // Get calculation timestamp
                if let timestamp = score.calculationTimestamp {
                    self.lastCalculationTime = timestamp
                }
                
                print("DEBUG: HRV baseline: \(score.hrvBaseline), deviation: \(score.hrvDeviation)")
                
                // Update the readiness mode if it's different
                if let modeString = score.readinessMode,
                   let mode = ReadinessMode(rawValue: modeString),
                   mode != self.readinessMode {
                    print("DEBUG: Updating readiness mode from score: \(mode)")
                    self.readinessMode = mode
                    userDefaults.set(mode.rawValue, forKey: "readinessMode")
                }
                
                // Update baseline period if different
                if let period = BaselinePeriod(rawValue: Int(score.baselinePeriod)),
                   period != self.baselinePeriod {
                    print("DEBUG: Updating baseline period from score: \(period.description)")
                    self.baselinePeriod = period
                    userDefaults.set(period.rawValue, forKey: "baselinePeriod")
                }
            } else {
                print("DEBUG: No readiness score found for today")
            }
        }
    }
    
    func loadPastScores(days: Int = 30) {
        Task { @MainActor in
            print("DEBUG: Loading past scores for the last \(days) days")
            let scores = readinessService.getReadinessScoresForPastDays(days)
            self.pastScores = scores
            
            // Also recalculates the baseline HRV
            let _ = readinessService.calculateHRVBaseline()
        }
    }
    
    // Helper function to validate input data in a sendable way
    private func validateInputData(restingHeartRate: Double, sleepHours: Double) async -> (isValid: Bool, missingMetrics: [String], availableMetrics: [String]) {
        var missingMetrics: [String] = []
        var availableMetrics: [String] = []
        
        if restingHeartRate <= 0 { 
            missingMetrics.append("Resting Heart Rate") 
        } else {
            availableMetrics.append("Resting Heart Rate (\(String(format: "%.0f", restingHeartRate))bpm)")
        }
        
        if sleepHours <= 0 { 
            missingMetrics.append("Sleep Duration") 
        } else {
            availableMetrics.append("Sleep Duration (\(String(format: "%.1f", sleepHours))h)")
        }
        
        // Always return valid=true even if metrics are missing
        // This allows calculation to proceed with whatever data is available
        return (true, missingMetrics, availableMetrics)
    }
    
    func calculateAndSaveReadinessScoreForCurrentMode(restingHeartRate: Double, sleepHours: Double, sleepQuality: Int, forceRecalculation: Bool = false) {
        isLoading = true
        error = nil
        
        print("DEBUG: Calculating readiness score with current settings")
        print("DEBUG: Mode: \(readinessMode), Baseline period: \(baselinePeriod.rawValue) days")
        print("DEBUG: Use RHR adjustment: \(useRHRAdjustment), Use sleep adjustment: \(useSleepAdjustment)")
        
        // Check for any missing metrics (for logging purposes)
        var missingDataWarning = ""
        if restingHeartRate <= 0 {
            missingDataWarning += "Resting heart rate data is missing. "
        }
        if sleepHours <= 0 {
            missingDataWarning += "Sleep data is missing. "
        }
        
        if !missingDataWarning.isEmpty {
            print("WARNING: \(missingDataWarning)Proceeding with available data only.")
        }
        
        // Process on a background thread
        Task {
            do {
                // Validate input data - but always proceed with calculation
                let validationResult = await validateInputData(restingHeartRate: restingHeartRate, sleepHours: sleepHours)
                
                // Log any missing metrics but continue with calculation
                if !validationResult.missingMetrics.isEmpty {
                    print("DEBUG: Missing metrics: \(validationResult.missingMetrics.joined(separator: ", "))")
                    print("DEBUG: Available metrics: \(validationResult.availableMetrics.joined(separator: ", "))")
                }
                
                if let score = try await readinessService.processAndSaveTodaysDataForCurrentMode(
                    restingHeartRate: restingHeartRate,
                    sleepHours: sleepHours,
                    sleepQuality: sleepQuality,
                    forceRecalculation: forceRecalculation
                ) {
                    // Update UI on main thread
                    await MainActor.run {
                        print("DEBUG: Received new readiness score: \(score.score)")
                        print("DEBUG: HRV baseline: \(score.hrvBaseline), deviation: \(score.hrvDeviation)")
                        
                        self.readinessScore = score.score
                        self.readinessCategory = ReadinessCategory(rawValue: score.readinessCategory ?? "Moderate") ?? .moderate
                        self.hrvBaseline = score.hrvBaseline
                        self.hrvDeviation = score.hrvDeviation
                        self.rhrAdjustment = score.rhrAdjustment
                        self.sleepAdjustment = score.sleepAdjustment
                        self.isLoading = false
                        
                        // Update last calculation time
                        if let timestamp = score.calculationTimestamp {
                            self.lastCalculationTime = timestamp
                        } else {
                            self.lastCalculationTime = Date()
                        }
                        
                        // Reload past scores
                        self.loadPastScores(days: 30)
                    }
                } else {
                    await MainActor.run {
                        self.error = .dataProcessingFailed(component: "readiness score", reason: "Unable to process calculation")
                        self.isLoading = false
                    }
                }
            } catch let error as ReadinessError {
                await MainActor.run {
                    print("DEBUG: ReadinessError calculating readiness score: \(error)")
                    self.error = error
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    print("DEBUG: Unknown error calculating readiness score: \(error)")
                    self.error = .unknownError(error)
                    self.isLoading = false
                }
            }
        }
    }
    
    // Get the 7-day trend of readiness scores
    func getReadinessTrend() -> [Double] {
        let scores = readinessService.getReadinessScoresForPastDays(7)
        return scores.map { $0.score }
    }
    
    // Update settings
    func updateBaselinePeriod(_ period: BaselinePeriod) {
        print("DEBUG: Updating baseline period to \(period.description)")
        userDefaults.set(period.rawValue, forKey: "baselinePeriod")
        self.baselinePeriod = period
        // Trigger recalculation of all past scores
        recalculateAllPastScores()
        // The observer will still trigger today's recalculation
    }
    
    // Update baseline period from Int (for use with @AppStorage)
    func updateBaselinePeriod(_ days: Int) {
        print("DEBUG: Updating baseline period to \(days) days")
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
        print("DEBUG: Updating RHR adjustment to \(enabled)")
        userDefaults.set(enabled, forKey: "useRHRAdjustment")
        self.useRHRAdjustment = enabled
        // The observer will trigger recalculation
    }
    
    func updateSleepAdjustment(_ enabled: Bool) {
        print("DEBUG: Updating sleep adjustment to \(enabled)")
        userDefaults.set(enabled, forKey: "useSleepAdjustment")
        self.useSleepAdjustment = enabled
        // The observer will trigger recalculation
    }
    
    // Update the readiness mode from a string value
    func updateReadinessMode(_ modeString: String) {
        print("DEBUG: Updating readiness mode from string: \(modeString)")
        
        // Clear any existing error to prevent unwanted alerts during mode changes
        Task { @MainActor in
            self.error = nil
        }
        
        if let mode = ReadinessMode(rawValue: modeString), mode != self.readinessMode {
            print("DEBUG: Changing readiness mode from \(self.readinessMode) to \(mode)")
            
            Task { @MainActor in
                // Update the mode
                self.readinessMode = mode
                
                // Save to UserDefaults
                userDefaults.set(modeString, forKey: "readinessMode")
            }
            
            // The observer will handle the recalculation, no need to do it here
        } else {
            print("DEBUG: Readiness mode unchanged or invalid mode string: \(modeString)")
        }
    }
    
    // Force recalculation of readiness score
    func recalculateReadinessScore() {
        print("DEBUG: Forcing recalculation of readiness score")
        Task {
            do {
                await MainActor.run {
                    self.isLoading = true
                    self.error = nil
                }
                
                let _ = try await readinessService.recalculateTodaysReadiness()
                
                await MainActor.run {
                    self.loadTodaysReadinessScore()
                    self.loadPastScores(days: 30)
                    self.isLoading = false
                }
            } catch let readinessError as ReadinessError {
                await MainActor.run {
                    // Filter out common non-critical errors
                    if case .historicalDataIncomplete(_, _, let partialResult) = readinessError, partialResult {
                        print("DEBUG: Partial data available, continuing without showing error")
                        // Still try to load whatever data we have
                        self.loadTodaysReadinessScore()
                        self.loadPastScores(days: 30)
                    } else {
                        print("DEBUG: ReadinessError calculating readiness score: \(readinessError)")
                        self.error = readinessError
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    // Filter out common "no data" errors that aren't critical
                    if error.localizedDescription.contains("no data available") || 
                       error.localizedDescription.contains("specified predicate") {
                        print("DEBUG: Non-critical error during calculation: \(error.localizedDescription)")
                        // Still try to load whatever data we have
                        self.loadTodaysReadinessScore() 
                        self.loadPastScores(days: 30)
                    } else {
                        self.error = .unknownError(error)
                    }
                    self.isLoading = false
                }
            }
        }
    }
    
    // Recalculate readiness for a specific date
    func recalculateReadinessForDate(_ date: Date) {
        print("DEBUG: Forcing recalculation of readiness score for date: \(date)")
        Task {
            do {
                await MainActor.run {
                    self.isLoading = true
                    self.error = nil
                }
                
                let _ = try await readinessService.recalculateReadinessForDate(date)
                
                await MainActor.run {
                    // If recalculating today's score, update the current view
                    if Calendar.current.isDateInToday(date) {
                        self.loadTodaysReadinessScore()
                    }
                    // Reload past scores to reflect the changes
                    self.loadPastScores(days: 30)
                    self.isLoading = false
                }
            } catch let error as ReadinessError {
                await MainActor.run {
                    print("DEBUG: Error recalculating date \(date): \(error)")
                    self.error = error
                    
                    // Still load past scores to show what we have
                    self.loadPastScores(days: 30)
                    self.isLoading = false
                    
                    // Special cases for user feedback
                    if case .historicalDataMissing = error {
                        print("DEBUG: Missing data error - guided user to Health app")
                    } else if case .historicalDataIncomplete = error {
                        print("DEBUG: Incomplete data - partial score calculated")
                    }
                }
            } catch {
                await MainActor.run {
                    print("DEBUG: Unknown error calculating readiness for date \(date): \(error)")
                    self.error = .unknownError(error)
                    self.isLoading = false
                }
            }
        }
    }
    
    // Recalculate all readiness scores for the past N days
    func recalculateAllPastScores(days: Int = 30) {
        print("DEBUG: Recalculating all readiness scores for the past \(days) days")
        Task {
            do {
                await MainActor.run {
                    self.isLoading = true
                    self.error = nil
                }
                
                let calendar = Calendar.current
                let today = Date()
                
                var processingErrors: [String] = []
                var successfulDates = 0
                var failedDates = 0
                
                // Process each day
                for dayOffset in 0..<days {
                    let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
                    print("DEBUG: Processing day \(dayOffset + 1) of \(days): \(date)")
                    
                    do {
                        let _ = try await readinessService.recalculateReadinessForDate(date)
                        successfulDates += 1
                    } catch let error as ReadinessError {
                        print("DEBUG: Error processing date \(date): \(error.localizedDescription)")
                        
                        // Format the date for error message
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateStyle = .short
                        let dateString = dateFormatter.string(from: date)
                        
                        // Add this date's error to our list
                        processingErrors.append("\(dateString): \(error.localizedDescription)")
                        failedDates += 1
                        
                        // Continue with the next date
                    } catch {
                        print("DEBUG: Unknown error processing date \(date): \(error.localizedDescription)")
                        failedDates += 1
                    }
                }
                
                await MainActor.run {
                    self.loadTodaysReadinessScore()
                    self.loadPastScores(days: days)
                    
                    // If we had any errors, create a summary error
                    if !processingErrors.isEmpty {
                        // Limit to first 3 errors to avoid overwhelming the user
                        let errorSamples = Array(processingErrors.prefix(3))
                        let additional = processingErrors.count > 3 ? " (and \(processingErrors.count - 3) more)" : ""
                        
                        self.error = ReadinessError.dataProcessingFailed(
                            component: "historical data",
                            reason: "Successfully processed \(successfulDates) days, failed on \(failedDates) days. Issues: \(errorSamples.joined(separator: "; "))\(additional)"
                        )
                    } else {
                        // Clear error if all was successful
                        self.error = nil
                    }
                    
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    if let readinessError = error as? ReadinessError {
                        self.error = readinessError
                    } else {
                        self.error = .unknownError(error)
                    }
                    self.isLoading = false
                }
            }
        }
    }
    
    // Get a description of the baseline data status
    var baselineDataStatus: String {
        let daysAvailable = readinessService.getReadinessScoresForPastDays(baselinePeriod.rawValue).count
        let minDays = readinessService.minimumDaysForBaseline
        
        if daysAvailable < minDays {
            return "Need at least \(minDays) days of data for baseline (have \(daysAvailable))"
        } else {
            return "Baseline established with \(daysAvailable) days of data"
        }
    }
    
    // Check if baseline data is sufficient
    var hasBaselineData: Bool {
        let daysAvailable = readinessService.getReadinessScoresForPastDays(baselinePeriod.rawValue).count
        return daysAvailable >= readinessService.minimumDaysForBaseline
    }
    
    // MARK: - UI Helper Methods
    
    // Get the color for the current readiness category
    var categoryColor: Color {
        if readinessScore == 0 {
            return .gray
        }
        switch readinessCategory {
        case .unknown:
            return .gray
        case .optimal:
            return .green
        case .moderate:
            return .yellow
        case .low:
            return .orange
        case .fatigue:
            return .red
        }
    }

    // Get a gradient color based on the score value (0-100)
    func getGradientColor(for score: Double) -> Color {
        if score <= 0 {
            return Color.gray.opacity(0.5)
        }
        
        // Map score to the appropriate color using a gradient with less vibrant colors
        if score >= 80 {
            // Muted green range (80-100)
            let intensity = min(1.0, (score - 80) / 20)
            return Color(red: 0.4, green: 0.6, blue: 0.4).opacity(0.7 + (intensity * 0.3))
        } else if score >= 50 {
            // Muted yellow/gold range (50-79)
            let intensity = (score - 50) / 30
            return Color(
                red: 0.7 + (0.1 * (1 - intensity)),
                green: 0.7,
                blue: 0.3 * (1 - intensity)
            )
        } else if score >= 30 {
            // Muted orange range (30-49)
            let intensity = (score - 30) / 20
            return Color(
                red: 0.8,
                green: 0.5 + (0.2 * intensity),
                blue: 0.2
            )
        } else {
            // Muted red range (0-29)
            let intensity = min(1.0, score / 30)
            return Color(
                red: 0.7,
                green: 0.2 + (0.3 * intensity),
                blue: 0.2
            )
        }
    }

    func getGradientBackgroundColor(for score: Double, isDarkMode: Bool) -> Color {
        if score <= 0 {
            return isDarkMode ? Color.gray.opacity(0.3) : Color.gray.opacity(0.1)
        }
        
        if score >= 80 {
            // Muted green range (80-100)
            if isDarkMode {
                return Color(red: 0.2, green: 0.4, blue: 0.2).opacity(0.4)
            } else {
                return Color(red: 0.7, green: 0.8, blue: 0.7).opacity(0.2)
            }
        } else if score >= 50 {
            // Muted yellow/gold range (50-79)
            if isDarkMode {
                return Color(red: 0.4, green: 0.4, blue: 0.2).opacity(0.4)
            } else {
                return Color(red: 0.8, green: 0.8, blue: 0.6).opacity(0.2)
            }
        } else if score >= 30 {
            // Muted orange range (30-49)
            if isDarkMode {
                return Color(red: 0.5, green: 0.3, blue: 0.1).opacity(0.4)
            } else {
                return Color(red: 0.9, green: 0.7, blue: 0.5).opacity(0.2)
            }
        } else {
            // Muted red range (0-29)
            if isDarkMode {
                return Color(red: 0.5, green: 0.2, blue: 0.2).opacity(0.4)
            } else {
                return Color(red: 0.8, green: 0.6, blue: 0.6).opacity(0.2)
            }
        }
    }
    
    // Format the readiness score as a string
    var formattedScore: String {
        return String(format: "%.0f", readinessScore)
    }
    
    // Format the HRV deviation as a string with sign
    var formattedHRVDeviation: String {
        let sign = hrvDeviation >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", hrvDeviation))%"
    }
    
    // Get the color for the HRV deviation
    var hrvDeviationColor: Color {
        if hrvBaseline == 0 || hrvDeviation == 0 {
            return .gray
        }
        if hrvDeviation >= 0 {
            return .green
        } else if hrvDeviation > -7 {
            return .yellow
        } else if hrvDeviation > -10 {
            return .orange
        } else {
            return .red
        }
    }
    
    // Get the description for the current readiness mode
    var readinessModeDescription: String {
        switch readinessMode {
        case .morning:
            return "Morning Readiness (00:00-10:00)"
        case .rolling:
            return "Rolling Readiness (Last 6 hours)"
        }
    }
    
    // Get the description for the baseline period
    var baselinePeriodDescription: String {
        return baselinePeriod.description
    }
    
    // Format the last calculation time as a string
    var formattedLastCalculationTime: String {
        guard let time = lastCalculationTime else { return "Not calculated yet" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        return "Last calculated: \(formatter.string(from: time))"
    }
} 
