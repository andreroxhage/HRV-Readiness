import Foundation
import CoreData

// Import models and enums
import HealthKit

// Import readiness-specific models
// ReadinessCalculationViewModel
// Responsible for:
// - Complex calculation logic for readiness scores
// - Processing historical data
// - Not responsible for UI state (not ObservableObject)
// - Pure business logic separated from presentation

class ReadinessCalculationViewModel {
    // MARK: - Dependencies
    
    private let readinessService: ReadinessService
    
    // MARK: - Initialization
    
    init(readinessService: ReadinessService = ReadinessService.shared) {
        self.readinessService = readinessService
    }
    
    // MARK: - Calculation Methods
    
    // Main calculation methods
    func calculateReadiness(restingHeartRate: Double, sleepHours: Double, sleepQuality: Int, forceRecalculation: Bool = false) async throws -> ReadinessScore? {
        // Check if the input data is valid
        let validation = validateInputData(restingHeartRate: restingHeartRate, sleepHours: sleepHours)
        if !validation.isValid {
            throw ReadinessError.insufficientData(missingMetrics: validation.missingMetrics, availableMetrics: validation.availableMetrics)
        }
        
        // Process today's data through the service
        return try await readinessService.processAndSaveTodaysDataForCurrentMode(
            restingHeartRate: restingHeartRate,
            sleepHours: sleepHours,
            sleepQuality: sleepQuality,
            forceRecalculation: forceRecalculation
        )
    }
    
    func recalculateHistoricalReadiness(days: Int = 30) async throws -> [ReadinessScore] {
        var results: [ReadinessScore] = []
        var errors: [Error] = []
        
        // Get the end date (today)
        let today = Date()
        let calendar = Calendar.current
        
        // Iterate through each day
        for dayOffset in 0..<days {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            
            do {
                if let score = try await readinessService.recalculateReadinessForDate(date) {
                    results.append(score)
                }
            } catch {
                errors.append(error)
                // Continue with next day even if there was an error
            }
        }
        
        // If all days failed, throw the last error
        if results.isEmpty && !errors.isEmpty {
            throw errors.last!
        }
        
        // Return all successfully calculated scores
        return results
    }
    
    func recalculateReadinessForDate(_ date: Date) async throws -> ReadinessScore? {
        return try await readinessService.recalculateReadinessForDate(date)
    }
    
    // MARK: - Validation Methods
    
    func validateInputData(restingHeartRate: Double, sleepHours: Double) -> (isValid: Bool, missingMetrics: [String], availableMetrics: [String]) {
        var missingMetrics: [String] = []
        var availableMetrics: [String] = []
        
        // Validate resting heart rate
        if restingHeartRate <= 30 || restingHeartRate > 200 {
            missingMetrics.append("Resting Heart Rate")
        } else {
            availableMetrics.append("Resting Heart Rate")
        }
        
        // Validate sleep hours
        if sleepHours <= 0 || sleepHours > 24 {
            missingMetrics.append("Sleep Data")
        } else {
            availableMetrics.append("Sleep Data")
        }
        
        // Check HRV baseline availability
        let hrvBaseline = readinessService.calculateHRVBaseline()
        if hrvBaseline <= 0 {
            missingMetrics.append("HRV Baseline")
        } else {
            availableMetrics.append("HRV Baseline")
        }
        
        // Data is valid if there are no missing metrics
        let isValid = missingMetrics.isEmpty
        
        return (isValid, missingMetrics, availableMetrics)
    }
} 
