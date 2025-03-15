//
//  Widget_2_0.swift
//  Widget 2.0
//
//  Created by André Roxhage on 2025-03-13.
//

import WidgetKit
import SwiftUI
import HealthKit

// Create a simple wrapper for the HealthKitManager
// This is a temporary solution until we fix the module structure
class HealthDataProvider {
    static let shared = HealthDataProvider()
    
    private init() {}
    
    // Mock shared defaults
    var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.andreroxhage.Ready-2-0")
    }
}

struct Provider: TimelineProvider {
    static let appGroupIdentifyer = "group.andreroxhage.Ready-2-0"
    let sharedDefaults = UserDefaults(suiteName: appGroupIdentifyer)

    func placeholder(in context: Context) -> HealthEntry {
        HealthEntry(
            date: Date(),
            hrv: 0,
            restingHeartRate: 0,
            sleepHours: 0,
            sleepQuality: 0,
            readinessScore: 0,
            readinessCategory: "Moderate",
            readinessMode: "morning"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (HealthEntry) -> ()) {
        let entry = getHealthEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentEntry = getHealthEntry()
        
        // Schedule updates every minute
        var entries: [HealthEntry] = [currentEntry]
        let currentDate = Date()
        
        for minute in stride(from: 1, through: 5, by: 1) {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minute, to: currentDate)!
            let entry = HealthEntry(
                date: entryDate,
                hrv: currentEntry.hrv,
                restingHeartRate: currentEntry.restingHeartRate,
                sleepHours: currentEntry.sleepHours,
                sleepQuality: currentEntry.sleepQuality,
                readinessScore: currentEntry.readinessScore,
                readinessCategory: currentEntry.readinessCategory,
                readinessMode: currentEntry.readinessMode
            )
            entries.append(entry)
        }
        
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    private func getHealthEntry() -> HealthEntry {
        let defaults = sharedDefaults
        let readinessScore = defaults?.double(forKey: "readinessScore") ?? 0
        let readinessCategory = defaults?.string(forKey: "readinessCategory") ?? "Moderate"
        let readinessMode = defaults?.string(forKey: "readinessMode") ?? "morning"
        
        print("Widget reading - HRV: \(defaults?.double(forKey: "lastHRV") ?? 0)")
        print("Widget reading - Resting Heart Rate: \(defaults?.double(forKey: "lastRestingHeartRate") ?? 0)")
        print("Widget reading - Sleep Hours: \(defaults?.double(forKey: "lastSleepHours") ?? 0)")
        print("Widget reading - Sleep Quality: \(defaults?.integer(forKey: "sleepQuality") ?? 0)")
        print("Widget reading - Readiness Score: \(readinessScore)")
        print("Widget reading - Readiness Category: \(readinessCategory)")
        print("Widget reading - Readiness Mode: \(readinessMode)")
        print("--------------------------------")

        return HealthEntry(
            date: defaults?.object(forKey: "lastUpdateTime") as? Date ?? Date(),
            hrv: defaults?.double(forKey: "lastHRV") ?? 0,
            restingHeartRate: defaults?.double(forKey: "lastRestingHeartRate") ?? 0,
            sleepHours: defaults?.double(forKey: "lastSleepHours") ?? 0,
            sleepQuality: defaults?.integer(forKey: "sleepQuality") ?? 0,
            readinessScore: readinessScore,
            readinessCategory: readinessCategory,
            readinessMode: readinessMode
        )
    }
}

struct HealthEntry: TimelineEntry {
    let date: Date
    let hrv: Double
    let restingHeartRate: Double
    let sleepHours: Double
    let sleepQuality: Int
    let readinessScore: Double
    let readinessCategory: String
    let readinessMode: String
}

struct Widget_2_0EntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry
    
    var body: some View {
        switch family {
        case .systemSmall:
            ReadinessWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
        case .accessoryRectangular:
            RectangularWidgetView(entry: entry)
        case .accessoryInline:
            InlineWidgetView(entry: entry)
        default:
            ReadinessWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.text.square.fill")
                .font(.title)
                .foregroundStyle(.pink)
            Text("\(Int(entry.hrv))")
                .font(.system(.title, design: .rounded))
                .bold()
            Text("ms HRV")
                .font(.caption)
            Text("Sleep: \(formatSleepDuration(hours: entry.sleepHours))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    private func formatSleepDuration(hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)h \(minutes)m"
    }
}

struct MediumWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        HStack {
            VStack(spacing: 8) {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundStyle(.pink)
                Text("\(Int(entry.hrv))")
                    .font(.system(.body, design: .rounded))
                    .bold()
                Text("HRV ms")
                    .font(.caption)
            }
            
            Divider()
            
            VStack(spacing: 8) {
                Image(systemName: "heart.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                Text("\(Int(entry.restingHeartRate))")
                    .font(.system(.body, design: .rounded))
                    .bold()
                Text("Resting")
                    .font(.caption)
            }
            
            Divider()
            
            VStack(spacing: 8) {
                Image(systemName: "bed.double.fill")
                    .font(.title2)
                    .foregroundStyle(.indigo)
                Text(formatSleepDuration(hours: entry.sleepHours))
                    .font(.system(.body, design: .rounded))
                    .bold()
                Text("Sleep")
                    .font(.caption)
            }
        }
        .padding()
    }
    
    private func formatSleepDuration(hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)h \(minutes)m"
    }
}

