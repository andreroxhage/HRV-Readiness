import SwiftUI

struct SettingsView: View {
    @StateObject private var settingsManager: ReadinessSettingsManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ReadinessViewModel
    @State private var showHealthKitAuth = false
    @State private var showingUnsavedChangesAlert = false
    @State private var showRecalcPrompt = false

    // Persisted originals captured on appear for change detection at Save
    @State private var originalReadinessMode: ReadinessMode = .morning
    @State private var originalBaselinePeriod: BaselinePeriod = .sevenDays
    @State private var originalUseRHR: Bool = false
    @State private var originalUseSleep: Bool = false
    @State private var originalMinimumDays: Int = 3
    @State private var originalMorningEndHour: Int = 11
    
    init(viewModel: ReadinessViewModel) {
        self.viewModel = viewModel
        self._settingsManager = StateObject(wrappedValue: ReadinessSettingsManager())
    }
    
    var body: some View {
        NavigationView {
            List {
                // Readiness Mode Section
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("HRV Reading Mode")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Picker("Readiness Mode", selection: $settingsManager.readinessMode) {
                            Text("Morning").tag(ReadinessMode.morning)
                            Text("Rolling").tag(ReadinessMode.rolling)
                        }
                        .pickerStyle(.segmented)
                        .disabled(settingsManager.isSaving || viewModel.isLoading)
                        
                        // Mode description and morning end-hour config
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: settingsManager.readinessMode == .morning ? "sunrise" : "clock.arrow.circlepath")
                                    .foregroundStyle(settingsManager.readinessMode == .morning ? .orange : .blue)
                                    .symbolEffect(.pulse, options: .repeating, value: settingsManager.readinessMode)
                                
                                if settingsManager.readinessMode == .morning {
                                    Text("Measures HRV during sleep (00:00-\(String(format: "%02d", settingsManager.morningEndHour)):00)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Measures HRV over the last 6 hours")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            if settingsManager.readinessMode == .morning {
                                HStack {
                                    Text("Morning window end time")
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Picker("Morning End Hour", selection: $settingsManager.morningEndHour) {
                                        Text("09:00").tag(9)
                                        Text("10:00").tag(10)
                                        Text("11:00").tag(11)
                                        Text("12:00").tag(12)
                                    }
                                    .pickerStyle(.segmented)
                                    .disabled(settingsManager.isSaving || viewModel.isLoading)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                } header: {
                    Text("Measurement Settings")
                } footer: {
                    Text("Morning mode is recommended for most users as it provides more consistent measurements during sleep.")
                }
                
                // Baseline Settings
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Baseline Period")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Picker("Baseline Period", selection: $settingsManager.baselinePeriod) {
                            Text("7 days").tag(BaselinePeriod.sevenDays)
                            Text("14 days").tag(BaselinePeriod.fourteenDays)
                            Text("30 days").tag(BaselinePeriod.thirtyDays)
                        }
                        .pickerStyle(.segmented)
                        .disabled(settingsManager.isSaving || viewModel.isLoading)
                    }
                    
                    // Baseline status
                    HStack {
                        Image(systemName: viewModel.hasBaselineData ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(viewModel.hasBaselineData ? .green : .orange)
                        Text(viewModel.baselineDataStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                } header: {
                    Text("Baseline Calculation")
                } footer: {
                    Text("The baseline is calculated using your HRV data from the selected period. 7-day baseline is recommended as the research-backed default. Longer periods provide more stability but respond slower to changes.")
                }
                
                // Score Adjustment Settings
                Section {
                    Toggle("RHR Adjustment", isOn: $settingsManager.useRHRAdjustment)
                        .disabled(settingsManager.isSaving || viewModel.isLoading)
                    
                    Toggle("Sleep Adjustment", isOn: $settingsManager.useSleepAdjustment)
                        .disabled(settingsManager.isSaving || viewModel.isLoading)
                } header: {
                    Text("Score Adjustments")
                } footer: {
                    Text("Enable additional factors that adjust your readiness score. RHR adjustment reduces score when resting heart rate is elevated. Sleep adjustment reduces score when sleep is insufficient.")
                }
                
                // Advanced Settings
                Section {
                    NavigationLink(destination: AdvancedSettingsView(viewModel: viewModel, settingsManager: settingsManager)) {
                        HStack {
                            Image(systemName: "gear")
                                .foregroundStyle(.blue)
                            Text("Advanced Settings")
                            Spacer()
                        }
                    }
                    .disabled(settingsManager.isSaving || viewModel.isLoading)
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("Configure minimum baseline requirements and perform manual recalculations.")
                }
                
                // Health Kit Section
                Section {
                    Button {
                        showHealthKitAuth = true
                    } label: {
                        HStack {
                            Image(systemName: "heart.text.square")
                                .foregroundStyle(.red)
                            Text("Health App Permissions")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(settingsManager.isSaving || viewModel.isLoading)
                } header: {
                    Text("Data Sources")
                } footer: {
                    Text("Manage what health data Ready can access from the Health app. HRV is required to calculate readiness. Resting heart rate and sleep are optional adjustments.")
                }
                
                // About Section
                Section {
                    NavigationLink(destination: AboutView()) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.blue)
                            Text("About Ready")
                            Spacer()
                        }
                    }
                    
                    NavigationLink(destination: HelpView()) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.blue)
                            Text("Help & Support")
                            Spacer()
                        }
                    }
                } header: {
                    Text("Information")
                }
                
