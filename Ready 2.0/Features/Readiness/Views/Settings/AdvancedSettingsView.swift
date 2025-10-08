import SwiftUI

struct AdvancedSettingsView: View {
    @ObservedObject var viewModel: ReadinessViewModel
    @ObservedObject var settingsManager: ReadinessSettingsManager
    @State private var daysToRecalculate: Int = 7
    @State private var isRecalculating: Bool = false
    @State private var showingDatePicker: Bool = false
    @State private var selectedDate: Date = Date()
    @State private var showingErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var errorRecoverySuggestion: String = ""
    
    var body: some View {
        List {
            Section {
                Stepper(value: $settingsManager.minimumDaysForBaseline, in: 1...10) {
                    HStack {
                        Text("Minimum Days for Baseline")
                        Spacer()
                        Text("\(settingsManager.minimumDaysForBaseline) days")
                            .foregroundStyle(.secondary)
                    }
                }
                // Changes are now tracked by ReadinessSettingsManager; user must Save in parent Settings view
            } header: {
                Text("Baseline Calculation")
            } footer: {
                Text("The minimum number of days needed to establish a valid baseline. Lower values allow faster baseline creation but may result in less stable scores.")
            }
            
            Section {
                Picker("Days to Recalculate", selection: $daysToRecalculate) {
                    Text("Last 7 days").tag(7)
                    Text("Last 14 days").tag(14)
                    Text("Last 30 days").tag(30)
                }
                .pickerStyle(.segmented)
                
                 Button(action: {
                    isRecalculating = true
                    viewModel.startRecalculateAllPastScores(days: daysToRecalculate)
                }) {
                    HStack {
                        if viewModel.isLoading && isRecalculating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .padding(.trailing, 5)
                        } else {
                            Image(systemName: "arrow.clockwise.circle")
                        }
                        Text("Recalculate Past \(daysToRecalculate) Days")
                    }
                }
                .disabled(viewModel.isLoading)
                .onChange(of: viewModel.isLoading) {
                    if !viewModel.isLoading {
                        isRecalculating = false
                        
                        // Check if there was an error
                        if let error = viewModel.error {
                            errorMessage = error.errorDescription ?? "An error occurred"
                            errorRecoverySuggestion = error.recoverySuggestion ?? "Please try again."
                            showingErrorAlert = true
                        }
                    }
                }
                
                Button(action: {
                    showingDatePicker = true
                }) {
                    HStack {
                        Image(systemName: "calendar")
                        Text("Recalculate Specific Date")
                    }
                }
                .disabled(viewModel.isLoading)

                Button(action: {
                    viewModel.startHistoricalImportAndBackfill()
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("Re-run Initial Import & Backfill (90 days)")
                    }
                }
                .disabled(viewModel.isLoading)

                if viewModel.isLoading || viewModel.isPerformingInitialSetup {
                    Button(role: .destructive) {
                        viewModel.cancelActiveOperation()
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Cancel Ongoing Operation")
                        }
                    }
                }
                
                if let error = viewModel.error {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Recalculation Issue:")
                            .font(.subheadline.bold())
                            .foregroundStyle(.red)
                        
                        Text(error.errorDescription ?? "An error occurred")
                            .font(.subheadline)
                        
                        if let recovery = error.recoverySuggestion {
                            Text(recovery)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 8)
                }
            } header: {
                Text("Data Recalculation")
            } footer: {
                Text("Recalculate past readiness scores based on health data, or re-run the full 90-day import & backfill. Useful after manual edits in the Health app.")
            }
            
