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
    @State private var showingInfo = false
    @State private var showingSettings = false
    @Environment(\.appearanceViewModel) private var appearanceViewModel
    @Environment(\.colorScheme) private var systemColorScheme
    
    // Health metrics state variables
    @State private var restingHeartRate: Double = 0
    @State private var sleepHours: Double = 0
    @State private var sleepQuality: Int = 0
    @State private var isLoading: Bool = false

    private var effectiveColorScheme: ColorScheme {
        appearanceViewModel.colorScheme ?? systemColorScheme
    }

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
                        VStack(spacing: 12) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Readiness")
                                    .font(.system(.title, design: .rounded, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text(String(format: "%.0f", viewModel.readinessScore))
                                            .font(.system(size: 48, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.secondary)
                                            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                                            .monospacedDigit()
                                            .minimumScaleFactor(0.8)
                                            .accessibilityLabel("\(Int(viewModel.readinessScore)) out of 100")
                                        Text("/ 100")
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                            .accessibilityHidden(true)
                                }
                            }
                            
                            Text(viewModel.readinessCategory.description)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.opacity)
                                .animation(.easeInOut(duration: 0.6), value: viewModel.readinessCategory.description)
                                .id(viewModel.readinessCategory.description)
                                .accessibilityLabel("Category: \(viewModel.readinessCategory.description)")
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Today's readiness score: \(Int(viewModel.readinessScore)) out of 100, \(viewModel.readinessCategory.description)")
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("History")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            CalendarView(viewModel: viewModel)
                        }
                    }
                    
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Score Details")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(alignment: .firstTextBaseline) {
                                Text("Base Score")
                                    .font(.body)
                                Spacer()
                                Text("\(String(format: "%.0f", viewModel.readinessScore - viewModel.rhrAdjustment - viewModel.sleepAdjustment))")
                                    .font(.body.weight(.semibold))
                                    .monospacedDigit()
                            }
                            
                            if viewModel.rhrAdjustment != 0 {
                                HStack(alignment: .firstTextBaseline) {
                                    Text("RHR Adjustment")
                                        .font(.body)
                                    Spacer()
                                    Text("\(String(format: "%+.0f", viewModel.rhrAdjustment))")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(viewModel.rhrAdjustment < 0 ? .red : .green)
                                        .monospacedDigit()
                                }
                            }
                            
                            if viewModel.sleepAdjustment != 0 {
                                HStack(alignment: .firstTextBaseline) {
                                    Text("Sleep Adjustment")
                                        .font(.body)
                                    Spacer()
                                    Text("\(String(format: "%+.0f", viewModel.sleepAdjustment))")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(viewModel.sleepAdjustment < 0 ? .red : .green)
                                        .monospacedDigit()
                                }
                            }
                            
                            HStack(alignment: .firstTextBaseline) {
                                Text("Final Score (incl. sleep and resting heart rate)")
                                    .font(.body)
                                Spacer()
                                Text("\(String(format: "%.0f", viewModel.readinessScore))")
                                    .font(.body.weight(.semibold))
                                    .monospacedDigit()
                            }
                        }
                    }
                    
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("HRV Analysis")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(alignment: .firstTextBaseline) {
                                Text("7-Day Baseline")
                                    .font(.body)
                                Spacer()
                                Text("\(Int(viewModel.hrvBaseline)) ms")
                                    .font(.body.weight(.semibold))
                                    .monospacedDigit()
                            }
                            
                            HStack(alignment: .firstTextBaseline) {
                                Text("Today's HRV")
                                    .font(.body)
                                Spacer()
                                Text("\(Int(viewModel.hrvBaseline * (1 + viewModel.hrvDeviation / 100))) ms")
                                    .font(.body.weight(.semibold))
                                    .monospacedDigit()
                            }
                            
                            HStack(alignment: .firstTextBaseline) {
                                Text("Deviation")
                                    .font(.body)
                                Spacer()
                                Text(String(format: "%.1f%%", viewModel.hrvDeviation))
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(viewModel.hrvDeviationColor)
                                    .monospacedDigit()
                            }
                            
                            UnderstandingScore(viewModel: viewModel)
                        }
                    }
                }
                .refreshable {
                    refreshData(forceRecalculation: true)
                }
                .listStyle(.insetGrouped)
                .scrollClipDisabled()
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
                .safeAreaInset(edge: .bottom) {
                    ZStack {
                        // Glass background with blur
                        RoundedRectangle(cornerRadius: 0)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.1),
                                                Color.white.opacity(0.05)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                            .overlay(
                                Rectangle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                    .frame(height: 0.5),
                                alignment: .top
                            )
                        
                        HStack {
                            Spacer()
                            Button(action: {
                                showingSettings = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 16, weight: .medium))
                                    Text("Settings")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            effectiveColorScheme == .dark ? Color.white : Color.black,
                                            effectiveColorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(
                                    ZStack {
                                        // Glass capsule background
                                        Capsule()
                                            .fill(.ultraThinMaterial)
                                        
                                        // Subtle gradient overlay
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.15),
                                                        Color.white.opacity(0.05)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                        
                                        // Border glow
                                        Capsule()
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.3),
                                                        Color.white.opacity(0.1)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    }
                                )
                                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                            }
                            .buttonStyle(GlassButtonStyle())
                            .accessibilityLabel("Settings")
                            .accessibilityHint("Opens settings to configure readiness calculation parameters")
                            .padding(.trailing, 20)
                        }
                        .padding(.vertical, 12)
                    }
                    .frame(height: 80)
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView(viewModel: viewModel)
                }
                .alert(
                    "Readiness Update",
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
                            // Show inline data status when permissions are partial
                            if case .partialPermissions(let missing) = error, !missing.isEmpty {
                                Divider()
                                Text("Missing: \(missing.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .background(viewModel.getBackgroundGradient(
                for: viewModel.readinessScore,
                isDarkMode: effectiveColorScheme == .dark
            )
            .ignoresSafeArea())
        }
        .preferredColorScheme(appearanceViewModel.colorScheme)
        .onAppear {
            print("🔄 CONTENT: ContentView appeared after onboarding completion")
            Task { @MainActor in
                // First check if we need to perform initial setup
                await viewModel.checkAndPerformInitialSetup()
                
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
            let previousCategory = viewModel.readinessCategory
            
            // Debug current settings (source of truth is ViewModel/UserDefaultsManager)
            print("🔄 CONTENT: Starting health data fetch")
            print("⚙️ CONTENT: ViewModel settings - RHR: \(viewModel.useRHRAdjustment), Sleep: \(viewModel.useSleepAdjustment)")
            
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
            
            // Provide haptic feedback if category changed
            if previousCategory != viewModel.readinessCategory {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }

}

// Glass button style for the floating settings button
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: ReadinessViewModel())
    }
}
