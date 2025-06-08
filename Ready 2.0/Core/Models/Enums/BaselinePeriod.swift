import Foundation

// BaselinePeriod
// Defines the different time periods for calculating baselines
// Provides helper properties for display and interpretation

enum BaselinePeriod: Int, CaseIterable {
    case sevenDays = 7
    case fourteenDays = 14
    case thirtyDays = 30
    
    var description: String {
        switch self {
        case .sevenDays: return "7 days"
        case .fourteenDays: return "14 days"
        case .thirtyDays: return "30 days"
        }
    }    
    
    var explanation: String {
        switch self {
        case .sevenDays:
            return "Uses the last 7 days of data to establish your baseline. Recommended default per research-backed algorithm. Responds quickly to recent changes."
        case .fourteenDays:
            return "Uses the last 14 days of data to establish your baseline. Provides more stability but slower response to changes."
        case .thirtyDays:
            return "Uses the last 30 days of data to establish your baseline. Most stable but takes longer to adapt to changes in your fitness."
        }
    }
    
    // Get the date range for this period from today
    func dateRange(from endDate: Date = Date()) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -self.rawValue, to: calendar.startOfDay(for: endDate))!
        return (startDate, endDate)
    }
    
    var minimumDaysRequired: Int {
        switch self {
        case .sevenDays:
            return 3
        case .fourteenDays:
            return 5
        case .thirtyDays:
            return 7
        }
    }
    
    // Get all period options
    static var allOptions: [Int] {
        return BaselinePeriod.allCases.map { $0.rawValue }
    }
    
    // Create from any integer, defaulting to 7 days if not valid
    static func from(_ days: Int) -> BaselinePeriod {
        return BaselinePeriod(rawValue: days) ?? .sevenDays
    }
} 
