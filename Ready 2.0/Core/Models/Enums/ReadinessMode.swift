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
            return "Morning Readiness (00:00-11:00)"
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
            // Extended morning window to 11:00 AM to be more inclusive
            let end = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: today) ?? today
            
            print("🕐 READINESS_MODE: Morning mode - today start: \(today), end: \(end)")
            print("🕐 READINESS_MODE: Current time: \(now), hour: \(calendar.component(.hour, from: now))")
            
            // If it's after 11 AM, use today's full morning window
            // If it's before 11 AM, use current time as end to get most recent data
            if calendar.component(.hour, from: now) < 11 {
                // Before 11 AM - end time is current time to get latest data
                print("🕐 READINESS_MODE: Before 11 AM, using current time as end")
                return (today, now)
            } else {
                // After 11 AM - use standard extended morning window
                print("🕐 READINESS_MODE: After 11 AM, using full morning window")
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
            // Extended to 11:00 AM for more inclusive morning window
            let end = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: startOfDay) ?? startOfDay
            return (startOfDay, end)
            
        case .rolling:
            // For historical dates, use full day for rolling mode
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return (startOfDay, endOfDay)
        }
    }
} 
