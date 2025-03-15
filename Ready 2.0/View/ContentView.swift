//
//  ContentView.swift
//  Ready 2.0
//
//  Created by André Roxhage on 2025-03-13.
//

import SwiftUI
import HealthKit
import CoreData

// Create a simple wrapper for the HealthKitManager
// This is a temporary solution until we fix the module structure
class HealthDataProvider {
    static let shared = HealthDataProvider()
    
    private init() {}
    
    
    func fetchHRV() async throws -> Double {
        return 50
    }
    
    func fetchRestingHeartRate() async throws -> Double {
        return 60
    }
    
    struct SleepData {
        let hours: Double
        let quality: Int
        let startTime: Date?
        let endTime: Date?
    }
    
    func fetchSleepData() async throws -> SleepData {
        return SleepData(hours: 7.5, quality: 85, startTime: Date().addingTimeInterval(-8 * 3600), endTime: Date())
    }
    
    // Mock shared defaults
    var sharedDefaults: UserDefaults? {
        UserDefaults.standard
    }
    
    // Mock storage keys
    struct StorageKeys {
        static let lastUpdateTime = "lastUpdateTime"
        static let lastHRV = "lastHRV"
        static let lastRestingHeartRate = "lastRestingHeartRate"
        static let lastSleepHours = "lastSleepHours"
        static let sleepQuality = "sleepQuality"
        static let sleepStartTime = "sleepStartTime"
        static let sleepEndTime = "sleepEndTime"
    }
}

struct ContentView: View {
    @ObservedObject var viewModel = ReadinessViewModel()
    @AppStorage("readinessMode") private var readinessMode: String = "morning"
    @State private var showingInfo = false
    @State private var previousMode: String = ""
    
    // Health metrics state variables
    @State private var hrv: Double = 0
    @State private var restingHeartRate: Double = 0
    @State private var sleepHours: Double = 0
    @State private var sleepQuality: Int = 0
    @State private var sleepStartTime: Date? = nil
    @State private var sleepEndTime: Date? = nil
    @State private var isLoading: Bool = false
    @State private var error: Error? = nil
    
