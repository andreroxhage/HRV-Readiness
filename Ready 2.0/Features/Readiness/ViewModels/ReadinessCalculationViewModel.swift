import Foundation
import CoreData

// Import models and enums
import HealthKit

// Import readiness-specific models - these need to be accessible
// ReadinessService, ReadinessScore, ReadinessError should be in the same module
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
        print("🧮 CALC_VM: calculateReadiness called with RHR=\(restingHeartRate), Sleep=\(sleepHours)h")
        
        // Check if the input data is valid
        let validation = validateInputData(restingHeartRate: restingHeartRate, sleepHours: sleepHours)
        print("🔍 CALC_VM: Validation result - Valid: \(validation.isValid), Missing: \(validation.missingMetrics), Available: \(validation.availableMetrics)")
        
        if !validation.isValid {
            print("❌ CALC_VM: Validation failed, throwing insufficientData error")
            throw ReadinessError.insufficientData(missingMetrics: validation.missingMetrics, availableMetrics: validation.availableMetrics)
        }

        // if a baseline is not available, make a call to the readiness service to calculate it 

        // also make sure this parts as well as other things  actually work with minimum hrv. @services too
        
        // Process today's data through the service
        return try await readinessService.processAndSaveTodaysDataForCurrentMode(
            restingHeartRate: restingHeartRate,
            sleepHours: sleepHours,
            sleepQuality: sleepQuality,
            forceRecalculation: forceRecalculation
        )
    }
    
    func recalculateHistoricalReadiness(days: Int = 30, progressCallback: ((Double, String) -> Void)? = nil) async throws -> [ReadinessScore] {
        var results: [ReadinessScore] = []
        var errors: [Error] = []
        
        // Get the end date (today)
        let today = Date()
        let calendar = Calendar.current
        
        // Iterate through each day
        for dayOffset in 0..<days {
            if Task.isCancelled { break }
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            let currentIndex = dayOffset + 1
            let progress = Double(currentIndex) / Double(max(days, 1))
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none
            let dateString = dateFormatter.string(from: date)
            progressCallback?(progress * 0.99, "Calculating \(dateString) (\(currentIndex)/\(days))…")
            
            do {
                if let score = try await readinessService.recalculateReadinessForDate(date) {
                    results.append(score)
                }
            } catch {
                errors.append(error)
                progressCallback?(progress * 0.99, "Skipped \(dateString) due to error: \(error.localizedDescription)")
                // Continue with next day even if there was an error
            }
        }
        
        // If all days failed, throw the last error
        if results.isEmpty && !errors.isEmpty {
            throw errors.last!
        }
        
        // Return all successfully calculated scores
        progressCallback?(1.0, "Historical recalculation complete")
        return results
    }
    
    func recalculateReadinessForDate(_ date: Date) async throws -> ReadinessScore? {
        return try await readinessService.recalculateReadinessForDate(date)
    }
    
    // MARK: - Validation Methods
    
    func validateInputData(restingHeartRate: Double, sleepHours: Double) -> (isValid: Bool, missingMetrics: [String], availableMetrics: [String]) {
        var missingMetrics: [String] = []
        var availableMetrics: [String] = []
        
        print("🔍 CALC_VM: Validating input data - checking service settings...")
        
        // Only validate RHR if RHR adjustment is enabled
        if readinessService.useRHRAdjustment {
            print("🔍 CALC_VM: RHR adjustment is ENABLED, checking RHR value: \(restingHeartRate)")
            if restingHeartRate <= 0 {
                print("⚠️ CALC_VM: RHR value is 0 or negative (\(restingHeartRate))")
                print("🔄 CALC_VM: This means RHR fetching failed - will continue calculation without RHR adjustment")
                // Don't fail validation - just note that RHR data isn't available for adjustment
                availableMetrics.append("RHR (no data - will skip adjustment)")
            } else if restingHeartRate < 30 || restingHeartRate > 200 {
                print("❌ CALC_VM: RHR validation failed - out of range: \(restingHeartRate) (valid: 30-200)")
                missingMetrics.append("Resting Heart Rate")
            } else {
                print("✅ CALC_VM: RHR validation passed - value: \(restingHeartRate) bpm")
                availableMetrics.append("Resting Heart Rate")
            }
        } else {
            print("⚙️ CALC_VM: RHR adjustment disabled, skipping RHR validation")
        }
        
        // Only validate sleep if sleep adjustment is enabled
        if readinessService.useSleepAdjustment {
            print("🔍 CALC_VM: Sleep adjustment is ENABLED, checking sleep value: \(sleepHours)")
            if sleepHours <= 0 {
                print("⚠️ CALC_VM: Sleep value is 0 or negative (\(sleepHours))")
                print("🔄 CALC_VM: This means sleep fetching failed - will continue calculation without sleep adjustment")
                // Don't fail validation - just note that sleep data isn't available for adjustment
                availableMetrics.append("Sleep (no data - will skip adjustment)")
            } else if sleepHours > 24 {
                print("❌ CALC_VM: Sleep validation failed - out of range: \(sleepHours) hours (valid: 0-24)")
                missingMetrics.append("Sleep Data")
            } else {
                print("✅ CALC_VM: Sleep validation passed - value: \(sleepHours) hours")
                availableMetrics.append("Sleep Data")
            }
        } else {
            print("⚙️ CALC_VM: Sleep adjustment disabled, skipping sleep validation")
        }
        
        // Check HRV baseline availability (nice to have, but not required for calculation)
        let hrvBaseline = readinessService.calculateHRVBaseline()
        if hrvBaseline <= 0 {
            print("⚠️ CALC_VM: HRV baseline not available - will use fallback calculation method")
            // Don't add to missingMetrics since calculation can work without baseline
        } else {
            availableMetrics.append("HRV Baseline")
            print("✅ CALC_VM: HRV baseline available - baseline: \(hrvBaseline)")
        }
        
        // Data is valid if there are no missing metrics
        let isValid = missingMetrics.isEmpty
        
        print("🎯 CALC_VM: Final validation result - Valid: \(isValid)")
        if !isValid {
            print("⚠️ CALC_VM: Missing required metrics: \(missingMetrics)")
        }
        
        return (isValid, missingMetrics, availableMetrics)
    }
} 