            // Debug Data Section
            Section {
                NavigationLink(destination: DebugDataView(viewModel: viewModel)) {
                    HStack {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .foregroundStyle(.blue)
                        Text("Debug Data & Diagnostics")
                        Spacer()
                    }
                }
            } header: {
                Text("Troubleshooting")
            } footer: {
                Text("View current metric values, baselines, and historical data for troubleshooting and debugging.")
            }

        }
        .navigationTitle("Advanced Settings")
        .sheet(isPresented: $showingDatePicker) {
            NavigationView {
                VStack {
                    DatePicker(
                        "Select Date",
                        selection: $selectedDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                        Text("Recalculating will update this date's readiness score with the latest health data")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        viewModel.recalculateReadinessForDate(selectedDate)
                        showingDatePicker = false
                    }) {
                        Text("Recalculate Selected Date")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding()
                    .disabled(viewModel.isLoading)
                }
                .navigationTitle("Select Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            showingDatePicker = false
                        }
                    }
                }
            }
        }
        .alert(isPresented: $showingErrorAlert) {
            Alert(
                title: Text("Recalculation Issue"),
                message: Text("\(errorMessage)\n\n\(errorRecoverySuggestion)"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

// Placeholder views for diagnostics
struct DataDebugView: View {
    @ObservedObject var viewModel: ReadinessViewModel
    
    var body: some View {
        List {
            Section {
                LabeledContent("Current HRV Baseline", value: String(format: "%.1f ms", viewModel.hrvBaseline))
                LabeledContent("HRV Deviation", value: viewModel.formattedHRVDeviation)
                    .foregroundStyle(viewModel.hrvDeviationColor)
                LabeledContent("RHR Adjustment", value: String(format: "%.1f", viewModel.rhrAdjustment))
                LabeledContent("Sleep Adjustment", value: String(format: "%.1f", viewModel.sleepAdjustment))
                LabeledContent("Raw Score", value: String(format: "%.1f", viewModel.readinessScore))
            } header: {
                Text("Today's Calculation")
            } footer: {
                Text("Raw data used to calculate today's readiness score.")
            }
            
            Section {
                LabeledContent("RHR Adjustment Enabled", value: viewModel.useRHRAdjustment ? "Yes" : "No")
                LabeledContent("Sleep Adjustment Enabled", value: viewModel.useSleepAdjustment ? "Yes" : "No")
                LabeledContent("Baseline Period", value: viewModel.baselinePeriodDescription)
                LabeledContent("Readiness Mode", value: viewModel.readinessModeDescription)
            } header: {
                Text("Settings")
            }
            
            if let error = viewModel.error {
                Section {
                    Text(error.errorDescription ?? "Unknown error")
                        .foregroundStyle(.red)
                    
                    if let recoverySuggestion = error.recoverySuggestion {
                        Text(recoverySuggestion)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                } header: {
                    Text("Current Error")
                }
            }
            
            Section {
                Button("Clear All App Data") {
                    // This should show a confirmation dialog before actually deleting
                }
                .foregroundStyle(.red)
            } footer: {
                Text("This will delete all stored scores and reset to default settings. Use with caution.")
            }
        }
        .navigationTitle("Debug Data")
    }
}

struct BaselineDetailView: View {
    @ObservedObject var viewModel: ReadinessViewModel
    
    var body: some View {
        List {
            Section {
                LabeledContent("Current Period", value: viewModel.baselinePeriodDescription)
                LabeledContent("Minimum Days Required", value: "\(viewModel.readinessService.minimumDaysForBaseline)")
                LabeledContent("Days Available", value: "\(viewModel.pastScores.count)")
                LabeledContent("Baseline Status", value: viewModel.hasBaselineData ? "Established" : "Insufficient Data")
                    .foregroundStyle(viewModel.hasBaselineData ? .green : .orange)
            } header: {
                Text("Baseline Configuration")
            }
            
            if !viewModel.pastScores.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Historical HRV Values")
                            .font(.headline)
                        
                        // Simple line chart would go here
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .overlay(
                                Text("HRV Chart Placeholder")
                                    .foregroundStyle(.secondary)
                            )
                    }
                } header: {
                    Text("Historical Data")
                } footer: {
                    Text("This chart shows your HRV values over time, which are used to calculate your baseline.")
                }
            }
        }
        .navigationTitle("Baseline Details")
    }
}

#Preview {
    NavigationView {
        AdvancedSettingsView(viewModel: ReadinessViewModel(), settingsManager: ReadinessSettingsManager())
    }
}
