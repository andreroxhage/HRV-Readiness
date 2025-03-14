//
//  Widget_2_0.swift
//  Widget 2.0
//
//  Created by André Roxhage on 2025-03-13.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    static let appGroupIdentifyer = "group.andreroxhage.Ready-2-0"
    let sharedDefaults = UserDefaults(suiteName: appGroupIdentifyer)

    func placeholder(in context: Context) -> HealthEntry {
        HealthEntry(date: Date(), steps: 0, activeEnergy: 0, heartRate: 0)
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
                steps: currentEntry.steps,
                activeEnergy: currentEntry.activeEnergy,
                heartRate: currentEntry.heartRate
            )
            entries.append(entry)
        }
        
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    private func getHealthEntry() -> HealthEntry {
        let defaults = sharedDefaults
        let steps = defaults?.double(forKey: "lastSteps") ?? 0
        print("Widget reading - Steps: \(steps)")

        return HealthEntry(
            date: defaults?.object(forKey: "lastUpdateTime") as? Date ?? Date(),
            steps: steps,
            activeEnergy: defaults?.double(forKey: "lastActiveEnergy") ?? 0,
            heartRate: defaults?.double(forKey: "lastHeartRate") ?? 0
        )
    }
}

struct HealthEntry: TimelineEntry {
    let date: Date
    let steps: Double
    let activeEnergy: Double
    let heartRate: Double
}

struct Widget_2_0EntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
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
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.walk")
                .font(.title)
            Text("\(Int(entry.steps))")
                .font(.system(.title2, design: .rounded))
                .bold()
            Text("Steps")
                .font(.caption)
        }
    }
}

struct MediumWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        HStack {
            VStack(spacing: 8) {
                Image(systemName: "figure.walk")
                    .font(.title2)
                Text("\(Int(entry.steps))")
                    .font(.system(.body, design: .rounded))
                    .bold()
                Text("Steps")
                    .font(.caption)
            }
            
            Divider()
            
            VStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                Text("\(Int(entry.activeEnergy))")
                    .font(.system(.body, design: .rounded))
                    .bold()
                Text("Cal")
                    .font(.caption)
            }
            
            Divider()
            
            VStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.title2)
                Text("\(Int(entry.heartRate))")
                    .font(.system(.body, design: .rounded))
                    .bold()
                Text("BPM")
                    .font(.caption)
            }
        }
        .padding()
    }
}

struct LargeWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Health Summary")
                .font(.headline)
            
            VStack(spacing: 20) {
                HStack {
                    Image(systemName: "figure.walk")
                        .font(.title)
                    VStack(alignment: .leading) {
                        Text("\(Int(entry.steps))")
                            .font(.system(.title2, design: .rounded))
                            .bold()
                        Text("Steps today")
                            .font(.caption)
                    }
                }
                
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.title)
                    VStack(alignment: .leading) {
                        Text("\(Int(entry.activeEnergy))")
                            .font(.system(.title2, design: .rounded))
                            .bold()
                        Text("Active calories")
                            .font(.caption)
                    }
                }
                
                HStack {
                    Image(systemName: "heart.fill")
                        .font(.title)
                    VStack(alignment: .leading) {
                        Text("\(Int(entry.heartRate))")
                            .font(.system(.title2, design: .rounded))
                            .bold()
                        Text("Avg heart rate")
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
    }
}

struct CircularWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        Gauge(value: entry.steps, in: 0...10000) {
            Image(systemName: "figure.walk")
        } currentValueLabel: {
            Text("\(Int(entry.steps))")
        }
        .gaugeStyle(.accessoryCircular)
    }
}

struct RectangularWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        HStack {
            Image(systemName: "figure.walk")
            Text("\(Int(entry.steps)) steps")
            Spacer()
            Image(systemName: "heart.fill")
            Text("\(Int(entry.heartRate)) bpm")
        }
    }
}

struct InlineWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        Text("\(Int(entry.steps)) steps")
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
        .configurationDisplayName("Health Stats")
        .description("View your daily health statistics.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge
        ])
    }
}

#if DEBUG
struct Widget_2_0_Previews: PreviewProvider {
    static var previews: some View {
        Widget_2_0EntryView(entry: HealthEntry(date: .now, steps: 5432, activeEnergy: 320, heartRate: 72))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
#endif
