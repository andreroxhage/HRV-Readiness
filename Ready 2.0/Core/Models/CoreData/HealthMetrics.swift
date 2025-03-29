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
        return hrv > 10
    }
    
    // Check if has all required metrics for readiness calculation
    var hasRequiredMetrics: Bool {
        return hasValidHRV && restingHeartRate > 30 && sleepHours > 0
    }
    
    // Get the missing metrics description
    var missingMetricsDescription: [String] {
        var missing: [String] = []
        
        if !hasValidHRV {
            missing.append("HRV")
        }
        
        if restingHeartRate <= 30 {
            missing.append("Resting Heart Rate")
        }
        
        if sleepHours <= 0 {
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
        
        if restingHeartRate > 30 {
            available.append("Resting Heart Rate")
        }
        
        if sleepHours > 0 {
            available.append("Sleep Data")
        }
        
        return available
    }
} 