                // Debug Section (Development builds only)
                Section {
                    NavigationLink(destination: DebugDataView(viewModel: viewModel)) {
                        HStack {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .foregroundStyle(.blue)
                            Text("Debug Data")
                            Spacer()
                        }
                    }
                } header: {
                    Text("Debug Information")
                } footer: {
                    Text("View current metric values, baselines, and historical data for troubleshooting.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if settingsManager.hasUnsavedChanges {
                        Button("Cancel") {
                            showingUnsavedChangesAlert = true
                        }
                    } else {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if settingsManager.hasUnsavedChanges {
                        Button("Save") {
                            Task {
                                do {
                                    try await settingsManager.saveSettings()
                                    // Build change set by comparing persisted before/after
                                    let u = UserDefaultsManager.shared
                                    var changeTypes: Set<SettingsChangeType> = []
                                    if originalReadinessMode != u.readinessMode { changeTypes.insert(.readinessMode) }
                                    if originalBaselinePeriod != u.baselinePeriod { changeTypes.insert(.baselinePeriod) }
                                    if originalUseRHR != u.useRHRAdjustment { changeTypes.insert(.rhrAdjustment) }
                                    if originalUseSleep != u.useSleepAdjustment { changeTypes.insert(.sleepAdjustment) }
                                    if originalMinimumDays != u.minimumDaysForBaseline { changeTypes.insert(.minimumDays) }
                                    if originalMorningEndHour != u.morningEndHour { changeTypes.insert(.morningEndHour) }

                                    let changes = ReadinessSettingsChange(
                                        types: changeTypes,
                                        previousValues: SettingsValues(
                                            mode: originalReadinessMode,
                                            period: originalBaselinePeriod,
                                            rhrEnabled: originalUseRHR,
                                            sleepEnabled: originalUseSleep,
                                            minimumDays: originalMinimumDays,
                                            morningEndHour: originalMorningEndHour
                                        ),
                                        newValues: SettingsValues(
                                            mode: u.readinessMode,
                                            period: u.baselinePeriod,
                                            rhrEnabled: u.useRHRAdjustment,
                                            sleepEnabled: u.useSleepAdjustment,
                                            minimumDays: u.minimumDaysForBaseline,
                                            morningEndHour: u.morningEndHour
                                        )
                                    )

                                    if changes.requiresHistoricalRecalculation {
                                        showRecalcPrompt = true
                                    } else if changes.requiresCurrentRecalculation {
                                        viewModel.handleSettingsChanges(changes)
                                        dismiss()
                                    } else {
                                        dismiss()
                                    }
                                } catch {
                                    print("❌ Failed to save settings: \(error)")
                                }
                            }
                        }
                        .disabled(settingsManager.isSaving || viewModel.isLoading)
                    }
                }
            }
        }
        .sheet(isPresented: $showHealthKitAuth) {
            HealthKitAuthView()
        }
        .confirmationDialog(
            "Recalculate historical scores?",
            isPresented: $showRecalcPrompt,
            titleVisibility: .visible
        ) {
            Button("Run now", role: .none) {
                // Run current and historical recalculation
                Task { @MainActor in
                    await viewModel.recalculateAllScores()
                    await viewModel.loadTodaysReadinessScore()
                    showRecalcPrompt = false
                    dismiss()
                }
            }
            Button("Later", role: .cancel) {
                // Only refresh today's score for now
                Task { @MainActor in
                    await viewModel.loadTodaysReadinessScore()
                    showRecalcPrompt = false
                    dismiss()
                }
            }
        } message: {
            Text("Changes you made affect historical calculations. You can recalculate past scores now or do it later from Advanced Settings.")
        }
        .alert("Unsaved Changes", isPresented: $showingUnsavedChangesAlert) {
            Button("Discard Changes", role: .destructive) {
                settingsManager.discardChanges()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. Do you want to discard them?")
        }
        .onAppear {
            // Capture original persisted settings for change detection
            let u = UserDefaultsManager.shared
            originalReadinessMode = u.readinessMode
            originalBaselinePeriod = u.baselinePeriod
            originalUseRHR = u.useRHRAdjustment
            originalUseSleep = u.useSleepAdjustment
            originalMinimumDays = u.minimumDaysForBaseline
            originalMorningEndHour = u.morningEndHour
        }
    }
}

// Helper extensions for better readability
extension ReadinessMode: CaseIterable {
    public static var allCases: [ReadinessMode] {
        return [.morning, .rolling]
    }
}

// Placeholder views for navigation links
struct AboutView: View {
    var body: some View {
        Text("About Ready 2.0")
            .navigationTitle("About")
    }
}

struct HelpView: View {
    var body: some View {
        Text("Help & Support")
            .navigationTitle("Help")
    }
}

struct HealthKitAuthView: View {
    var body: some View {
        Text("HealthKit Authorization")
            .navigationTitle("Health Permissions")
    }
}

#Preview {
    SettingsView(viewModel: ReadinessViewModel())
} 
