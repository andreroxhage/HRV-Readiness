//
//  ContentView.swift
//  Ready 2.0
//
//  Created by André Roxhage on 2025-03-13.
//

import SwiftUI
import HealthKit
import CoreData
import UIKit

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
    
    var sharedDefaults: UserDefaults? {
        UserDefaults.standard
    }
    
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
    @StateObject private var appearanceViewModel = AppearanceViewModel.shared
    @AppStorage("readinessMode") private var readinessMode: String = "morning"
    @State private var showingInfo = false
    @State private var previousMode: String = ""
    @State private var showingSettings = false
    
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
            ZStack {
                Color.clear
                    .ignoresSafeArea()
                
                List {                
                    if appearanceViewModel.showParticles {
                        TodaysScoreParticlesView(viewModel: viewModel)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                            .background(Color.clear)
                    }

                    Section {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Today's Readiness")
                                    .font(.title)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.bottom, 5)
                                HStack(spacing: 2) {
                                        Text(viewModel.formattedScore)
                                            .font(.title)
                                            .foregroundStyle(.secondary)
                                        Text("/ 100")
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                }
                            }
                            
                            Text(viewModel.readinessCategory.description)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .transition(.opacity)
                                .id(viewModel.readinessCategory.description)
                        }
                    }.onChange(of: readinessMode) { oldValue, newValue in
                        if oldValue != newValue {
                            Task { @MainActor in
                                // Wait a moment to ensure settings view has time to dismiss if needed
                                viewModel.updateReadinessMode(newValue)
                                
                                // Slight delay before refreshing data to avoid race conditions
                                try? await Task.sleep(for: .milliseconds(100))
                                
                                // Force recalculation with the new mode
                                refreshData(forceRecalculation: true)
                            }
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
                                Text("Final Score (incl. sleep and resting heart rate)")
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
                            }
                            
                            UnderstandingScore(viewModel: viewModel)
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
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "gearshape")
                                .foregroundStyle(appearanceViewModel.colorScheme == .dark ? .white : .black)
                        }
                    }
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView(viewModel: viewModel)
                }
                .alert(
                    "Readiness Update Failed",
                    isPresented: Binding(
                        get: { viewModel.error != nil },
                        set: { if !$0 { 
                            Task { @MainActor in
                                viewModel.error = nil
                            } 
                        }}
                    )
                ) {
                    Button("OK") {
                        Task { @MainActor in
                            viewModel.error = nil
                        }
                    }
                } message: {
                    if let error = viewModel.error {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(error.localizedDescription)
                            if let suggestion = error.recoverySuggestion {
                                Text(suggestion)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .background(viewModel.getGradientBackgroundColor(
                for: viewModel.readinessScore,
                isDarkMode: appearanceViewModel.colorScheme == .dark
            )
            .ignoresSafeArea())
        }
        .preferredColorScheme(appearanceViewModel.colorScheme)
        .onAppear {
            Task { @MainActor in
                previousMode = readinessMode
                fetchHealthData()
            }
        }
    }
    
    private func refreshData(forceRecalculation: Bool = false) {
        fetchHealthData()
    }
    
    private func fetchHealthData() {
        Task { @MainActor in
            isLoading = true
            
            do {              
                // Update timestamp
                HealthDataProvider.shared.sharedDefaults?.set(Date(), forKey: HealthDataProvider.StorageKeys.lastUpdateTime)
                
                // Fetch HRV data - our primary focus now
                do {
                    let fetchedHrv = try await HealthDataProvider.shared.fetchHRV()
                    await MainActor.run {
                        hrv = fetchedHrv
                    }
                    HealthDataProvider.shared.sharedDefaults?.set(hrv, forKey: HealthDataProvider.StorageKeys.lastHRV)
                } catch {
                    print("HRV data error: \(error)")
                }
                
                // Fetch resting heart rate - our primary focus now
                do {
                    let fetchedRhr = try await HealthDataProvider.shared.fetchRestingHeartRate()
                    await MainActor.run {
                        restingHeartRate = fetchedRhr
                    }
                    HealthDataProvider.shared.sharedDefaults?.set(restingHeartRate, forKey: HealthDataProvider.StorageKeys.lastRestingHeartRate)
                } catch {
                    print("Resting heart rate error: \(error)")
                }
                
                // Fetch sleep data - our primary focus now
                do {
                    let sleepData = try await HealthDataProvider.shared.fetchSleepData()
                    await MainActor.run {
                        sleepHours = sleepData.hours
                        sleepQuality = sleepData.quality
                        sleepStartTime = sleepData.startTime
                        sleepEndTime = sleepData.endTime
                    }
                    
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
                    await MainActor.run {
                        previousMode = readinessMode
                    }
                    
                    // Update the viewModel's readiness mode using string-based approach
                    await MainActor.run {
                        // The viewModel will handle the conversion from string to enum internally
                        self.viewModel.updateReadinessMode(readinessMode)
                    }
                }
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                print("Health data error: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
