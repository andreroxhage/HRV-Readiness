import Foundation

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
            return "Failed to process \(component) data: \(reason). Please try again."
        
        case .historicalDataMissing(let date, let missingMetrics):
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let dateString = dateFormatter.string(from: date)
            
            let metricsList = missingMetrics.joined(separator: ", ")
            return "Missing health data for \(dateString): \(metricsList)."
            
        case .historicalDataIncomplete(let date, let missingMetrics, let partialResult):
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let dateString = dateFormatter.string(from: date)
            
            let metricsList = missingMetrics.joined(separator: ", ")
            if partialResult {
                return "Partial data for \(dateString). Missing: \(metricsList). A score was still calculated based on available data."
            } else {
                return "Incomplete data for \(dateString): \(metricsList). Unable to calculate readiness score."
            }
            
        case .manualRecalculationRequired(let date, let reason):
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let dateString = dateFormatter.string(from: date)
            
            return "Manual recalculation needed for \(dateString): \(reason)"
            
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
        case .notAvailable:
            return "Please ensure your Apple Watch is worn consistently and that you have collected enough data."

        case .healthKitAuthorizationRequired:
            return "Go to Settings > Privacy > Health > Ready 2.0 and enable all categories."
            
        case .insufficientData(let missingMetrics, _):
            var suggestions = "Make sure your Apple Watch is worn consistently"
            
            if missingMetrics.contains("Heart Rate Variability") {
                suggestions += " and wear it during sleep to capture HRV data."
            }
            
            if missingMetrics.contains("Resting Heart Rate") {
                suggestions += " throughout the day to record accurate RHR."
            }
            
            if missingMetrics.contains("Sleep Duration") {
                suggestions += " and ensure sleep tracking is enabled in the Health app."
            }
            
            return suggestions
            
        case .invalidTimeRange(let range):
            if range.contains("morning") {
                return "Morning readiness mode requires data between 00:00-10:00. Try again later or switch to Rolling mode."
            } else {
                return "Try selecting a different time range or wait for more data to be collected."
            }
            
        case .hrvBaselineNotAvailable(let daysAvailable, let daysNeeded):
            let daysRemaining = daysNeeded - daysAvailable
            return "Continue wearing your Apple Watch during sleep for \(daysRemaining) more day\(daysRemaining == 1 ? "" : "s") to establish a baseline. You currently have \(daysAvailable) day\(daysAvailable == 1 ? "" : "s") of data."
            
        case .dataProcessingFailed(let component, _):
            if component == "HRV" {
                return "Check that your Apple Watch is worn properly during sleep. Try syncing your health data and restart the app."
            } else if component == "sleep" {
                return "Ensure sleep tracking is properly configured in the Health app and that your Apple Watch has sufficient battery life overnight."
            } else {
                return "Check your internet connection and try again. If the problem persists, restart the app."
            }
            
        case .historicalDataMissing(_, let missingMetrics):
            var suggestion = "To fix this:"
            
            if missingMetrics.contains("HRV") {
                suggestion += "\n• Make sure HRV data is available in the Health app"
            }
            
            if missingMetrics.contains("Resting Heart Rate") {
                suggestion += "\n• Check that resting heart rate is recorded for this date"
            }
            
            if missingMetrics.contains("Sleep") {
                suggestion += "\n• Verify sleep data is present in the Health app"
            }
            
            suggestion += "\n\nAfter adding data in the Health app, go to Advanced Settings and use 'Recalculate Specific Date' to update this score."
            
            return suggestion
            
        case .historicalDataIncomplete(_, let missingMetrics, let partialResult):
            if partialResult {
                // Check what metrics are missing
                let containsRHR = missingMetrics.contains("Resting Heart Rate")
                let containsSleep = missingMetrics.contains("Sleep")
                
                var suggestion = "A score was calculated with available data. "
                
                if containsRHR || containsSleep {
                    suggestion += "Note that "
                    
                    if containsRHR && containsSleep {
                        suggestion += "both resting heart rate and sleep data are optional metrics that can be disabled in settings if you don't use them."
                    } else if containsRHR {
                        suggestion += "resting heart rate is an optional metric that can be disabled in settings if you don't use it."
                    } else if containsSleep {
                        suggestion += "sleep data is an optional metric that can be disabled in settings if you don't use it."
                    }
                    
                    suggestion += " If you've added the missing health data in the Health app, go to Advanced Settings and use 'Recalculate Specific Date' to update this score."
                } else {
                    suggestion += "If you've added missing health data in the Health app, go to Advanced Settings and use 'Recalculate Specific Date' to update this score."
                }
                
                return suggestion
            } else {
                return "Go to the Health app and check for missing data on this date. After adding the necessary data, return to Advanced Settings and use 'Recalculate Specific Date' to generate a score."
            }
            
        case .manualRecalculationRequired(_, _):
            return "Go to Advanced Settings > Data Recalculation > Recalculate Specific Date to update this score with the latest health data."
            
        case .networkError:
            return "Check your internet connection and try again. If you're on cellular data, try connecting to WiFi."
            
        case .databaseError:
            return "Try force quitting and reopening the app. If the problem persists, you may need to reinstall the app. Your data is stored in HealthKit and will be reimported."
            
        case .unknownError:
            return "Try force quitting and reopening the app. If the problem persists, please contact support with a screenshot of this error."
        }
    }
} 
