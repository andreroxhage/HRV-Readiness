import Foundation
import CoreData

// ReadinessScore extension
// Provides additional functionality for the CoreData ReadinessScore entity

extension ReadinessScore: @unchecked Sendable {
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
    
    // Get formatted score as a string
    var formattedScore: String {
        let scoreValue = score
        if scoreValue <= 0 {
            return "N/A"
        }
        return String(format: "%.0f", scoreValue)
    }
    
    // Get the ReadinessCategory enum from the stored string
    var category: ReadinessCategory {
        guard let categoryString = readinessCategory else {
            return .unknown
        }
        return ReadinessCategory(rawValue: categoryString) ?? .unknown
    }
    
    // Get the ReadinessMode enum from the stored string
    var mode: ReadinessMode? {
        guard let modeString = readinessMode else {
            return nil
        }
        return ReadinessMode(rawValue: modeString)
    }
    
    // Get the BaselinePeriod enum from the stored integer
    var period: BaselinePeriod? {
        return BaselinePeriod(rawValue: Int(baselinePeriod))
    }
    
    // Check if the score is a valid readiness measurement
    var isValid: Bool {
        return score > 0 && category != .unknown
    }
    
    // Check if score was calculated today
    var isToday: Bool {
        guard let scoreDate = date else { return false }
        return Calendar.current.isDateInToday(scoreDate)
    }
    
    // Check if calculation is fresh (within the last 6 hours)
    var isFresh: Bool {
        guard let timestamp = calculationTimestamp else { return false }
        let hoursAgo = Calendar.current.dateComponents([.hour], from: timestamp, to: Date()).hour ?? 0
        return hoursAgo < 6
    }
    
    // Get formatted time since calculation
    var timeSinceCalculation: String {
        guard let timestamp = calculationTimestamp else { return "Unknown" }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
} 