    var body: some View {
        NavigationView {
            List {
                // Mode Selector Section
                Section {
                    Picker("Readiness Mode", selection: $readinessMode) {
                        Text("Morning").tag("morning")
                        Text("Rolling").tag("rolling")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: readinessMode) { oldValue, newValue in
                        print("DEBUG: Mode changed from \(oldValue) to \(newValue)")
                        if oldValue != newValue {
                            // Immediately update the viewModel's mode
                            // We'll use string-based mode handling to avoid ReadinessMode enum issues
                            DispatchQueue.main.async {
                                // The viewModel will handle the conversion from string to enum internally
                                viewModel.updateReadinessMode(newValue)
                            }
                            // Force recalculation with the new mode
                            refreshData(forceRecalculation: true)
                        }
                    }
                } header: {
                    HStack {
                        Text("Readiness Mode")
                        Spacer()
                        Button(action: {
                            refreshData(forceRecalculation: true)
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Readiness Score Section
                Section {
                    VStack(spacing: 20) {
                        // Readiness Score Circle
                        ZStack {
                            Circle()
                                .stroke(
                                    viewModel.categoryColor.opacity(0.2),
                                    lineWidth: 15
                                )
                                .frame(width: 150, height: 150)
                            
                            Circle()
                                .trim(from: 0, to: viewModel.readinessScore / 100)
                                .stroke(
                                    viewModel.categoryColor,
                                    style: StrokeStyle(
                                        lineWidth: 15,
                                        lineCap: .round
                                    )
                                )
                                .frame(width: 150, height: 150)
                                .rotationEffect(.degrees(-90))
                            
                            VStack(spacing: 5) {
                                Text(viewModel.formattedScore)
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                
                                Text(viewModel.readinessCategory.rawValue)
                                    .font(.headline)
                                    .foregroundStyle(viewModel.categoryColor)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        
                        // Readiness Description
                        Text(viewModel.readinessCategory.emoji + " " + viewModel.readinessCategory.description)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        
                        // Mode indicator
                        HStack {
                            Image(systemName: readinessMode == "morning" ? "sunrise" : "clock.arrow.circlepath")
                                .foregroundStyle(readinessMode == "morning" ? .orange : .blue)
                            
                            Text(readinessMode == "morning" ? "Morning (00:00-10:00)" : "Rolling (Last 6 hours)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 10)
                } header: {
                    Text("Today's Readiness")
                }
                
                // Score Details Section
                Section("Score Details") {
                    HStack {
                        Text("Base Score")
                        Spacer()
                        Text("\(String(format: "%.0f", viewModel.readinessScore - viewModel.rhrAdjustment - viewModel.sleepAdjustment))")
                            .bold()
                    }
                    
                    if viewModel.rhrAdjustment != 0 {
                        HStack {
                            Text("RHR Adjustment")
                            Spacer()
                            Text("\(String(format: "%+.0f", viewModel.rhrAdjustment))")
                                .foregroundStyle(.red)
                                .bold()
                        }
                    }
                    
                    if viewModel.sleepAdjustment != 0 {
                        HStack {
                            Text("Sleep Adjustment")
                            Spacer()
                            Text("\(String(format: "%+.0f", viewModel.sleepAdjustment))")
                                .foregroundStyle(.red)
                                .bold()
                        }
                    }
                    
                    HStack {
                        Text("Final Score")
                        Spacer()
                        Text("\(viewModel.formattedScore)")
                            .bold()
                    }
                }
                
                // HRV Analysis Section
                Section("HRV Analysis") {
                    HStack {
                        Text("7-Day Baseline")
                        Spacer()
                        Text("\(Int(viewModel.hrvBaseline)) ms")
                            .bold()
                    }
                    
                    HStack {
                        Text("Today's HRV")
                        Spacer()
                        Text("\(Int(viewModel.hrvBaseline * (1 + viewModel.hrvDeviation / 100))) ms")
                            .bold()
                    }
                    
                    HStack {
                        Text("Deviation")
                        Spacer()
                        Text(viewModel.formattedHRVDeviation)
                            .foregroundStyle(viewModel.hrvDeviationColor)
                            .bold()
                    }
                }
                
                // Trend Section
                Section("7-Day Trend") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.pastScores.prefix(7).reversed(), id: \.date) { score in
                                VStack(spacing: 8) {
                                    Text(formatDate(score.date ?? Date()))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    
                                    ZStack {
                                        Circle()
                                            .fill(getCategoryColor(score.readinessCategory ?? "Moderate").opacity(0.2))
                                            .frame(width: 50, height: 50)
                                        
                                        Text("\(Int(score.score))")
                                            .font(.system(.body, design: .rounded))
                                            .bold()
                                    }
                                    
                                    Text(score.readinessCategory ?? "Moderate")
                                        .font(.caption2)
                                        .foregroundStyle(getCategoryColor(score.readinessCategory ?? "Moderate"))
                                }
                                .frame(width: 70)
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                    }
                    .frame(height: 120)
                }
                
                // Understanding Section (collapsible)
                Section {
                    Button(action: {
                        showingInfo.toggle()
                    }) {
                        HStack {
                            Text("Understanding Your Score")
                            Spacer()
                            Image(systemName: showingInfo ? "chevron.up" : "chevron.down")
                        }
                    }
                    
                    if showingInfo {
                        VStack(alignment: .leading, spacing: 12) {
                            ScoreCategoryRow(
                                title: "Optimal (80-100)",
                                emoji: "✅",
                                description: "Your body is well-recovered and ready for high-intensity training.",
                                color: .green
                            )
                            
                            ScoreCategoryRow(
                                title: "Moderate (50-79)",
                                emoji: "🟡",
                                description: "Your body is moderately recovered. Consider moderate-intensity training.",
                                color: .yellow
                            )
                            
                            ScoreCategoryRow(
                                title: "Low (30-49)",
                                emoji: "🔴",
                                description: "Your body shows signs of fatigue. Consider light activity or active recovery.",
                                color: .orange
                            )
                            
                            ScoreCategoryRow(
                                title: "Fatigue (0-29)",
                                emoji: "💀",
                                description: "Your body needs rest. Focus on recovery and avoid intense training.",
                                color: .red
                            )
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Readiness")
            .refreshable {
                refreshData(forceRecalculation: true)
            }
            .overlay {
                if viewModel.isLoading {
                    ZStack {
                        Color.black.opacity(0.1)
                            .ignoresSafeArea()
                        ProgressView()
                            .scaleEffect(1.5)
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "Unknown error")
            }
        }
        .onAppear {
            // Store the initial mode
            previousMode = readinessMode
            fetchHealthData()
        }
    }
    
    private func refreshData(forceRecalculation: Bool = false) {
        fetchHealthData()
    }
    
    private func fetchHealthData() {
        isLoading = true
        
        Task {
            do {              
                // Update timestamp
                HealthDataProvider.shared.sharedDefaults?.set(Date(), forKey: HealthDataProvider.StorageKeys.lastUpdateTime)
                
                // Fetch HRV data - our primary focus now
                do {
                    hrv = try await HealthDataProvider.shared.fetchHRV()
                    HealthDataProvider.shared.sharedDefaults?.set(hrv, forKey: HealthDataProvider.StorageKeys.lastHRV)
                } catch {
                    print("HRV data error: \(error)")
                }
                
                // Fetch resting heart rate - our primary focus now
                do {
                    restingHeartRate = try await HealthDataProvider.shared.fetchRestingHeartRate()
                    HealthDataProvider.shared.sharedDefaults?.set(restingHeartRate, forKey: HealthDataProvider.StorageKeys.lastRestingHeartRate)
                } catch {
                    print("Resting heart rate error: \(error)")
                }
                
                // Fetch sleep data - our primary focus now
                do {
                    let sleepData = try await HealthDataProvider.shared.fetchSleepData()
                    sleepHours = sleepData.hours
                    sleepQuality = sleepData.quality
                    sleepStartTime = sleepData.startTime
                    sleepEndTime = sleepData.endTime
                    
                    HealthDataProvider.shared.sharedDefaults?.set(sleepHours, forKey: HealthDataProvider.StorageKeys.lastSleepHours)
                    HealthDataProvider.shared.sharedDefaults?.set(sleepQuality, forKey: HealthDataProvider.StorageKeys.sleepQuality)
                    HealthDataProvider.shared.sharedDefaults?.set(sleepData.startTime, forKey: HealthDataProvider.StorageKeys.sleepStartTime)
                    HealthDataProvider.shared.sharedDefaults?.set(sleepData.endTime, forKey: HealthDataProvider.StorageKeys.sleepEndTime)
                } catch {
                    print("Sleep data error: \(error)")
                }

                // Check if mode has changed since last refresh
                let modeChanged = previousMode != readinessMode
                if modeChanged {
                    print("DEBUG: Mode changed from \(previousMode) to \(readinessMode)")
                    previousMode = readinessMode
                    
                    // Update the viewModel's readiness mode using string-based approach
                    DispatchQueue.main.async {
                        // The viewModel will handle the conversion from string to enum internally
                        self.viewModel.updateReadinessMode(readinessMode)
                    }
                }

                // Calculate and save readiness score using the current mode
                viewModel.calculateAndSaveReadinessScoreForCurrentMode(
                    restingHeartRate: restingHeartRate,
                    sleepHours: sleepHours,
                    sleepQuality: sleepQuality,
                    forceRecalculation: modeChanged
                )

                error = nil
            }
            
            // Set isLoading to false after all async operations are complete
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
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

struct ScoreCategoryRow: View {
    let title: String
    let emoji: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(title) \(emoji)")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(color)
            }
            
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
