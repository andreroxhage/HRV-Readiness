import Foundation

enum ReadinessError: LocalizedError {
    case healthKitAuthorizationRequired
    case insufficientData(missingMetrics: [String])
    case invalidTimeRange
    case hrvBaselineNotAvailable
    case dataProcessingFailed
    case networkError(Error)
    case databaseError(Error)
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .healthKitAuthorizationRequired:
            return "HealthKit authorization is required. Please enable access to health data in Settings."
            
        case .insufficientData(let missingMetrics):
            if missingMetrics.isEmpty {
                return "Insufficient data to calculate readiness score."
            } else {
                return "Missing required data: \(missingMetrics.joined(separator: ", "))"
            }
            
        case .invalidTimeRange:
            return "Invalid time range for data collection. Please try again later."
            
        case .hrvBaselineNotAvailable:
            return "HRV baseline not available. Need at least 3 days of data to establish baseline."
            
        case .dataProcessingFailed:
            return "Failed to process readiness data. Please try again."
            
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
            
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
            
        case .unknownError(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .healthKitAuthorizationRequired:
            return "Go to Settings > Privacy > Health > Ready 2.0 and enable all categories."
            
        case .insufficientData:
            return "Make sure your Apple Watch is worn consistently and check that sleep tracking is enabled."
            
        case .invalidTimeRange:
            return "Try selecting a different time range or wait for more data to be collected."
            
        case .hrvBaselineNotAvailable:
            return "Continue wearing your Apple Watch during sleep for at least 3 days to establish a baseline."
            
        case .dataProcessingFailed:
            return "Check your internet connection and try again. If the problem persists, restart the app."
            
        case .networkError:
            return "Check your internet connection and try again."
            
        case .databaseError:
            return "Try force quitting and reopening the app. If the problem persists, you may need to reinstall."
            
        case .unknownError:
            return "Try force quitting and reopening the app. If the problem persists, please contact support."
        }
    }
} 