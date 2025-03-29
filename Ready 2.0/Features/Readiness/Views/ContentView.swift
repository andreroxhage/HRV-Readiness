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
                                    .foregroundStyle(getHRVDeviationColor(viewModel.hrvDeviation))
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
            .background(getGradientBackgroundColor(
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
        fetchHealthData(forceRecalculation: forceRecalculation)
    }
    
    private func fetchHealthData(forceRecalculation: Bool = false) {
        Task { @MainActor in
            isLoading = true
            
            do {
                // Fetch health data using the ViewModel's methods
                
                // Fetch resting heart rate
                do {
                    restingHeartRate = try await viewModel.fetchRestingHeartRate()
                } catch {
                    print("Resting heart rate error: \(error)")
                }
                
                // Fetch sleep data
                do {
                    let sleepData = try await viewModel.fetchSleepData()
                    sleepHours = sleepData.hours
                    sleepQuality = sleepData.quality
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
                    
                    // Update the viewModel's readiness mode
                    viewModel.updateReadinessMode(readinessMode)
                }
                
                // Calculate the readiness score using the health metrics
                viewModel.calculateReadiness(
                    restingHeartRate: restingHeartRate,
                    sleepHours: sleepHours,
                    sleepQuality: sleepQuality
                )
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                print("Error fetching health data: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    // Helper functions for UI
    private func getHRVDeviationColor(_ deviation: Double) -> Color {
        if deviation >= 0 {
            return .green
        } else if deviation >= -5 {
            return .yellow
        } else if deviation >= -10 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func getGradientBackgroundColor(for score: Double, isDarkMode: Bool) -> some View {
        let category = ReadinessCategory.forScore(score)
        
        let gradientColors: [Color]
        
        switch category {
        case .optimal:
            gradientColors = isDarkMode ? 
                [Color.green.opacity(0.1), Color.green.opacity(0.05)] :
                [Color.green.opacity(0.1), Color.green.opacity(0.05)]
        case .moderate:
            gradientColors = isDarkMode ?
                [Color.yellow.opacity(0.1), Color.yellow.opacity(0.05)] :
                [Color.yellow.opacity(0.1), Color.yellow.opacity(0.05)]
        case .low:
            gradientColors = isDarkMode ?
                [Color.orange.opacity(0.1), Color.orange.opacity(0.05)] :
                [Color.orange.opacity(0.1), Color.orange.opacity(0.05)]
        case .fatigue:
            gradientColors = isDarkMode ?
                [Color.red.opacity(0.1), Color.red.opacity(0.05)] :
                [Color.red.opacity(0.1), Color.red.opacity(0.05)]
        default:
            gradientColors = isDarkMode ?
                [Color.gray.opacity(0.1), Color.gray.opacity(0.05)] :
                [Color.gray.opacity(0.1), Color.gray.opacity(0.05)]
        }
        
        return LinearGradient(
            gradient: Gradient(colors: gradientColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: ReadinessViewModel())
    }
}
