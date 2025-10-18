//
//  Widget_2_0.swift
//  Widget 2.0
//
//  Created by André Roxhage on 2025-03-13.
//

import WidgetKit
import SwiftUI
import HealthKit

// Shared category-aware color helper used by all widget views
private func colorFor(score: Double, category: String?) -> Color {
    if let category = category {
        switch category {
        case "Optimal": return .green
        case "Moderate": return .yellow
        case "Low": return .orange
        case "Fatigue": return .red
        default: break // Unknown or unexpected → fall back to score thresholds
        }
    }
    // Fallback to score thresholds
    switch score {
    case 80...100: return .green
    case 50...79: return .yellow
    case 30...49: return .orange
    case 1...29: return .red
    default: return .gray // 0 or negative → Unknown/No data
    }
}

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
            readinessCategory: "Unknown",
            readinessMode: "morning",
            readinessEmoji: "",
            readinessDescription: "No data available",
            recentDates: [],
            recentScores: [],
            recentCategories: []
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (HealthEntry) -> ()) {
        let entry = getHealthEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentEntry = getHealthEntry()
        // Provide a single entry and rely on WidgetCenter.reloadAllTimelines() after app calculations
        let timeline = Timeline(entries: [currentEntry], policy: .atEnd)
        completion(timeline)
    }
    
    private func getHealthEntry() -> HealthEntry {
        let d = sharedDefaults
        // Primary keys (main app + background task writers)
        let score = d?.double(forKey: "currentReadinessScore") ?? 0
        let category = d?.string(forKey: "currentReadinessCategory") ?? "Unknown"
        let emoji = d?.string(forKey: "currentReadinessEmoji") ?? "❓"
        let description = d?.string(forKey: "currentReadinessDescription") ?? "No data available"
        // Timestamp key may vary; try both
        let ts = (d?.object(forKey: "lastUpdateTimestamp") as? Date) ?? (d?.object(forKey: "currentReadinessTimestamp") as? Date) ?? Date()
        // Availability flag – if false, treat as no current score
        let hasCurrent = d?.bool(forKey: "hasCurrentReadiness") ?? false
        // Optional legacy/extra metrics for secondary displays
        let hrv = d?.double(forKey: "lastHRV") ?? 0
        let rhr = d?.double(forKey: "lastRestingHeartRate") ?? 0
        let sleepH = d?.double(forKey: "lastSleepHours") ?? 0
        let sleepQ = d?.integer(forKey: "sleepQuality") ?? 0
        let mode = d?.string(forKey: "readinessMode") ?? "morning"

        // Recent history for larger widgets (optional)
        let recentDates = (d?.array(forKey: "recentReadinessDates") as? [Date]) ?? []
        let recentScores = (d?.array(forKey: "recentReadinessScores") as? [Double]) ?? []
        let recentCats = (d?.array(forKey: "recentReadinessCategories") as? [String]) ?? []

        return HealthEntry(
            date: ts,
            hrv: hrv,
            restingHeartRate: rhr,
            sleepHours: sleepH,
            sleepQuality: sleepQ,
            readinessScore: hasCurrent ? score : 0,
            readinessCategory: category,
            readinessMode: mode,
            readinessEmoji: emoji,
            readinessDescription: description,
            recentDates: recentDates,
            recentScores: recentScores,
            recentCategories: recentCats,
            hasCurrentScore: hasCurrent
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
    let readinessEmoji: String
    let readinessDescription: String
    let recentDates: [Date]
    let recentScores: [Double]
    let recentCategories: [String]
    
    // UI States
    var isLoading: Bool = false
    var hasError: Bool = false
    var isHighlighted: Bool = false
    var hasCurrentScore: Bool = false
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



struct MediumWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left half: current score ring + last calc (perfectly centered)
            HStack {
                Spacer()
                VStack(alignment: .center, spacing: 16) {
                    ZStack {
                        // Enhanced circle with gradient and shadow
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        colorFor(score: entry.readinessScore, category: entry.readinessCategory).opacity(0.3),
                                        colorFor(score: entry.readinessScore, category: entry.readinessCategory).opacity(0.1)
                                    ]),
                                    center: .center,
                                    startRadius: 40,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 100, height: 100)
                            .shadow(color: colorFor(score: entry.readinessScore, category: entry.readinessCategory).opacity(0.3), radius: 8, x: 0, y: 2)
                            .background(.regularMaterial, in: Circle())

                        // Score content with loading/error states
                        if entry.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(colorFor(score: entry.readinessScore, category: entry.readinessCategory))
                        } else if entry.hasCurrentScore {
                            VStack(spacing: 2) {
                                Text("\(Int((entry.readinessScore).rounded()))")
                                    .font(.system(.title, design: .rounded))
                                    .bold()
                                    .foregroundStyle(colorFor(score: entry.readinessScore, category: entry.readinessCategory).opacity(0.9))
                                    .contentTransition(.numericText())
                                    .animation(.easeInOut(duration: 0.3), value: entry.readinessScore)
                                Text(entry.readinessCategory)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            VStack(spacing: 2) {
                                Text("--")
                                    .font(.system(.title, design: .rounded))
                                    .bold()
                                    .foregroundStyle(.secondary)
                        }

                        // Error indicator overlay
                        if entry.hasError {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                                .offset(x: 25, y: -25)
                        }
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity) // Takes up half the width

            // Right half: title + MTWTFSS bars (perfectly centered)
            HStack {
                Spacer()
                VStack(alignment: .leading, spacing: 16) {
                    Text("Readiness")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(weekdayPoints(entry: entry), id: \.dayIndex) { p in
                            let barColor = colorFor(score: p.score ?? -1, category: p.category)
                            VStack(spacing: 8) {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                barColor,
                                                barColor.opacity(0.7)
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 4, height: barHeight(for: p.score))
                                    .opacity(p.score == nil ? 0.15 : 0.95)
                                    .scaleEffect(entry.isHighlighted ? 1.05 : 1.0)
                                    .animation(.spring(response: 0.3), value: entry.isHighlighted)
                                Text(p.label)
                                    .font(.caption2)
                                    .foregroundStyle(barColor.opacity(0.9))
                            }
                        }
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity) // Takes up half the width
        }
        .padding(12)
        .dynamicTypeSize(.small ... .large) // Prevent extreme scaling in widgets
        }
    }


    private func formatSleepDuration(hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)h \(minutes)m"
    }

    // Colors now resolved via colorFor(score:category:)

    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }


    private func absoluteTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE d, HH:mm"
        return f.string(from: date)
    }

    private func ringBackground() -> some View {
        Circle()
            .stroke(Color.gray.opacity(0.2), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            .padding(6)
    }

    private func ringProgress(score: Double) -> some View {
        let progress = max(0, min(1, score / 100))
        let c = colorFor(score: score, category: entry.readinessCategory)
        let grad = AngularGradient(colors: [c.opacity(0.9), c.opacity(0.6), c.opacity(0.9)], center: .center)
        return Circle()
            .trim(from: 0, to: progress)
            .stroke(grad, style: StrokeStyle(lineWidth: 10, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .padding(6)
    }

    private func barHeight(for score: Double?) -> CGFloat {
        guard let s = score else { return 6 }
        return CGFloat(max(8, min(40, (s / 100.0) * 40)))
    }

    private struct DayPoint: Hashable {
        let dayIndex: Int
        let label: String
        let score: Double?
        let category: String?
    }
    
    private func weekdayPoints(entry: Provider.Entry) -> [DayPoint] {
        // MTWTFSS
        let labels = ["M","T","W","T","F","S","S"]
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else { return [] }
        // Map stored dates → (score, category)
        var scoreMap: [Date: Double] = [:]
        var categoryMap: [Date: String] = [:]
        for (i, d) in entry.recentDates.enumerated() {
            let key = cal.startOfDay(for: d)
            if i < entry.recentScores.count { scoreMap[key] = entry.recentScores[i] }
            if i < entry.recentCategories.count { categoryMap[key] = entry.recentCategories[i] }
        }
        
        if entry.hasCurrentScore && entry.readinessScore > 0 {
            let currentDayStart = cal.startOfDay(for: entry.date)
            if cal.dateInterval(of: .weekOfYear, for: currentDayStart)?.contains(today) == true {
                scoreMap[currentDayStart] = entry.readinessScore
                categoryMap[currentDayStart] = entry.readinessCategory
            }
        }
        
        return (0..<7).map { idx in
            let day = cal.startOfDay(for: cal.date(byAdding: .day, value: idx, to: weekStart)!)
            return DayPoint(
                dayIndex: idx,
                label: labels[idx],
                score: scoreMap[day],
                category: categoryMap[day]
            )
        }
    }

}

// Small Widget - Left side of medium (score ring only)
struct ReadinessWidgetView: View {
      var entry: Provider.Entry

      var body: some View {
          VStack(alignment: .center, spacing: 12) {
            Text("Readiness")
                .font(.caption)
                .foregroundStyle(.secondary)

              ZStack {
                  // Enhanced circle with gradient and shadow
                  Circle()
                      .fill(
                          RadialGradient(
                              gradient: Gradient(colors: [
                                  colorFor(score: entry.readinessScore, category: entry.readinessCategory).opacity(0.3),
                                  colorFor(score: entry.readinessScore, category: entry.readinessCategory).opacity(0.1)
                              ]),
                              center: .center,
                              startRadius: 35,
                              endRadius: 50
                          )
                      )
                      .frame(width: 80, height: 80)
                      .shadow(color: colorFor(score: entry.readinessScore, category: entry.readinessCategory).opacity(0.3), radius: 6, x: 0, y: 2)
                      .background(.regularMaterial, in: Circle())

                  // Score content with loading/error states
                  if entry.isLoading {
                      ProgressView()
                          .scaleEffect(0.7)
                          .tint(colorFor(score: entry.readinessScore, category: entry.readinessCategory))
                  } else if entry.hasCurrentScore {
                      VStack(spacing: 1) {
                          Text("\(Int((entry.readinessScore).rounded()))")
                              .font(.system(.title2, design: .rounded))
                              .bold()
                              .foregroundStyle(colorFor(score: entry.readinessScore, category: entry.readinessCategory).opacity(0.9))
                              .contentTransition(.numericText())
                              .animation(.easeInOut(duration: 0.3), value: entry.readinessScore)
                          Text(entry.readinessCategory)
                              .font(.caption2)
                              .foregroundStyle(.secondary)
                      }
                  } else {
                      VStack(spacing: 1) {
                          Text("--")
                              .font(.system(.title2, design: .rounded))
                              .bold()
                              .foregroundStyle(.secondary)
     
                      }
                  }

                  // Error indicator overlay
                  if entry.hasError {
                      Image(systemName: "exclamationmark.triangle.fill")
                          .foregroundStyle(.orange)
                          .font(.caption2)
                          .offset(x: 20, y: -20)
                  }
              }


          }
          .padding(8)
          .dynamicTypeSize(.small ... .large)
      }

      // Colors now resolved via colorFor(score:category:)
  }

  // Large Widget - Extended version with metrics and chart
  struct LargeWidgetView: View {
      var entry: Provider.Entry

      var body: some View {
          VStack(alignment: .leading, spacing: 16) {

              // Description and timestamp
              VStack(alignment: .leading, spacing: 8) {
                  Text("Readiness")
                      .font(.headline)
                      .foregroundStyle(.primary)

                  Text(entry.readinessDescription)
                      .font(.subheadline)
                      .foregroundStyle(.secondary)
                      .multilineTextAlignment(.leading)

                  Text(relativeTime(from: entry.date))
                      .font(.caption)
                      .foregroundStyle(.tertiary)
              }

              // Top section - Current score and description
              HStack(alignment: .center, spacing: 24) {
                  // Score ring (larger)
                  ZStack {
                      let ringColor = colorFor(score: entry.readinessScore, category: entry.readinessCategory)
                      let ringGradient = RadialGradient(
                          gradient: Gradient(colors: [
                              ringColor.opacity(0.3),
                              ringColor.opacity(0.1)
                          ]),
                          center: .center,
                          startRadius: 50,
                          endRadius: 70
                      )

                      Circle()
                          .fill(ringGradient)
                          .frame(width: 120, height: 120)
                          .shadow(color: ringColor.opacity(0.3), radius: 10, x: 0, y: 3)
                          .background(.regularMaterial, in: Circle())

                      if entry.isLoading {
                          ProgressView()
                              .scaleEffect(1.0)
                              .tint(ringColor)
                      } else if entry.hasCurrentScore {
                          VStack(spacing: 3) {
                              Text("\(Int((entry.readinessScore).rounded()))")
                                  .font(.system(.largeTitle, design: .rounded))
                                  .bold()
                                  .foregroundStyle(ringColor.opacity(0.9))
                                  .contentTransition(.numericText())
                                  .animation(.easeInOut(duration: 0.3), value: entry.readinessScore)
                              Text(entry.readinessCategory)
                                  .font(.caption)
                                  .foregroundStyle(.secondary)
                          }
                      } else {
                          VStack(spacing: 3) {
                              Text("--")
                                  .font(.system(.largeTitle, design: .rounded))
                                  .bold()
                                  .foregroundStyle(.secondary)

                          }
                      }

                      if entry.hasError {
                          Image(systemName: "exclamationmark.triangle.fill")
                              .foregroundStyle(.orange)
                              .font(.caption)
                              .offset(x: 35, y: -35)
                      }
                  }
                  // Weekly chart
                  VStack(alignment: .leading, spacing: 8) {
                      HStack(alignment: .bottom, spacing: 12) {
                          ForEach(weekdayPoints(entry: entry), id: \.self.dayIndex) { point in
                              let barColor = colorFor(score: point.score ?? -1, category: point.category)
                              VStack(spacing: 6) {
                                  Capsule()
                                      .fill(
                                          LinearGradient(
                                              gradient: Gradient(colors: [
                                                  barColor,
                                                  barColor.opacity(0.7)
                                              ]),
                                              startPoint: .top,
                                              endPoint: .bottom
                                          )
                                      )
                                      .frame(width: 6, height: barHeight(for: point.score, maxHeight: 60))
                                      .opacity(point.score == nil ? 0.15 : 0.95)
                                      .scaleEffect(entry.isHighlighted ? 1.05 : 1.0)
                                      .animation(.spring(response: 0.3), value: entry.isHighlighted)

                                  Text(point.label)
                                      .font(.caption2)
                                      .foregroundStyle(barColor.opacity(0.9))
                              }
                          }
                      }
                  }
              }

              // Health metrics row
              HStack(spacing: 16) {
                  MetricView(title: "HRV", value: "\(Int(entry.hrv))", unit: "ms", color: .blue)
                  MetricView(title: "RHR", value: "\(Int(entry.restingHeartRate))", unit: "bpm", color: .red)
                  MetricView(title: "Sleep", value: formatSleepDuration(hours: entry.sleepHours), unit: "", color: .purple)
              }
          }
          .padding(16)
          .dynamicTypeSize(.small ... .large)
      }

      // Colors now resolved via colorFor(score:category:)

      private func relativeTime(from date: Date) -> String {
          let formatter = RelativeDateTimeFormatter()
          formatter.unitsStyle = .short
          return formatter.localizedString(for: date, relativeTo: Date())
      }

      private func formatSleepDuration(hours: Double) -> String {
          let totalMinutes = Int(hours * 60)
          let hours = totalMinutes / 60
          let minutes = totalMinutes % 60
          return "\(hours)h \(minutes)m"
      }

      private func barHeight(for score: Double?, maxHeight: CGFloat) -> CGFloat {
          guard let s = score else { return 8 }
          return CGFloat(max(12, min(maxHeight, (s / 100.0) * maxHeight)))
      }

      private struct DayPoint: Hashable {
          let dayIndex: Int
          let label: String
          let score: Double?
           let category: String?
      }

      private func weekdayPoints(entry: Provider.Entry) -> [DayPoint] {
           let labels = ["M","T","W","T","F","S","S"]
           let calendar = Calendar.current
           let today = calendar.startOfDay(for: Date())
           guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else { return [] }
           var scoreByDay: [Date: Double] = [:]
           var categoryByDay: [Date: String] = [:]
           for (index, date) in entry.recentDates.enumerated() {
               let key = calendar.startOfDay(for: date)
               if index < entry.recentScores.count { scoreByDay[key] = entry.recentScores[index] }
               if index < entry.recentCategories.count { categoryByDay[key] = entry.recentCategories[index] }
           }
           
           if entry.hasCurrentScore && entry.readinessScore > 0 {
               let currentDayStart = calendar.startOfDay(for: entry.date)
               if calendar.dateInterval(of: .weekOfYear, for: currentDayStart)?.contains(today) == true {
                   scoreByDay[currentDayStart] = entry.readinessScore
                   categoryByDay[currentDayStart] = entry.readinessCategory
               }
           }
           
           return (0..<7).map { index in
               let day = calendar.startOfDay(for: calendar.date(byAdding: .day, value: index, to: weekStart)!)
               return DayPoint(
                   dayIndex: index,
                   label: labels[index],
                   score: scoreByDay[day],
                   category: categoryByDay[day]
               )
           }
      }
  }

  // Metric view helper for large widget
  struct MetricView: View {
      let title: String
      let value: String
      let unit: String
      let color: Color

      var body: some View {
          VStack(spacing: 4) {
              Text(title)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              HStack(alignment: .bottom, spacing: 2) {
                  Text(value)
                      .font(.system(.callout, design: .rounded))
                      .bold()
                      .foregroundStyle(color)
                  if !unit.isEmpty {
                      Text(unit)
                          .font(.caption2)
                          .foregroundStyle(.tertiary)
                  }
              }
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
      }
  }

  // Circular Accessory Widget
  struct CircularWidgetView: View {
      var entry: Provider.Entry

      var body: some View {
          ZStack {
              // Progress ring
              Circle()
                  .stroke(Color.gray.opacity(0.3), lineWidth: 4)

              Circle()
                  .trim(from: 0, to: max(0, min(1, entry.readinessScore / 100)))
                  .stroke(colorFor(score: entry.readinessScore, category: entry.readinessCategory), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                  .rotationEffect(.degrees(-90))
                  .animation(.easeInOut(duration: 0.3), value: entry.readinessScore)

              // Score text
              if entry.isLoading {
                  ProgressView()
                      .scaleEffect(0.6)
                      .tint(colorFor(score: entry.readinessScore, category: entry.readinessCategory))
              } else if entry.hasCurrentScore {
                  Text("\(Int((entry.readinessScore).rounded()))")
                      .font(.system(.caption, design: .rounded))
                      .bold()
                      .foregroundStyle(colorFor(score: entry.readinessScore, category: entry.readinessCategory))
                      .contentTransition(.numericText())
                      .animation(.easeInOut(duration: 0.3), value: entry.readinessScore)
              } else {
                  Text("--")
                      .font(.system(.caption, design: .rounded))
                      .bold()
                      .foregroundStyle(.secondary)
              }
          }
          .widgetAccentable()
      }

      // Colors now resolved via colorFor(score:category:)
  }

  // Rectangular Accessory Widget
  struct RectangularWidgetView: View {
      var entry: Provider.Entry

      var body: some View {
          HStack(alignment: .center, spacing: 8) {
              // Mini progress ring
              ZStack {
                  Circle()
                      .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                      .frame(width: 16, height: 16)

                  Circle()
                      .trim(from: 0, to: max(0, min(1, entry.readinessScore / 100)))
                      .stroke(colorFor(score: entry.readinessScore, category: entry.readinessCategory), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                      .rotationEffect(.degrees(-90))
                      .frame(width: 16, height: 16)
                      .animation(.easeInOut(duration: 0.3), value: entry.readinessScore)
              }

              VStack(alignment: .leading, spacing: 1) {
                  if entry.isLoading {
                      HStack {
                          ProgressView()
                              .scaleEffect(0.5)
                          Text("Loading...")
                              .font(.caption2)
                              .foregroundStyle(.secondary)
                      }
                  } else if entry.hasCurrentScore {
                      HStack(alignment: .bottom, spacing: 2) {
                          Text("\(Int((entry.readinessScore).rounded()))")
                              .font(.system(.callout, design: .rounded))
                              .bold()
                              .foregroundStyle(colorFor(score: entry.readinessScore, category: entry.readinessCategory))
                              .contentTransition(.numericText())
                              .animation(.easeInOut(duration: 0.3), value: entry.readinessScore)
                          Text("Readiness")
                              .font(.caption2)
                              .foregroundStyle(.secondary)
                      }
                      Text(entry.readinessCategory)
                          .font(.caption2)
                          .foregroundStyle(.tertiary)
                  } else {
                      HStack(alignment: .bottom, spacing: 2) {
                          Text("--")
                              .font(.system(.callout, design: .rounded))
                              .bold()
                              .foregroundStyle(.secondary)
                          Text("Readiness")
                              .font(.caption2)
                              .foregroundStyle(.secondary)
                      }
                  }
              }

              Spacer()
          }
          .widgetAccentable()
      }

      // Colors now resolved via colorFor(score:category:)
  }

  // Inline Accessory Widget
  struct InlineWidgetView: View {
      var entry: Provider.Entry

      var body: some View {
          if entry.isLoading {
              Text("Loading readiness...")
          } else if entry.hasCurrentScore {
              Text("Readiness: \(Int((entry.readinessScore).rounded())) (\(entry.readinessCategory))")
                  .contentTransition(.numericText())
                  .animation(.easeInOut(duration: 0.3), value: entry.readinessScore)
          } else {
              Text("Readiness: No data")
          }
      }
  }

  // Widget Configuration
  struct Widget_2_0: Widget {
      let kind: String = "Widget_2_0"

      var body: some WidgetConfiguration {
          StaticConfiguration(kind: kind, provider: Provider()) { entry in
              Widget_2_0EntryView(entry: entry)
                  .containerBackground(.fill.tertiary, for: .widget)
          }
          .configurationDisplayName("Readiness")
          .description("Track your daily readiness score and health metrics.")
          .supportedFamilies([
              .systemSmall,
              .systemMedium,
              .systemLarge,
              .accessoryCircular,
              .accessoryRectangular,
              .accessoryInline
          ])
      }
  }


#Preview(as: .systemSmall) {
    Widget_2_0()
} timeline: {
    let now = Date()
    let cal = Calendar.current
    let recentDates = Array((0..<7).compactMap { cal.date(byAdding: .day, value: -$0, to: now) }.reversed())
    let recentScores: [Double] = [82, 76, 64, 48, 30, 92, 58]
    let entry = HealthEntry(
        date: now,
        hrv: 50,
        restingHeartRate: 60,
        sleepHours: 7.5,
        sleepQuality: 70,
        readinessScore: 78,
        readinessCategory: "Moderate",
        readinessMode: "morning",
        readinessEmoji: "",
        readinessDescription: "Solid—moderate training recommended",
        recentDates: recentDates,
        recentScores: recentScores,
        recentCategories: recentScores.map { s in
            s >= 80 ? "Optimal" : s >= 50 ? "Moderate" : s >= 30 ? "Low" : "Fatigue"
        }
    )
    return [entry]
}

#Preview(as: .systemMedium) {
    Widget_2_0()
} timeline: {
    let now = Date()
    let cal = Calendar.current
    let recentDates = Array((0..<7).compactMap { cal.date(byAdding: .day, value: -$0, to: now) }.reversed())
    let recentScores: [Double] = [82, 76, 64, 48, 30, 92, 58]
    let entry = HealthEntry(
        date: now,
        hrv: 50,
        restingHeartRate: 60,
        sleepHours: 7.5,
        sleepQuality: 70,
        readinessScore: 78,
        readinessCategory: "Moderate",
        readinessMode: "morning",
        readinessEmoji: "",
        readinessDescription: "Solid—moderate training recommended",
        recentDates: recentDates,
        recentScores: recentScores,
        recentCategories: recentScores.map { s in
            s >= 80 ? "Optimal" : s >= 50 ? "Moderate" : s >= 30 ? "Low" : "Fatigue"
        }
    )
    return [entry]
}

