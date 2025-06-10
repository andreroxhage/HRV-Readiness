import SwiftUI
import Foundation
import CoreData

struct CalendarView: View {
    @ObservedObject var viewModel: ReadinessViewModel
    @Environment(\.appearanceViewModel) private var appearanceViewModel
    let monthsToShow = 6
    
    // Calendar components - Using standard calendar with Monday-first display logic
    private let calendar = Calendar.current
    private let daysInWeek = 7
    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 4
    
    // Seven-day view constants
    private let sevenDayCellSize: CGFloat = 40
    private let sevenDayCellSpacing: CGFloat = 8
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Seven-day view
            VStack(alignment: .leading) {
                
                HStack(spacing: sevenDayCellSpacing) {
                    ForEach(0..<daysInWeek, id: \.self) { dayIndex in
                        let date = self.getDateForWeekday(weekday: dayIndex)
                        sevenDayCell(for: date)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Monthly calendar view
            VStack(alignment: .leading) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(0..<monthsToShow, id: \.self) { monthIndex in
                            let month = self.getMonth(monthsAgo: monthIndex)
                            monthView(for: month)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                }
                .frame(height: 160)
            }
        }
    }
    
    // Get the date for a specific weekday in the current week (Monday-first)
    private func getDateForWeekday(weekday: Int) -> Date {
        let today = Date()
        // Convert from Monday-first index (0-6) to Calendar weekday (2-8 for Mon-Sun)
        let calendarWeekday = weekday + 2 // Monday = 2, so add 2
        let correctedWeekday = calendarWeekday > 7 ? calendarWeekday - 7 : calendarWeekday
        
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = correctedWeekday
        
        return calendar.date(from: components) ?? today
    }
    
    // Create a cell for the seven-day view
    private func sevenDayCell(for date: Date) -> some View {
        let score = getScore(for: date)
        let isToday = calendar.isDateInToday(date)
        let hasData = score != nil
        let scoreValue = score?.score ?? 0
        let dayNumber = calendar.component(.day, from: date)
        let dayName = dayOfWeekLetter(for: date)
        
        return VStack(spacing: 2) {
            Text(dayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            ZStack {
                // Main cell background
                RoundedRectangle(cornerRadius: 8)
                    .fill(hasData ? viewModel.getColor(for: scoreValue, isDarkMode: appearanceViewModel.colorScheme == .dark) : Color.gray.opacity(0.2))
                    .frame(width: sevenDayCellSize, height: sevenDayCellSize)
                
                // Score value in the middle (only if we have data)
                if hasData {
                    Text("\(Int(scoreValue))")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(viewModel.getTextColor(for: scoreValue))
                }
                
                // Today indicator
                if isToday {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary, lineWidth: 1.5)
                        .frame(width: sevenDayCellSize, height: sevenDayCellSize)
                }
            }
            
            Text("\(dayNumber)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    // Get the month data for the given number of months ago
    private func getMonth(monthsAgo: Int) -> Date {
        let today = Date()
        return calendar.date(byAdding: .month, value: -monthsAgo, to: today) ?? today
    }
    
    // Create a view for a single month
    private func monthView(for month: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthFormatter.string(from: month))
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Get the correct number of days in the month
            let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
            
            // Get the first day of the month
            let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
            
            // Get what day of the week the 1st falls on (1=Sunday, 2=Monday, etc.)
            let firstWeekday = calendar.component(.weekday, from: firstDay)
            
            // Calculate offset for Monday-first display
            // Sunday=1 should display in position 6 (last column)
            // Monday=2 should display in position 0 (first column)
            // Tuesday=3 should display in position 1, etc.
            let weekOffset = (firstWeekday == 1) ? 6 : (firstWeekday - 2)
            
            VStack(spacing: cellSpacing) {
                // Days of the week header
                HStack(spacing: cellSpacing) {
                    ForEach(0..<daysInWeek, id: \.self) { dayIndex in
                        Text(dayOfWeekLetter(for: dayIndex))
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .frame(width: cellSize, height: cellSize)
                    }
                }
                
                // Calendar grid
                let totalCells = weekOffset + daysInMonth
                let rows = (totalCells + daysInWeek - 1) / daysInWeek
                
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: cellSpacing) {
                        ForEach(0..<daysInWeek, id: \.self) { column in
                            let index = row * daysInWeek + column
                            let day = index - weekOffset + 1
                            
                            if day > 0 && day <= daysInMonth {
                                let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay)!
                                dayCell(for: date)
                            } else {
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: (cellSize + cellSpacing) * CGFloat(daysInWeek))
    }
    
    // Create a cell for a single day in the month view
    private func dayCell(for date: Date) -> some View {
        let score = getScore(for: date)
        let isToday = calendar.isDateInToday(date)
        let scoreValue = score?.score ?? 0
        
        return ZStack {
            // Main cell background with gradient color based on score
            if score != nil {
                RoundedRectangle(cornerRadius: 2)
                    .fill(viewModel.getGradient(for: scoreValue, isDarkMode: appearanceViewModel.colorScheme == .dark))
                    .frame(width: cellSize, height: cellSize)
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: cellSize, height: cellSize)
            }
            
            // Today indicator
            if isToday {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.primary, lineWidth: 0.5)
                    .frame(width: cellSize, height: cellSize)
            }
        }
    }
    
    // Get the score for a specific date from the viewModel
    private func getScore(for date: Date) -> ReadinessScore? {
        // Return nil for future dates
        if date > Date() {
            return nil
        }
        
        return viewModel.pastScores.first { score in
            guard let scoreDate = score.date else { return false }
            return calendar.isDate(scoreDate, inSameDayAs: date)
        }
    }
    
    // Format the day of the week as a single letter (Monday-first)
    private func dayOfWeekLetter(for dayIndex: Int) -> String {
        let days = ["M", "T", "W", "T", "F", "S", "S"] // Monday-first: Mon, Tue, Wed, Thu, Fri, Sat, Sun
        return days[dayIndex]
    }
    
    // Get the day of week letter from a date
    private func dayOfWeekLetter(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }
    
    // Date formatter for month names
    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }
}

struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView(viewModel: ReadinessViewModel())
            .padding()
    }
}
