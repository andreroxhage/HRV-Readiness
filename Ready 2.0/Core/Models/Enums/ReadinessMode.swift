import Foundation
import SwiftUI

// ReadinessMode
// Defines the mode for readiness calculations (Morning HRV measurement)
// Provides helper properties for display and time ranges
enum ReadinessMode: String {
    case morning = "morning"
    
    // User-friendly description
    var description: String {
        let endHour = UserDefaultsManager.shared.morningEndHour
        return "Morning Readiness (00:00-\(String(format: "%02d", endHour)):00)"
    }
    
    // Icon for display
    var icon: String {
        return "sunrise"
    }
    
    // Color for icon
    var iconColor: Color {
        return .orange
    }
    
    // Get time range for today based on morning mode
    func getTimeRange() -> (start: Date, end: Date) {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let endHour = UserDefaultsManager.shared.morningEndHour
        let end = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: today) ?? today

        print("🕐 READINESS_MODE: Morning mode - today start: \(today), end: \(end) (endHour=\(endHour))")
        print("🕐 READINESS_MODE: Current time: \(now), hour: \(calendar.component(.hour, from: now))")

        // If it's before endHour, use current time as end to get latest data; otherwise use full window
        if calendar.component(.hour, from: now) < endHour {
            print("🕐 READINESS_MODE: Before \(endHour), using current time as end")
            return (today, now)
        } else {
            print("🕐 READINESS_MODE: After \(endHour), using full morning window")
            return (today, end)
        }
    }
    
    // Get time range for a specific date (morning mode)
    func getTimeRangeForDate(_ date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endHour = UserDefaultsManager.shared.morningEndHour
        let end = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: startOfDay) ?? startOfDay
        return (startOfDay, end)
    }
} 
