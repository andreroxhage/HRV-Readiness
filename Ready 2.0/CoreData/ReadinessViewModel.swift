import Foundation
import SwiftUI
import Combine

class ReadinessViewModel: ObservableObject {
    @Published var readinessScore: Double = 0
    @Published var readinessCategory: ReadinessCategory = .moderate
    @Published var hrvBaseline: Double = 0
    @Published var hrvDeviation: Double = 0
    @Published var rhrAdjustment: Double = 0
    @Published var sleepAdjustment: Double = 0
    @Published var isLoading: Bool = false
    @Published var error: Error?
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
        
        // Process on a background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if let score = self.readinessService.processAndSaveTodaysData(
                hrv: hrv,
                restingHeartRate: restingHeartRate,
                sleepHours: sleepHours,
                sleepQuality: sleepQuality
            ) {
                // Update UI on main thread
                DispatchQueue.main.async {
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
                DispatchQueue.main.async {
                    self.error = NSError(domain: "ReadinessViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to calculate readiness score"])
                    self.isLoading = false
                }
            }
        }
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
                        print("DEBUG: Failed to calculate readiness score")
                        self.error = NSError(domain: "ReadinessViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to calculate readiness score"])
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    print("DEBUG: Error calculating readiness score: \(error)")
                    self.error = error
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
    
    // Get the color for the current readiness category
    var categoryColor: Color {
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
