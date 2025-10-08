import Foundation
import CoreData

// HealthMetrics extension
// Provides additional functionality for the CoreData HealthMetrics entity

extension HealthMetrics {
    // Convenience method to get formatted date string
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date ?? Date())
    }
    
    // Get date component for grouping
    var dayComponent: Date? {
        guard let date = date else { return nil }
        return Calendar.current.startOfDay(for: date)
    }
    
    // Calculate sleep quality as percentage
    var sleepQualityPercentage: Double {
        let quality = Double(sleepQuality)
        return min(max(quality / 100.0, 0), 1) * 100
    }
    
    // Check if HRV data is valid
    var hasValidHRV: Bool {
        return hrv >= 10 && hrv <= 200
    }
    
    // Check if RHR data is valid
    var hasValidRHR: Bool {
        return restingHeartRate >= 30 && restingHeartRate <= 120
    }
    
    // Check if sleep data is valid
    var hasValidSleep: Bool {
        return sleepHours > 0 && sleepHours <= 12
    }
    
    // Check if has all required metrics for readiness calculation
    var hasRequiredMetrics: Bool {
        return hasValidHRV && hasValidRHR && hasValidSleep
    }
    
    // Check if has minimum required metrics for readiness calculation (just HRV)
    var hasMinimumMetrics: Bool {
        return hasValidHRV
    }
    
    // Check if has required metrics based on user settings
    func hasRequiredMetrics(useRHR: Bool, useSleep: Bool) -> Bool {
        var required = hasValidHRV
        
        if useRHR {
            required = required && hasValidRHR
        }
        
        if useSleep {
            required = required && hasValidSleep
        }
        
        return required
    }
    
    // Get the missing metrics description
    var missingMetricsDescription: [String] {
        var missing: [String] = []
        
        if !hasValidHRV {
            missing.append("HRV")
        }
        
        if !hasValidRHR {
            missing.append("Resting Heart Rate")
        }
        
        if !hasValidSleep {
            missing.append("Sleep Data")
        }
        
        return missing
    }
    
    // Get available metrics
    var availableMetricsDescription: [String] {
        var available: [String] = []
        
        if hasValidHRV {
            available.append("HRV")
        }
        
        if hasValidRHR {
            available.append("Resting Heart Rate")
        }
        
        if hasValidSleep {
            available.append("Sleep Data")
        }
        
        return available
    }
} 
