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

struct ContentView: View {
    @ObservedObject var viewModel: ReadinessViewModel
    @AppStorage("readinessMode") private var readinessMode: String = "morning"
    @State private var showingInfo = false
    @State private var previousMode: String = ""
    @State private var showingSettings = false
    @Environment(\.appearanceViewModel) private var appearanceViewModel
    
    // Health metrics state variables
    @State private var restingHeartRate: Double = 0
    @State private var sleepHours: Double = 0
    @State private var sleepQuality: Int = 0
    @State private var isLoading: Bool = false

    var body: some View {
        // Show initial setup view if needed
        if viewModel.isPerformingInitialSetup {
            InitialSetupView(viewModel: viewModel)
        } else {
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
                                        Text(String(format: "%.0f", viewModel.readinessScore))
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
                                        .foregroundStyle(viewModel.rhrAdjustment < 0 ? .red : .green)
                                        .bold()
                                }
                            }
                            
                            if viewModel.sleepAdjustment != 0 {
                                HStack {
                                    Text("Sleep Adjustment")
                                    Spacer()
                                    Text("\(String(format: "%+.0f", viewModel.sleepAdjustment))")
                                        .foregroundStyle(viewModel.sleepAdjustment < 0 ? .red : .green)
                                        .bold()
                                }
                            }
                            
                            HStack {
                                Text("Final Score (incl. sleep and resting heart rate)")
                                Spacer()
                                Text("\(String(format: "%.0f", viewModel.readinessScore))")
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
                                Text(String(format: "%.1f%%", viewModel.hrvDeviation))
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
            .background(viewModel.getBackgroundGradient(
                for: viewModel.readinessScore,
                isDarkMode: appearanceViewModel.colorScheme == .dark
            )
            .ignoresSafeArea())
        }
        .preferredColorScheme(appearanceViewModel.colorScheme)
        .onAppear {
            print("🔄 CONTENT: ContentView appeared after onboarding completion")
            Task { @MainActor in
                // First check if we need to perform initial setup
                await viewModel.checkAndPerformInitialSetup()
                
                // Then sync @AppStorage with viewModel's current mode on app launch
                if readinessMode != viewModel.readinessMode.rawValue {
                    readinessMode = viewModel.readinessMode.rawValue
                }
                previousMode = readinessMode
                fetchHealthData()
            }
        }
        } // Close the else clause
    }
    
    private func refreshData(forceRecalculation: Bool = false) {
        fetchHealthData(forceRecalculation: forceRecalculation)
    }
    
    private func fetchHealthData(forceRecalculation: Bool = false) {
        Task { @MainActor in
            isLoading = true
            
            // Debug current settings from multiple sources
            print("🔄 CONTENT: Starting health data fetch")
            print("⚙️ CONTENT: ViewModel settings - RHR: \(viewModel.useRHRAdjustment), Sleep: \(viewModel.useSleepAdjustment)")
            print("⚙️ CONTENT: UserDefaults direct - RHR: \(UserDefaults.standard.bool(forKey: "useRHRAdjustment")), Sleep: \(UserDefaults.standard.bool(forKey: "useSleepAdjustment"))")
            print("⚙️ CONTENT: AppStorage values - RHR: \(UserDefaults.standard.object(forKey: "useRHRAdjustment") ?? "not set"), Sleep: \(UserDefaults.standard.object(forKey: "useSleepAdjustment") ?? "not set")")
            
            // Fetch resting heart rate only if RHR adjustment is enabled
            if viewModel.useRHRAdjustment {
                print("💓 CONTENT: RHR adjustment ENABLED - attempting to fetch RHR data")
                do {
                    restingHeartRate = try await viewModel.fetchRestingHeartRate()
                    print("✅ CONTENT: Successfully fetched RHR: \(restingHeartRate) bpm")
                } catch {
                    print("❌ CONTENT: Resting heart rate error: \(error)")
                    restingHeartRate = 0 // Set default when error occurs
                    print("⚠️ CONTENT: Using default RHR value: 0 due to error")
                }
            } else {
                restingHeartRate = 0 // Set default when RHR adjustment is disabled
                print("💓 CONTENT: RHR adjustment DISABLED, using default value: 0")
            }
            
            // Fetch sleep data only if sleep adjustment is enabled
            if viewModel.useSleepAdjustment {
                do {
                    let sleepData = try await viewModel.fetchSleepData()
                    sleepHours = sleepData.hours
                    sleepQuality = sleepData.quality
                    print("😴 CONTENT: Fetched sleep: \(sleepHours)h, quality: \(sleepQuality)")
                } catch {
                    print("⚠️ CONTENT: Sleep data error: \(error)")
                    sleepHours = 0
                    sleepQuality = 0
                }
            } else {
                // Set default values when sleep adjustment is disabled
                sleepHours = 0
                sleepQuality = 0
                print("😴 CONTENT: Sleep adjustment disabled, using default values: 0h")
            }

            // Calculate the readiness score using the health metrics
            print("🎯 CONTENT: About to call viewModel.calculateReadiness with final values:")
            print("   - restingHeartRate: \(restingHeartRate)")
            print("   - sleepHours: \(sleepHours)")
            print("   - sleepQuality: \(sleepQuality)")
            
            viewModel.calculateReadiness(
                restingHeartRate: restingHeartRate,
                sleepHours: sleepHours,
                sleepQuality: sleepQuality
            )
            
            await MainActor.run {
                isLoading = false
            }
        }
    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: ReadinessViewModel())
    }
}
