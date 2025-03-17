import Foundation
import SwiftUI
import Combine
import CoreData

class ReadinessViewModel: ObservableObject {
    @Published var readinessScore: Double = 0
    @Published var readinessCategory: ReadinessCategory = .moderate
    @Published var hrvBaseline: Double = 0
    @Published var hrvDeviation: Double = 0
    @Published var rhrAdjustment: Double = 0
    @Published var sleepAdjustment: Double = 0
    @Published var isLoading: Bool = false
    @Published var error: ReadinessError?
    @Published var pastScores: [ReadinessScore] = []
    @Published var readinessMode: ReadinessMode = .morning
    
    private let readinessService = ReadinessService.shared
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
        
        // Observe changes to the readiness mode setting
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                print("DEBUG: UserDefaults changed notification received")
                if let modeString = self?.userDefaults.string(forKey: "readinessMode") {
                    print("DEBUG: New readiness mode in UserDefaults: \(modeString)")
                    if let mode = ReadinessMode(rawValue: modeString),
                       let self = self,
                       mode != self.readinessMode {
                        print("DEBUG: Updating readiness mode from \(self.readinessMode) to \(mode)")
                        
                        // Store the old mode for comparison
                        let oldMode = self.readinessMode
                        
                        // Update the mode
                        self.readinessMode = mode
                        
                        // Force a recalculation of the readiness score with the new mode
                        Task {
                            do {
                                let healthData = HealthKitManager.shared
                                
                                let restingHeartRate = try await healthData.fetchRestingHeartRate()
                                let sleepData = try await healthData.fetchSleepData()
                                
                                self.calculateAndSaveReadinessScoreForCurrentMode(
                                    restingHeartRate: restingHeartRate,
                                    sleepHours: sleepData.hours,
                                    sleepQuality: sleepData.quality,
                                    forceRecalculation: true // Force recalculation when mode changes
                                )
                                
                                print("DEBUG: Forced recalculation after mode change from \(oldMode) to \(mode)")
                            } catch {
                                print("Error recalculating after mode change: \(error)")
                            }
                        }
                    } else {
                        print("DEBUG: No change in readiness mode or invalid mode: \(modeString)")
                    }
                } else {
                    print("DEBUG: No readiness mode found in UserDefaults")
                }
            }
            .store(in: &cancellables)
        
        // Load today's readiness score if available
        loadTodaysReadinessScore()
        
        // Load past scores
        loadPastScores(days: 30)
    }
    
    func loadTodaysReadinessScore() {
        print("DEBUG: Loading today's readiness score")
        if let score = readinessService.getTodaysReadinessScore() {
            print("DEBUG: Found readiness score for today: \(score.score)")
            self.readinessScore = score.score
            self.readinessCategory = ReadinessCategory(rawValue: score.readinessCategory ?? "Moderate") ?? .moderate
            self.hrvBaseline = score.hrvBaseline
            self.hrvDeviation = score.hrvDeviation
            self.rhrAdjustment = score.rhrAdjustment
            self.sleepAdjustment = score.sleepAdjustment
            
            print("DEBUG: HRV baseline: \(score.hrvBaseline), deviation: \(score.hrvDeviation)")
            
            // Update the readiness mode if it's different
            if let modeString = score.readinessMode,
               let mode = ReadinessMode(rawValue: modeString),
               mode != self.readinessMode {
                print("DEBUG: Updating readiness mode from score: \(mode)")
                self.readinessMode = mode
            }
        } else {
            print("DEBUG: No readiness score found for today")
        }
    }
    
    func loadPastScores(days: Int) {
        self.pastScores = readinessService.getReadinessScoresForPastDays(days)
    }
    
    func calculateAndSaveReadinessScore(hrv: Double, restingHeartRate: Double, sleepHours: Double, sleepQuality: Int) {
        isLoading = true
        error = nil
        
        Task {
            do {
                // Validate input data
                let validationResult = validateInputDataWithHRV(
                    hrv: hrv,
                    restingHeartRate: restingHeartRate,
                    sleepHours: sleepHours
                )
                
                if !validationResult.isValid {
                    await MainActor.run {
                        self.error = .insufficientData(missingMetrics: validationResult.missingMetrics)
                        self.isLoading = false
                    }
                    return
                }
                
                let score = readinessService.processAndSaveTodaysData(
                    hrv: hrv,
                    restingHeartRate: restingHeartRate,
                    sleepHours: sleepHours,
                    sleepQuality: sleepQuality
                )

                if let score = score {
                    // Update UI on main thread
                    await MainActor.run {
                        self.readinessScore = score.score
                        self.readinessCategory = ReadinessCategory(rawValue: score.readinessCategory ?? "Moderate") ?? .moderate
                        self.hrvBaseline = score.hrvBaseline
                        self.hrvDeviation = score.hrvDeviation
                        self.rhrAdjustment = score.rhrAdjustment
                        self.sleepAdjustment = score.sleepAdjustment
                        self.isLoading = false
                        
                        // Reload past scores
                        self.loadPastScores(days: 30)
                    }
                } else {
                    await MainActor.run {
                        self.error = .dataProcessingFailed
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    // Helper function to validate input data with HRV in a sendable way
    private func validateInputDataWithHRV(hrv: Double, restingHeartRate: Double, sleepHours: Double) -> (isValid: Bool, missingMetrics: [String]) {
        var missingMetrics: [String] = []
        
        if hrv <= 0 { missingMetrics.append("Heart Rate Variability") }
        if restingHeartRate <= 0 { missingMetrics.append("Resting Heart Rate") }
        if sleepHours <= 0 { missingMetrics.append("Sleep Duration") }
        
        return (missingMetrics.isEmpty, missingMetrics)
    }
    
    func calculateAndSaveReadinessScoreForCurrentMode(restingHeartRate: Double, sleepHours: Double, sleepQuality: Int, forceRecalculation: Bool = false) {
        isLoading = true
        error = nil
        
        print("DEBUG: Calculating readiness score for mode: \(readinessMode)")
        print("DEBUG: Input data - RHR: \(restingHeartRate), Sleep: \(sleepHours)h, Quality: \(sleepQuality)%")
        print("DEBUG: Force recalculation: \(forceRecalculation)")
        
        // Process on a background thread
        Task {
            do {
                // Validate input data
                let validationResult = await validateInputData(restingHeartRate: restingHeartRate, sleepHours: sleepHours)
                if !validationResult.isValid {
                    await MainActor.run {
                        self.error = .insufficientData(missingMetrics: validationResult.missingMetrics)
                        self.isLoading = false
                    }
                    return
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
                        
                        // Reload past scores
                        self.loadPastScores(days: 30)
                    }
                } else {
                    await MainActor.run {
                        self.error = .dataProcessingFailed
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
    
    // Helper function to validate input data in a sendable way
    private func validateInputData(restingHeartRate: Double, sleepHours: Double) async -> (isValid: Bool, missingMetrics: [String]) {
        var missingMetrics: [String] = []
        
        if restingHeartRate <= 0 { missingMetrics.append("Resting Heart Rate") }
        if sleepHours <= 0 { missingMetrics.append("Sleep Duration") }
        
        return (missingMetrics.isEmpty, missingMetrics)
    }
    
    // Get the 7-day trend of readiness scores
    func getReadinessTrend() -> [Double] {
        let scores = readinessService.getReadinessScoresForPastDays(7)
        return scores.map { $0.score }
    }
    
    // Get the color for the current readiness category
    var categoryColor: Color {
        if readinessScore == 0 {
            return .gray
        }
        switch readinessCategory {
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
    
    // Update the readiness mode from a string value
    func updateReadinessMode(_ modeString: String) {
        print("DEBUG: Updating readiness mode from string: \(modeString)")
        
        if let mode = ReadinessMode(rawValue: modeString), mode != self.readinessMode {
            print("DEBUG: Changing readiness mode from \(self.readinessMode) to \(mode)")
            
            // Update the mode
            self.readinessMode = mode
            
            // Save to UserDefaults
            userDefaults.set(modeString, forKey: "readinessMode")
            
            // Force a recalculation of the readiness score with the new mode
            // This will happen when the ContentView calls calculateAndSaveReadinessScoreForCurrentMode
        } else {
            print("DEBUG: Readiness mode unchanged or invalid mode string: \(modeString)")
        }
    }
} 
