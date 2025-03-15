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

    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.clear
                    .ignoresSafeArea()
                
                List {                
                    TodaysScoreParticlesView(viewModel: viewModel)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                        .background(Color.clear)

                    Section {
                        VStack(spacing: 8) {
                            HStack(spacing: 32) {
                                Text("Today's Readiness")
                                    .font(.title)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.bottom, 5)
                                Text(viewModel.formattedScore)
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text(viewModel.readinessCategory.description)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .transition(.opacity)
                                .id(viewModel.readinessCategory.description)
                        }
                    }.onChange(of: readinessMode) { oldValue, newValue in
                        if oldValue != newValue {
                            DispatchQueue.main.async {
                                viewModel.updateReadinessMode(newValue)
                            }
                            refreshData(forceRecalculation: true)
                        }
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("History")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 5)
                            
                            CalendarView(viewModel: viewModel)
                        }
                    }
                    
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Score Details")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 5)
                            
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
                    }
                    
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("HRV Analysis")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 5)
                            
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
                            
                            UnderstandingScore(viewModel: viewModel)
                        }
                    }

                    // Mode Selector Section
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Readiness Mode")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 5)
                            
                            Picker("Readiness Mode", selection: $readinessMode) {
                                Text("Morning").tag("morning")
                                Text("Rolling").tag("rolling")
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: readinessMode) { oldValue, newValue in
                                print("DEBUG: Mode changed from \(oldValue) to \(newValue)")
                                if oldValue != newValue {
                                    DispatchQueue.main.async {
                                        viewModel.updateReadinessMode(newValue)
                                    }
                                    refreshData(forceRecalculation: true)
                                }
                            }
                        }

                        // Mode indicator
                        HStack {
                            Image(systemName: readinessMode == "morning" ? "sunrise" : "clock.arrow.circlepath")
                                .foregroundStyle(readinessMode == "morning" ? .orange : .blue)
                                .symbolEffect(.pulse, options: .repeating, value: readinessMode)
                            
                            Text(readinessMode == "morning" ? "Morning (00:00-10:00)" : "Rolling (Last 6 hours)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .contentTransition(.symbolEffect(.replace))
                    } header: {
                        HStack {
                            Spacer()
                            Button(action: {
                                refreshData(forceRecalculation: true)
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .refreshable {
                    refreshData(forceRecalculation: true)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
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
            .background(viewModel.getGradientBackgroundColor(
                for: viewModel.readinessScore, 
                isDarkMode: colorScheme == .dark
            )
            .ignoresSafeArea())
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
