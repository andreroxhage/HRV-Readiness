import Foundation
import SwiftUI

// ReadinessCategory
// Defines the different categories for readiness scores
// Provides helper properties for display and interpretation


enum ReadinessCategory: String, CaseIterable {
    case unknown = "Unknown"
    case optimal = "Optimal"
    case moderate = "Moderate"
    case low = "Low"
    case fatigue = "Fatigue"
    
    var range: ClosedRange<Double> {
        switch self {
        case .unknown: return 0...0
        case .optimal: return 80...100
        case .moderate: return 50...79
        case .low: return 30...49
        case .fatigue: return 0...29
        }
    }
    
    var emoji: String {
        switch self {
        case .unknown: return "❓"
        case .optimal: return "✅"
        case .moderate: return "🟡"
        case .low: return "🔴"
        case .fatigue: return "💀"
        }
    }
    
    var description: String {
        switch self {
        case .unknown: return "Not enough data to determine readiness"
        case .optimal: return "Your body is well-recovered and ready for high-intensity training."
        case .moderate: return "Your body is moderately recovered. Consider moderate-intensity training."
        case .low: return "Your body shows signs of fatigue. Consider light activity or active recovery."
        case .fatigue: return "Your body needs rest. Focus on recovery and avoid intense training."
        }
    }
    
    // Color representation for UI elements
    var color: Color {
        switch self {
        case .unknown: return .gray
        case .optimal: return .green
        case .moderate: return .yellow
        case .low: return .orange
        case .fatigue: return .red
        }
    }
    
    // Get category for a given score
    static func forScore(_ score: Double) -> ReadinessCategory {
        if score <= 0 {
            return .unknown
        }
        
        for category in Self.allCases where category != .unknown {
            if category.range.contains(score) {
                return category
            }
        }
        
        return .unknown
    }
} 