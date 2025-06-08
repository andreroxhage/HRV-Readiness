import SwiftUI

struct SettingsView: View {
    @AppStorage("readinessMode") private var readinessMode: String = "morning"
    @AppStorage("baselinePeriod") private var baselinePeriod: Int = 7 // FR-2: 7-day rolling baseline default
    @AppStorage("useRHRAdjustment") private var useRHRAdjustment: Bool = false
    @AppStorage("useSleepAdjustment") private var useSleepAdjustment: Bool = false
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ReadinessViewModel
    @State private var showHealthKitAuth = false
    
    var body: some View {
        NavigationView {
            List {
                // Readiness Mode Section
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("HRV Reading Mode")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Picker("Readiness Mode", selection: $readinessMode) {
                            Text("Morning").tag("morning")
                            Text("Rolling").tag("rolling")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: readinessMode) { oldValue, newValue in
                            if oldValue != newValue {
                                viewModel.updateReadinessMode(newValue)
                            }
                        }
                        
                        // Mode description
                        HStack {
                            Image(systemName: readinessMode == "morning" ? "sunrise" : "clock.arrow.circlepath")
                                .foregroundStyle(readinessMode == "morning" ? .orange : .blue)
                                .symbolEffect(.pulse, options: .repeating, value: readinessMode)
                            
                            Text(readinessMode == "morning" ? "Measures HRV during sleep (00:00-10:00)" : "Measures HRV over the last 6 hours")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                        
                        Picker("Baseline Period", selection: $baselinePeriod) {
                            Text("7 days").tag(7)
                            Text("14 days").tag(14)
                            Text("30 days").tag(30)
                        }
                        .pickerStyle(.segmented)
                        .disabled(viewModel.isLoading)
                        .onChange(of: baselinePeriod) { oldValue, newValue in
                            viewModel.updateBaselinePeriod(newValue)
                        }
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
                    Toggle("Resting Heart Rate Adjustment", isOn: $useRHRAdjustment)
                        .disabled(viewModel.isLoading)
                        .onChange(of: useRHRAdjustment) { oldValue, newValue in
                            viewModel.updateRHRAdjustment(newValue)
                        }
                    
                    HStack {
                        Text("Reduces your score when your RHR is elevated")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading)
                    
                    Toggle("Sleep Duration Adjustment", isOn: $useSleepAdjustment)
                        .disabled(viewModel.isLoading)
                        .onChange(of: useSleepAdjustment) { oldValue, newValue in
                            viewModel.updateSleepAdjustment(newValue)
                        }
                    
                    HStack {
                        Text("Reduces your score when sleep is under 6 hours")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading)
                    
                    Button(action: {
                        viewModel.recalculateReadiness()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle")
                            Text("Recalculate Today's Score")
                        }
                    }
                    .disabled(viewModel.isLoading)
                    
                    NavigationLink(destination: AdvancedSettingsView(viewModel: viewModel)) {
                        HStack {
                            Image(systemName: "gearshape.2")
                                .foregroundStyle(.gray)
                            Text("Advanced Settings")
                            Spacer()
                        }
                    }
                } header: {
                    Text("Score Adjustments")
                } footer: {
                    Text("These factors can further adjust your readiness score based on other metrics. Disable them for a score based solely on HRV.")
                }
                
                // Calculation status
                Section {
                    if viewModel.isLoading {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                                .scaleEffect(0.8)
                            Text("Recalculating readiness scores...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundStyle(.gray)
                            Text(viewModel.lastCalculationDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Settings
                Section {
                    NavigationLink(destination: NotificationSettingsView()) {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundStyle(.gray)
                            Text("Notifications")
                            Spacer()
                        }
                    }

                    NavigationLink(destination: AppearanceSettingsView()) {
                        HStack {
                            Image(systemName: "paintbrush")
                                .foregroundStyle(.gray)
                            Text("Appearance")
                            Spacer()
                        }
                    }
                } header: {
                    Text("Settings")
                }

                // Health Data
                Section {
                    Button(action: {
                        showHealthKitAuth = true
                    }) {
                        HStack {
                            Image(systemName: "heart.text.square")
                                .foregroundStyle(.gray)
                            Text("Health Data Access")
                                .foregroundStyle(.primary)
                                .tint(.primary)
                            Spacer()
                        }
                    }
                } header: {
                    Text("Health Data")
                } footer: {
                    Text("Review and manage health data permissions used by the app.")
                }
                
                // About Section
                Section {
                    NavigationLink(destination: PrivacyPolicyView()) {
                        HStack {
                            Image(systemName: "hand.raised")
                                .foregroundStyle(.gray)
                            Text("Privacy Policy")
                            Spacer()
                        }
                    }
                    
                    NavigationLink(destination: TermsOfServiceView()) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.gray)
                            Text("Terms of Service")
                            Spacer()
                        }
                    }
                    
                    Button(action: {
                        // Implement feedback email
                        if let url = URL(string: "mailto:feedback@ready.andreroxhage.com") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundStyle(.gray)
                            Text("Send Feedback")
                        }
                    }
                    
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.gray)
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
                
                // Debug Data Section
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showHealthKitAuth) {
            HealthKitAuthView()
        }
    }
}

// Helper method to convert baseline period int to appropriate type
extension SettingsView {
    func updateBaselinePeriod(_ value: Int) {
        switch value {
        case 7: viewModel.updateBaselinePeriod(.sevenDays)
        case 14: viewModel.updateBaselinePeriod(.fourteenDays)
        case 30: viewModel.updateBaselinePeriod(.thirtyDays)
        default: viewModel.updateBaselinePeriod(.sevenDays)
        }
    }
}

// Placeholder views for navigation links
struct NotificationSettingsView: View {
    var body: some View {
        List {
            Section {
                Toggle("Daily Score Updates", isOn: .constant(true))
                Toggle("Low Readiness Alerts", isOn: .constant(true))
                Toggle("Weekly Reports", isOn: .constant(true))
            }
            
            Section {
                Toggle("Critical HRV Changes", isOn: .constant(true))
                Toggle("Sleep Quality Alerts", isOn: .constant(true))
            } header: {
                Text("Health Alerts")
            }
        }
        .navigationTitle("Notifications")
    }
}

struct HealthKitAuthView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "heart.text.square")
                            .foregroundStyle(.red)
                            .font(.title)
                        Text("Required Health Data")
                            .font(.headline)
                    }
                    .padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HealthDataRow(title: "Heart Rate Variability", description: "Used to calculate your readiness score", isEnabled: true)
                        HealthDataRow(title: "Resting Heart Rate", description: "Helps assess recovery status", isEnabled: true)
                        HealthDataRow(title: "Sleep Analysis", description: "Measures sleep duration and quality", isEnabled: true)
                    }
                } footer: {
                    Text("This data is required for calculating your daily readiness score.")
                }
                
                Section {
                    Button(action: {
                        // Implement opening Health settings
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Open Settings")
                            .frame(maxWidth: .infinity)
                    }
                } footer: {
                    Text("You can manage app permissions in the settings.")
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.title)
                        .fontWeight(.medium)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct HealthDataRow: View {
    let title: String
    let description: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isEnabled ? .green : .red)
        }
    }
}

#Preview {
    SettingsView(viewModel: ReadinessViewModel())
} 
