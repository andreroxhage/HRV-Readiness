import Foundation

// ReadinessError
// Defines the different error types for readiness calculations
// Provides detailed error descriptions and context
// Used for error handling throughout the app

enum ReadinessError: LocalizedError {
    case healthKitAuthorizationRequired
    case insufficientData(missingMetrics: [String], availableMetrics: [String])
    case invalidTimeRange(requestedRange: String)
    case hrvBaselineNotAvailable(daysAvailable: Int, daysNeeded: Int)
    case dataProcessingFailed(component: String, reason: String)
    case historicalDataMissing(date: Date, missingMetrics: [String])
    case historicalDataIncomplete(date: Date, missingMetrics: [String], partialResult: Bool)
    case manualRecalculationRequired(date: Date, reason: String)
    case networkError(Error)
    case databaseError(Error)
    case unknownError(Error)
    case notAvailable
    case partialPermissions(missing: [String])
    
    // Localized error description for display
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Readiness data is not available"
     
        case .healthKitAuthorizationRequired:
            return "HealthKit authorization is required. Please enable access to health data in Settings."
            
        case .insufficientData(let missingMetrics, let availableMetrics):
            if missingMetrics.isEmpty {
                return "Insufficient data to calculate readiness score."
            } else {
                let missingText = missingMetrics.joined(separator: ", ")
                let availableText = availableMetrics.isEmpty ? "No metrics available." : "Available metrics: \(availableMetrics.joined(separator: ", "))"
                return "Missing required data: \(missingText). \(availableText)"
            }
            
        case .invalidTimeRange(let range):
            return "Invalid time range for data collection: \(range). Please try again later."
            
        case .hrvBaselineNotAvailable(let daysAvailable, let daysNeeded):
            return "HRV baseline not available. Currently have \(daysAvailable) days of data, but need at least \(daysNeeded) days to establish baseline."
            
        case .dataProcessingFailed(let component, let reason):
            return "Failed to process \(component): \(reason)"
            
        case .historicalDataMissing(let date, let missingMetrics):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            let dateStr = formatter.string(from: date)
            
            let metricsStr = missingMetrics.joined(separator: ", ")
            return "Missing health data for \(dateStr): \(metricsStr)"
            
        case .historicalDataIncomplete(let date, let missingMetrics, _):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            let dateStr = formatter.string(from: date)
            
            let metricsStr = missingMetrics.joined(separator: ", ")
            return "Incomplete health data for \(dateStr). Missing: \(metricsStr)"
            
        case .manualRecalculationRequired(let date, let reason):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            let dateStr = formatter.string(from: date)
            
            return "Manual recalculation required for \(dateStr): \(reason)"
            
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
            
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
            
        case .unknownError(let error):
            return "Unknown error: \(error.localizedDescription)"
        case .partialPermissions(let missing):
            if missing.isEmpty { return "Some health permissions are missing." }
            return "Missing permissions: \(missing.joined(separator: ", "))"
        }
    }
    
    // Additional help text with recovery suggestions
    var recoverySuggestion: String? {
        switch self {
        case .healthKitAuthorizationRequired:
            return "Go to Settings > Privacy & Security > Health > Ready and enable all health data access."
            
        case .insufficientData:
            return "Try again tomorrow when more health data may be available, or check that your Apple Watch or other devices are properly synchronized."
            
        case .hrvBaselineNotAvailable(let daysAvailable, let daysNeeded):
            let remaining = daysNeeded - daysAvailable
            return "Continue wearing your Apple Watch consistently to collect the remaining \(remaining) days of data needed."
            
        case .historicalDataMissing:
            return "This data may not be available from your Apple Watch or other health devices for this date."
        case .partialPermissions:
            return "You can enable additional permissions in Settings > Privacy & Security > Health > Ready. The app works with HRV only; RHR and Sleep are optional."
            
        default:
            return nil
        }
    }
    
    // Whether this error should be shown to the user
    var shouldDisplay: Bool {
        switch self {
        case .historicalDataIncomplete(_, _, let partialResult):
            // Don't show errors for partial results that are still usable
            return !partialResult
        default:
            return true
        }
    }
    
    // Whether this error is critical (blocks functionality)
    var isCritical: Bool {
        switch self {
        case .healthKitAuthorizationRequired, .hrvBaselineNotAvailable:
            return true
        case .insufficientData, .invalidTimeRange, .dataProcessingFailed:
            return true
        default:
            return false
        }
    }
} 
