import SwiftUI

struct SettingsView: View {
    @AppStorage("readinessMode") private var readinessMode: String = "morning"
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
                
                // Health Data Section
                Section {
                    Button(action: {
                        showHealthKitAuth = true
                    }) {
                        HStack {
                            Image(systemName: "heart.text.square")
                                .foregroundStyle(.red)
                            Text("Health Data Access")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("Health Integration")
                } footer: {
                    Text("Review and manage health data permissions used by the app.")
                }
                
                // Notifications Section
                Section {
                    NavigationLink(destination: NotificationSettingsView()) {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundStyle(.blue)
                            Text("Notifications")
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Configure when and how you want to receive readiness updates.")
                }
                
                // App Settings Section
                Section {
                    NavigationLink(destination: AppearanceSettingsView()) {
                        HStack {
                            Image(systemName: "paintbrush")
                                .foregroundStyle(.purple)
                            Text("Appearance")
                        }
                    }
                    
                    NavigationLink(destination: DataManagementView()) {
                        HStack {
                            Image(systemName: "externaldrive")
                                .foregroundStyle(.green)
                            Text("Data Management")
                        }
                    }
                } header: {
                    Text("App Settings")
                }
                
                // About Section
                Section {
                    Link(destination: URL(string: "https://ready.andreroxhage.com/privacy")!) {
                        HStack {
                            Image(systemName: "hand.raised")
                                .foregroundStyle(.gray)
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    Link(destination: URL(string: "https://ready.andreroxhage.com/terms")!) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.gray)
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                                .font(.caption)
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

struct AppearanceSettingsView: View {
    @AppStorage("useSystemAppearance") private var useSystemAppearance = true
    @AppStorage("appAppearance") private var appAppearance = "light"
    @AppStorage("showParticles") private var showParticles = true
    
    var body: some View {
        List {
            Section {
                Toggle("Use System Settings", isOn: $useSystemAppearance)
                
                if !useSystemAppearance {
                    Picker("Appearance", selection: $appAppearance) {
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                Text("Theme")
            }
            
            Section {
                Toggle("Show Score Particles", isOn: $showParticles)
            } header: {
                Text("Visual Effects")
            } footer: {
                Text("Particles show a visual representation of your readiness score.")
            }
        }
        .navigationTitle("Appearance")
    }
}

struct DataManagementView: View {
    @State private var showingExportSheet = false
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        List {
            Section {
                Button(action: {
                    showingExportSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.blue)
                        Text("Export Data")
                    }
                }
                
                Button(action: {
                    // Implement import
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundStyle(.green)
                        Text("Import Data")
                    }
                }
            } header: {
                Text("Data Transfer")
            }
            
            Section {
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                        Text("Delete All Data")
                    }
                }
            } header: {
                Text("Data Removal")
            } footer: {
                Text("This will permanently delete all your readiness scores and settings.")
            }
        }
        .navigationTitle("Data Management")
        .alert("Delete All Data?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                // Implement delete
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
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
                        Text("Open Health Settings")
                            .frame(maxWidth: .infinity)
                    }
                } footer: {
                    Text("You can manage app permissions in the Health app settings.")
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