struct LargeWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Health Insights")
                .font(.headline)
            
            VStack(spacing: 15) {
                HStack {
                    Image(systemName: "heart.text.square.fill")
                        .font(.title)
                        .foregroundStyle(.pink)
                    VStack(alignment: .leading) {
                        Text("\(Int(entry.hrv)) ms")
                            .font(.system(.title2, design: .rounded))
                            .bold()
                        Text("Heart Rate Variability")
                            .font(.caption)
                    }
                }
                
                HStack {
                    Image(systemName: "heart.circle.fill")
                        .font(.title)
                        .foregroundStyle(.red)
                    VStack(alignment: .leading) {
                        Text("\(Int(entry.restingHeartRate)) BPM")
                            .font(.system(.title2, design: .rounded))
                            .bold()
                        Text("Resting Heart Rate")
                            .font(.caption)
                    }
                }
                
                HStack {
                    Image(systemName: "bed.double.fill")
                        .font(.title)
                        .foregroundStyle(.indigo)
                    VStack(alignment: .leading) {
                        Text(formatSleepDuration(hours: entry.sleepHours))
                            .font(.system(.title2, design: .rounded))
                            .bold()
                        Text("Sleep Duration")
                            .font(.caption)
                    }
                }
                
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.title)
                        .foregroundStyle(.purple)
                    VStack(alignment: .leading) {
                        Text("\(entry.sleepQuality)%")
                            .font(.system(.title2, design: .rounded))
                            .bold()
                        Text("Sleep Quality")
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
    }
    
    private func formatSleepDuration(hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)h \(minutes)m"
    }
}

struct CircularWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        Gauge(value: entry.readinessScore, in: 0...100) {
            Image(systemName: "gauge.medium")
        } currentValueLabel: {
            Text("\(Int(entry.readinessScore))")
        }
        .gaugeStyle(.accessoryCircular)
        .tint(getCategoryColor(entry.readinessCategory))
    }
    
    private func getCategoryColor(_ category: String) -> Color {
        switch category {
        case "Optimal":
            return .green
        case "Moderate":
            return .yellow
        case "Low":
            return .orange
        case "Fatigue":
            return .red
        default:
            return .gray
        }
    }
}

struct RectangularWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        HStack {
            Image(systemName: "gauge.medium")
                .foregroundStyle(getCategoryColor(entry.readinessCategory))
            Text("Readiness: \(Int(entry.readinessScore))")
            Spacer()
            Image(systemName: "heart.text.square.fill")
                .foregroundStyle(.pink)
            Text("\(Int(entry.hrv)) ms")
        }
    }
    
    private func getCategoryColor(_ category: String) -> Color {
        switch category {
        case "Optimal":
            return .green
        case "Moderate":
            return .yellow
        case "Low":
            return .orange
        case "Fatigue":
            return .red
        default:
            return .gray
        }
    }
}

struct InlineWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        Text("Readiness: \(Int(entry.readinessScore)) | HRV: \(Int(entry.hrv)) ms")
    }
}

// Add a new widget view for readiness
struct ReadinessWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Readiness")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("\(Int(entry.readinessScore))")
                .font(.system(.title, design: .rounded))
                .bold()
            
            Text(entry.readinessCategory)
                .font(.caption)
                .foregroundStyle(getCategoryColor(entry.readinessCategory))
            
            HStack(spacing: 4) {
                Image(systemName: entry.readinessMode == "morning" ? "sunrise" : "clock.arrow.circlepath")
                    .font(.caption2)
                    .foregroundStyle(entry.readinessMode == "morning" ? .orange : .blue)
                
                Text("\(Int(entry.hrv)) ms")
                    .font(.caption2)
            }
        }
    }
    
    private func getCategoryColor(_ category: String) -> Color {
        switch category {
        case "Optimal":
            return .green
        case "Moderate":
            return .yellow
        case "Low":
            return .orange
        case "Fatigue":
            return .red
        default:
            return .gray
        }
    }
}

struct Widget_2_0: Widget {
    let kind: String = "Widget_2_0"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                Widget_2_0EntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                Widget_2_0EntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Health Insights")
        .description("View your HRV and sleep data for better health tracking.")
        .supportedFamilies(getSupportedFamilies())
    }
    
    // Helper method to get supported widget families based on platform
    private func getSupportedFamilies() -> [WidgetFamily] {
        var families: [WidgetFamily] = [
            .systemSmall,
            .systemMedium,
            .systemLarge
        ]
        
        // Add accessory widget families only on iOS
        #if os(iOS)
        if #available(iOS 16.0, *) {
            families.append(.accessoryCircular)
            families.append(.accessoryRectangular)
            families.append(.accessoryInline)
        }
        #endif
        
        return families
    }
}
