import Foundation
import SwiftUI

// ReadinessMode
// Defines the different modes for readiness calculations
// Provides helper properties for display and time ranges
enum ReadinessMode: String {
    case morning = "morning"
    case rolling = "rolling"
    
    // User-friendly description
    var description: String {
        switch self {
        case .morning:
            return "Morning Readiness (00:00-10:00)"
        case .rolling:
            return "Rolling Readiness (Last 6 hours)"
        }
    }
    
    // Icon for display
    var icon: String {
        switch self {
        case .morning:
            return "sunrise"
        case .rolling:
            return "clock.arrow.circlepath"
        }
    }
    
    // Color for icon
    var iconColor: Color {
        switch self {
        case .morning:
            return .orange
        case .rolling:
            return .blue
        }
    }
    
    // Get time range for today based on mode
    func getTimeRange() -> (start: Date, end: Date) {
        let now = Date()
        let calendar = Calendar.current
        
        switch self {
        case .morning:
            let today = calendar.startOfDay(for: now)
            let end = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: today) ?? today
            
            // If it's after 10 AM, use today's window
            // If it's before 10 AM, check if we have enough data yet
            if calendar.component(.hour, from: now) < 10 {
                // Before 10 AM - end time is current time
                return (today, now)
            } else {
                // After 10 AM - use standard morning window
                return (today, end)
            }
            
        case .rolling:
            // Last 6 hours window
            let start = calendar.date(byAdding: .hour, value: -6, to: now) ?? now
            return (start, now)
        }
    }
    
    // Get time range for a specific date
    func getTimeRangeForDate(_ date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        switch self {
        case .morning:
            let end = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: startOfDay) ?? startOfDay
            return (startOfDay, end)
            
        case .rolling:
            // For historical dates, use full day for rolling mode
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return (startOfDay, endOfDay)
        }
    }
} 