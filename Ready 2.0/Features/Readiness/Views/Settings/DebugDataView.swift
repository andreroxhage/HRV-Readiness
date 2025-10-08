import SwiftUI
import CoreData

struct DebugDataView: View {
    @ObservedObject var viewModel: ReadinessViewModel
    @State private var debugData: DebugDataModel = DebugDataModel()
    
    var body: some View {
        List {
            // Current Values Section
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("HRV")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(debugData.currentHRV != 0 ? "\(debugData.currentHRV, specifier: "%.1f") ms" : "Not available")
                            .font(.headline)
                            .foregroundStyle(debugData.currentHRV != 0 ? .primary : .secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("RHR")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(debugData.currentRHR != 0 ? "\(debugData.currentRHR, specifier: "%.1f") bpm" : "Not available")
                            .font(.headline)
                            .foregroundStyle(debugData.currentRHR != 0 ? .primary : .secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Sleep")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(debugData.currentSleep != 0 ? "\(debugData.currentSleep, specifier: "%.1f") h" : "Not available")
                            .font(.headline)
                            .foregroundStyle(debugData.currentSleep != 0 ? .primary : .secondary)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Current Values (Today)")
            }
            
            // Baselines Section
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("HRV Baseline")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(debugData.hrvBaseline != 0 ? "\(debugData.hrvBaseline, specifier: "%.2f") ms" : "Not calculated")
                            .font(.headline)
                            .foregroundStyle(debugData.hrvBaseline != 0 ? .green : .orange)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("from \(debugData.hrvBaselineCount) days")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Deviation: \(debugData.hrvDeviation, specifier: "%.1f")%")
                            .font(.caption)
                            .foregroundStyle(debugData.hrvDeviation > 0 ? .green : .red)
                    }
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("RHR Baseline")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(debugData.rhrBaseline != 0 ? "\(debugData.rhrBaseline, specifier: "%.2f") bpm" : "Not calculated")
                            .font(.headline)
                            .foregroundStyle(debugData.rhrBaseline != 0 ? .green : .orange)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("from \(debugData.rhrBaselineCount) days")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Deviation: \(debugData.rhrDeviation, specifier: "%.1f")%")
                            .font(.caption)
                            .foregroundStyle(debugData.rhrDeviation < 0 ? .green : .red)
                    }
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Sleep Baseline")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(debugData.sleepBaseline != 0 ? "\(debugData.sleepBaseline, specifier: "%.2f") h" : "Not calculated")
                            .font(.headline)
                            .foregroundStyle(debugData.sleepBaseline != 0 ? .green : .orange)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("from \(debugData.sleepBaselineCount) days")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Deviation: \(debugData.sleepDeviation, specifier: "%.1f")%")
                            .font(.caption)
                            .foregroundStyle(debugData.sleepDeviation > 0 ? .green : .red)
                    }
                }
            } header: {
                Text("Baseline Calculations")
            } footer: {
                Text("Baselines are calculated from historical data over the selected period.")
            }
            
            // Score Breakdown Section
            Section {
                VStack(spacing: 12) {
                    HStack {
                        Text("Base Score")
                        Spacer()
                        Text("\(debugData.baseScore, specifier: "%.1f")")
                            .fontWeight(.medium)
                    }
                    
                    if debugData.rhrAdjustment != 0 {
                        HStack {
                            Text("RHR Adjustment")
                            Spacer()
                            Text("\(debugData.rhrAdjustment >= 0 ? "+" : "")\(debugData.rhrAdjustment, specifier: "%.1f")")
                                .foregroundStyle(debugData.rhrAdjustment >= 0 ? .green : .red)
                        }
                    }
                    
                    if debugData.sleepAdjustment != 0 {
                        HStack {
                            Text("Sleep Adjustment")
                            Spacer()
                            Text("\(debugData.sleepAdjustment >= 0 ? "+" : "")\(debugData.sleepAdjustment, specifier: "%.1f")")
                                .foregroundStyle(debugData.sleepAdjustment >= 0 ? .green : .red)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Final Score")
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(debugData.finalScore, specifier: "%.1f")")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                    }
                }
            } header: {
                Text("Score Breakdown")
            }
            
            // Historical Data Section
            Section {
                if debugData.historicalData.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("No historical data available")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(debugData.historicalData.prefix(7), id: \.date) { record in
                        VStack(spacing: 4) {
                            HStack {
                                Text(record.date, style: .date)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(daysAgo(from: record.date)) days ago")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("HRV")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(record.hrv != 0 ? "\(record.hrv, specifier: "%.1f")" : "—")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                Spacer()
                                VStack {
                                    Text("RHR")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(record.rhr != 0 ? "\(record.rhr, specifier: "%.1f")" : "—")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Sleep")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(record.sleep != 0 ? "\(record.sleep, specifier: "%.1f")h" : "—")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                            .padding(.leading, 8)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Recent Historical Data")
            } footer: {
                Text("Shows the last 7 days of recorded metrics used for baseline calculations.")
            }
            
            // Settings Status Section
            Section {
                HStack {
                    Text("RHR Adjustment")
                    Spacer()
                    Text(debugData.rhrEnabled ? "Enabled" : "Disabled")
                        .foregroundStyle(debugData.rhrEnabled ? .green : .secondary)
                }
                
                HStack {
                    Text("Sleep Adjustment")
                    Spacer()
                    Text(debugData.sleepEnabled ? "Enabled" : "Disabled")
                        .foregroundStyle(debugData.sleepEnabled ? .green : .secondary)
                }
                
                HStack {
                    Text("Readiness Mode")
                    Spacer()
                    Text(debugData.readinessMode.capitalized)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Baseline Period")
                    Spacer()
                    Text("\(debugData.baselinePeriod) days")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Current Settings")
            }
            
            // Core Data Status Section
            Section {
                HStack {
                    Text("Health Metrics Records")
                    Spacer()
                    Text("\(debugData.totalHealthMetrics)")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Readiness Score Records")
                    Spacer()
                    Text("\(debugData.totalReadinessScores)")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Last Calculation")
                    Spacer()
                    Text(debugData.lastCalculation != nil ? debugData.lastCalculation!.formatted(date: .abbreviated, time: .shortened) : "Never")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Data Storage")
            }
        }
        .navigationTitle("Debug Data")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadDebugData()
        }
        .refreshable {
            loadDebugData()
        }
    }
    
    private func daysAgo(from date: Date) -> Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
        return days
    }
    
    private func loadDebugData() {
        Task { @MainActor in
            debugData = await DebugDataLoader.loadDebugData(viewModel: viewModel)
        }
    }
}

// MARK: - Debug Data Models

struct DebugDataModel {
    var currentHRV: Double = 0
    var currentRHR: Double = 0
    var currentSleep: Double = 0
    
    var hrvBaseline: Double = 0
    var rhrBaseline: Double = 0
    var sleepBaseline: Double = 0
    
    var hrvBaselineCount: Int = 0
    var rhrBaselineCount: Int = 0
    var sleepBaselineCount: Int = 0
    
    var hrvDeviation: Double = 0
    var rhrDeviation: Double = 0
    var sleepDeviation: Double = 0
    
    var baseScore: Double = 0
    var rhrAdjustment: Double = 0
    var sleepAdjustment: Double = 0
    var finalScore: Double = 0
    
    var historicalData: [HistoricalRecord] = []
    
    var rhrEnabled: Bool = false
    var sleepEnabled: Bool = false
    var readinessMode: String = ""
    var baselinePeriod: Int = 0
    
    var totalHealthMetrics: Int = 0
    var totalReadinessScores: Int = 0
    var lastCalculation: Date?
}

struct HistoricalRecord {
    let date: Date
    let hrv: Double
    let rhr: Double
    let sleep: Double
}

// MARK: - Debug Data Loader

class DebugDataLoader {
    static func loadDebugData(viewModel: ReadinessViewModel) async -> DebugDataModel {
        var debugData = DebugDataModel()
        
        // Load current settings
        let userDefaults = UserDefaults.standard
        debugData.rhrEnabled = userDefaults.bool(forKey: "useRHRAdjustment")
        debugData.sleepEnabled = userDefaults.bool(forKey: "useSleepAdjustment")
        debugData.readinessMode = userDefaults.string(forKey: "readinessMode") ?? "morning"
        debugData.baselinePeriod = userDefaults.integer(forKey: "baselinePeriod")
        debugData.lastCalculation = userDefaults.object(forKey: "lastCalculationTime") as? Date
        
        // Load Core Data counts
        let context = CoreDataManager.shared.viewContext
        
        let healthMetricsRequest: NSFetchRequest<HealthMetrics> = HealthMetrics.fetchRequest()
        debugData.totalHealthMetrics = (try? context.count(for: healthMetricsRequest)) ?? 0
        
        let readinessScoreRequest: NSFetchRequest<ReadinessScore> = ReadinessScore.fetchRequest()
        debugData.totalReadinessScores = (try? context.count(for: readinessScoreRequest)) ?? 0
        
        // Load historical data
        let historicalMetrics = CoreDataManager.shared.getHealthMetricsForPastDays(14)
        debugData.historicalData = historicalMetrics.compactMap { metric in
            guard let date = metric.date else { return nil }
            return HistoricalRecord(
                date: date,
                hrv: metric.hrv,
                rhr: metric.restingHeartRate,
                sleep: metric.sleepHours
            )
        }.sorted { $0.date > $1.date }
        
        // Get today's data
        let today = Calendar.current.startOfDay(for: Date())
        if let todayMetrics = CoreDataManager.shared.getHealthMetricsForDate(today) {
            debugData.currentHRV = todayMetrics.hrv
            debugData.currentRHR = todayMetrics.restingHeartRate
            debugData.currentSleep = todayMetrics.sleepHours
        }
        
        // Calculate baselines using ReadinessService
        let readinessService = viewModel.readinessService
        
        // HRV baseline
        debugData.hrvBaseline = readinessService.calculateHRVBaseline()
        let validHRVData = historicalMetrics.filter { $0.hrv >= 10 && $0.hrv <= 200 }
        debugData.hrvBaselineCount = validHRVData.count
        if debugData.hrvBaseline > 0 && debugData.currentHRV > 0 {
            debugData.hrvDeviation = ((debugData.currentHRV - debugData.hrvBaseline) / debugData.hrvBaseline) * 100
        }
        
        // RHR baseline
        debugData.rhrBaseline = readinessService.calculateRHRBaseline()
        let validRHRData = historicalMetrics.filter { $0.restingHeartRate >= 30 && $0.restingHeartRate <= 120 }
        debugData.rhrBaselineCount = validRHRData.count
        if debugData.rhrBaseline > 0 && debugData.currentRHR > 0 {
            debugData.rhrDeviation = ((debugData.rhrBaseline - debugData.currentRHR) / debugData.rhrBaseline) * 100
        }
        
        // Sleep baseline
        debugData.sleepBaseline = readinessService.calculateSleepBaseline()
        let validSleepData = historicalMetrics.filter { $0.sleepHours > 0 && $0.sleepHours <= 12 }
        debugData.sleepBaselineCount = validSleepData.count
        if debugData.sleepBaseline > 0 && debugData.currentSleep > 0 {
            debugData.sleepDeviation = ((debugData.currentSleep - debugData.sleepBaseline) / debugData.sleepBaseline) * 100
        }
        
        // Get latest readiness score for score breakdown
        if let latestScore = CoreDataManager.shared.getReadinessScoreForDate(today) {
            debugData.finalScore = latestScore.score
            debugData.rhrAdjustment = latestScore.rhrAdjustment
            debugData.sleepAdjustment = latestScore.sleepAdjustment
            debugData.baseScore = debugData.finalScore - debugData.rhrAdjustment - debugData.sleepAdjustment
        }
        
        return debugData
    }
}

#Preview {
    NavigationView {
        DebugDataView(viewModel: ReadinessViewModel())
    }
} 