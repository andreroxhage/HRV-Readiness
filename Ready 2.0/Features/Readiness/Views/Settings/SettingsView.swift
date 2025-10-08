import SwiftUI

struct SettingsView: View {
    @StateObject private var settingsManager: ReadinessSettingsManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: ReadinessViewModel
    @State private var showHealthKitAuth = false
    @State private var showingUnsavedChangesAlert = false
    // Persisted originals captured on appear for change detection at Save
    @State private var originalBaselinePeriod: BaselinePeriod = .sevenDays
    @State private var originalUseRHR: Bool = false
    @State private var originalUseSleep: Bool = false
    @State private var originalMinimumDays: Int = 3
    @State private var originalMorningEndHour: Int = 11
    
    init(viewModel: ReadinessViewModel) {
        self.viewModel = viewModel
        self._settingsManager = StateObject(wrappedValue: ReadinessSettingsManager())
    }
    
    private var scoreTintColor: Color {
        let category = viewModel.readinessCategory
        let isDark = colorScheme == .dark
        
        switch category {
        case .optimal:
            return isDark ? Color.green.opacity(0.1) : Color.green.opacity(0.05)
        case .moderate:
            return isDark ? Color.yellow.opacity(0.1) : Color.yellow.opacity(0.05)
        case .low:
            return isDark ? Color.orange.opacity(0.1) : Color.orange.opacity(0.05)
        case .fatigue:
            return isDark ? Color.red.opacity(0.1) : Color.red.opacity(0.05)
        default:
            return Color.clear
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Score-based background tint
                scoreTintColor
                    .ignoresSafeArea()
                
            List {
                // Morning Window Configuration
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Morning Window End Time")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                        
                        Picker("Morning End Hour", selection: $settingsManager.morningEndHour) {
                            Text("09:00").tag(9)
                            Text("10:00").tag(10)
                            Text("11:00").tag(11)
                            Text("12:00").tag(12)
                        }
                        .pickerStyle(.segmented)
                        .disabled(settingsManager.isSaving || viewModel.isLoading)
                        .accessibilityLabel("Morning window end time")
                        .accessibilityHint("Selects when the morning measurement window ends")
                        
                        HStack {
                            Image(systemName: "sunrise")
                                .foregroundStyle(.orange)
                            Text("Measures HRV during sleep (00:00-\(String(format: "%02d", settingsManager.morningEndHour)):00)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                    }
                } header: {
                    Text("Measurement Settings")
                } footer: {
                    Text("Ready measures your HRV during sleep to provide consistent morning readiness scores.")
                }
                
                // Baseline Settings
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Baseline Period")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                        
                        Picker("Baseline Period", selection: $settingsManager.baselinePeriod) {
                            Text("7 days").tag(BaselinePeriod.sevenDays)
                            Text("14 days").tag(BaselinePeriod.fourteenDays)
                            Text("30 days").tag(BaselinePeriod.thirtyDays)
                        }
                        .pickerStyle(.segmented)
                        .disabled(settingsManager.isSaving || viewModel.isLoading)
                        .accessibilityLabel("Baseline calculation period")
                        .accessibilityHint("Selects how many days of historical data to use for baseline calculation")
                    }
                    
                    // Baseline status
                    HStack {
                        Image(systemName: viewModel.hasBaselineData ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(viewModel.hasBaselineData ? .green : .orange)
                        Text(viewModel.baselineDataStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                } header: {
                    Text("Baseline Calculation")
                } footer: {
                    Text("The baseline is calculated using your HRV data from the selected period. 7-day baseline is recommended as the research-backed default. Longer periods provide more stability but respond slower to changes.")
                }
                
                // Score Adjustment Settings
                Section {
                    Toggle("RHR Adjustment", isOn: $settingsManager.useRHRAdjustment)
                        .disabled(settingsManager.isSaving || viewModel.isLoading)
                        .accessibilityLabel("Resting heart rate adjustment")
                        .accessibilityHint("When enabled, adjusts readiness score based on resting heart rate")
                    
                    Toggle("Sleep Adjustment", isOn: $settingsManager.useSleepAdjustment)
                        .disabled(settingsManager.isSaving || viewModel.isLoading)
                        .accessibilityLabel("Sleep adjustment")
                        .accessibilityHint("When enabled, adjusts readiness score based on sleep duration")
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
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !settingsManager.hasUnsavedChanges {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if settingsManager.hasUnsavedChanges {
                    HStack(spacing: 16) {
                        Button {
                            showingUnsavedChangesAlert = true
                        } label: {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.gray)
                        .controlSize(.large)
                        
                        Button {
                            do {
                                try settingsManager.saveSettings()
                                // Build change set by comparing persisted before/after
                                let u = UserDefaultsManager.shared
                                var changeTypes: Set<SettingsChangeType> = []
                                if originalBaselinePeriod != u.baselinePeriod { changeTypes.insert(.baselinePeriod) }
                                if originalUseRHR != u.useRHRAdjustment { changeTypes.insert(.rhrAdjustment) }
                                if originalUseSleep != u.useSleepAdjustment { changeTypes.insert(.sleepAdjustment) }
                                if originalMinimumDays != u.minimumDaysForBaseline { changeTypes.insert(.minimumDays) }
                                if originalMorningEndHour != u.morningEndHour { changeTypes.insert(.morningEndHour) }

                                let changes = ReadinessSettingsChange(
                                    types: changeTypes,
                                    previousValues: SettingsValues(
                                        mode: .morning, // Always morning mode now
                                        period: originalBaselinePeriod,
                                        rhrEnabled: originalUseRHR,
                                        sleepEnabled: originalUseSleep,
                                        minimumDays: originalMinimumDays,
                                        morningEndHour: originalMorningEndHour
                                    ),
                                    newValues: SettingsValues(
                                        mode: .morning, // Always morning mode now
                                        period: u.baselinePeriod,
                                        rhrEnabled: u.useRHRAdjustment,
                                        sleepEnabled: u.useSleepAdjustment,
                                        minimumDays: u.minimumDaysForBaseline,
                                        morningEndHour: u.morningEndHour
                                    )
                                )

                                // Auto-recalculate based on change requirements
                                if changes.requiresHistoricalRecalculation {
                                    // Automatically run full historical recalculation
                                    Task { @MainActor in
                                        await viewModel.recalculateAllScores()
                                        await viewModel.loadTodaysReadinessScore()
                                        dismiss()
                                    }
                                } else if changes.requiresCurrentRecalculation {
                                    viewModel.handleSettingsChanges(changes)
                                    dismiss()
                                } else {
                                    dismiss()
                                }
                            } catch {
                                print("❌ Failed to save settings: \(error)")
                            }
                        } label: {
                            Text("Save Changes")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.large)
                        .disabled(settingsManager.isSaving || viewModel.isLoading)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                }
            }
            }
        }
        .sheet(isPresented: $showHealthKitAuth) {
            HealthKitAuthView()
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
            // Refresh settings from UserDefaults to ensure we have the latest values
            settingsManager.refreshFromUserDefaults()
            
            // Capture original persisted settings for change detection
            let u = UserDefaultsManager.shared
            originalBaselinePeriod = u.baselinePeriod
            originalUseRHR = u.useRHRAdjustment
            originalUseSleep = u.useSleepAdjustment
            originalMinimumDays = u.minimumDaysForBaseline
            originalMorningEndHour = u.morningEndHour
            
            print("📋 SETTINGS: Settings view appeared with mode: \(u.readinessMode.rawValue), period: \(u.baselinePeriod.rawValue)")
        }
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
