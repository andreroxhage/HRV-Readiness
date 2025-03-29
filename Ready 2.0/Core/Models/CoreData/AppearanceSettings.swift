import Foundation
import CoreData

// AppearanceSettings entity extension
// Provides additional functionality for the Core Data AppearanceSettings entity

extension AppearanceSettings {
    // Get formatted date of last update
    var formattedLastUpdated: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastUpdated ?? Date())
    }
    
    // Check if settings were updated recently
    var updatedRecently: Bool {
        guard let updated = lastUpdated else { return false }
        let calendar = Calendar.current
        let hoursSinceUpdate = calendar.dateComponents([.hour], from: updated, to: Date()).hour ?? 0
        return hoursSinceUpdate < 24
    }
    
    // Ensure appAppearance always returns a valid string
    var safeAppAppearance: String {
        return appAppearance ?? "light"
    }
} 