import Foundation
import HealthKit

// HealthKitManager
// Responsible for:
// - Managing HealthKit authorization
// - Fetching health data from HealthKit store
// - Processing raw health data into usable formats
// - Not responsible for business logic or UI

@globalActor actor HealthKitManager: @unchecked Sendable {
    static let shared = HealthKitManager()
    
    // MARK: - Properties
    
    private let healthStore = HKHealthStore()
    private let appGroupIdentifier = "group.andreroxhage.Ready-2-0"
    
    // MARK: - Initialization
    
    private init() {
        // Private initializer for singleton
    }
    
    // MARK: - Types
    
    struct SleepData {
        let hours: Double
        let quality: Int
        let startTime: Date?
        let endTime: Date?
    }
    
    enum HealthKitError: Error, LocalizedError {
        case authorizationDenied
        case dataTypeNotAvailable
        case noDataAvailable(metric: String)
        case dataProcessingError(String)
        
        var errorDescription: String? {
            switch self {
            case .authorizationDenied:
                return "HealthKit authorization was denied."
            case .dataTypeNotAvailable:
                return "The requested health data type is not available."
            case .noDataAvailable(let metric):
                return "No \(metric) data available for the specified time range."
            case .dataProcessingError(let message):
                return "Error processing health data: \(message)"
            }
        }
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.dataTypeNotAvailable
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
        
        // Check if authorization was actually granted - we don't throw errors here anymore
        // The app can work with partial permissions
    }
    
    func isAuthorized() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { 
            print("📱 HEALTHKIT: Health data not available on this device")
            return false 
        }
        
        let hrvAuth = healthStore.authorizationStatus(for: HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!)
        let rhrAuth = healthStore.authorizationStatus(for: HKObjectType.quantityType(forIdentifier: .restingHeartRate)!)
        let sleepAuth = healthStore.authorizationStatus(for: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!)
        
        print("🔐 HEALTHKIT: Authorization details:")
        print("   - HRV: \(hrvAuth.rawValue) (\(authStatusString(hrvAuth)))")
        print("   - RHR: \(rhrAuth.rawValue) (\(authStatusString(rhrAuth)))")
        print("   - Sleep: \(sleepAuth.rawValue) (\(authStatusString(sleepAuth)))")
        
        let isFullyAuthorized = hrvAuth == .sharingAuthorized && rhrAuth == .sharingAuthorized && sleepAuth == .sharingAuthorized
        let isHRVAuthorized = hrvAuth == .sharingAuthorized
        
        print("🔐 HEALTHKIT: Full authorization: \(isFullyAuthorized), HRV authorized: \(isHRVAuthorized)")
        
        // For readiness calculation, we mainly need HRV
        return isHRVAuthorized
    }
    
    private func authStatusString(_ status: HKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "notDetermined"
        case .sharingDenied:
            return "sharingDenied"
        case .sharingAuthorized:
            return "sharingAuthorized"
        @unknown default:
            return "unknown"
        }
    }
    
    // MARK: - Data Fetching
    
    func fetchHRV() async throws -> Double {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        return try await fetchHRVForTimeRange(startTime: today, endTime: tomorrow)
    }
    
    func fetchRestingHeartRate() async throws -> Double {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        return try await fetchRestingHeartRateForTimeRange(startTime: today, endTime: tomorrow)
    }
    
    func fetchSleepData() async throws -> SleepData {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        return try await fetchSleepDataForTimeRange(startTime: today, endTime: tomorrow)
    }
    
    // MARK: - Time Range Specific Fetches
    
    func fetchHRVForTimeRange(startTime: Date, endTime: Date) async throws -> Double {
        print("💗 HEALTHKIT: Fetching HRV for time range: \(startTime) to \(endTime)")
        
        // Check authorization status first
        let authStatus = await isAuthorized()
        print("🔐 HEALTHKIT: Authorization status: \(authStatus)")
        
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            print("❌ HEALTHKIT: HRV data type not available")
            throw HealthKitError.dataTypeNotAvailable
        }
        
        let specificAuthStatus = healthStore.authorizationStatus(for: hrvType)
        print("🔐 HEALTHKIT: HRV specific authorization: \(specificAuthStatus.rawValue)")
        
        let predicate = HKQuery.predicateForSamples(withStart: startTime, end: endTime, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    print("❌ HEALTHKIT: HRV query error: \(error.localizedDescription)")
                    continuation.resume(throwing: HealthKitError.dataProcessingError(error.localizedDescription))
                    return
                }
                
                guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else {
                    print("⚠️ HEALTHKIT: No HRV data available for time range")
                    print("🔍 HEALTHKIT: Let's try a broader search to see if any HRV data exists...")
                    
                    // Try searching for HRV data in the past 7 days
                    let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
                    let broadPredicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: Date(), options: .strictStartDate)
                    let broadQuery = HKSampleQuery(
                        sampleType: hrvType,
                        predicate: broadPredicate,
                        limit: 10,
                        sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
                    ) { _, broadSamples, error in
                        if let broadSamples = broadSamples as? [HKQuantitySample] {
                            print("🔍 HEALTHKIT: Found \(broadSamples.count) HRV samples in past 7 days")
                            for (index, sample) in broadSamples.prefix(5).enumerated() {
                                let value = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                                print("   Sample \(index + 1): \(value) ms at \(sample.startDate)")
                            }
                        } else {
                            print("🔍 HEALTHKIT: No HRV data found in past 7 days either")
                        }
                    }
                    Task { self.healthStore.execute(broadQuery) }
                    
                    continuation.resume(throwing: HealthKitError.noDataAvailable(metric: "HRV"))
                    return
                }
                
                print("💗 HEALTHKIT: Found \(quantitySamples.count) HRV samples")
                
                // Get the most recent HRV reading
                if let mostRecent = quantitySamples.first {
                    let hrvValue = mostRecent.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    print("✅ HEALTHKIT: Retrieved HRV value: \(hrvValue) ms at \(mostRecent.startDate)")
                    continuation.resume(returning: hrvValue)
                } else {
                    print("❌ HEALTHKIT: No HRV samples found")
                    continuation.resume(throwing: HealthKitError.noDataAvailable(metric: "HRV"))
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    func fetchRestingHeartRateForTimeRange(startTime: Date, endTime: Date) async throws -> Double {
        print("💓 HEALTHKIT: Fetching RHR for time range: \(startTime) to \(endTime)")
        
        // Check authorization status first
      let authStatus = await isAuthorized()
        print("🔐 HEALTHKIT: Authorization status for RHR fetch: \(authStatus)")
        
        guard let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            print("❌ HEALTHKIT: RHR data type not available")
            throw HealthKitError.dataTypeNotAvailable
        }
        
        let specificAuthStatus = healthStore.authorizationStatus(for: rhrType)
        print("🔐 HEALTHKIT: RHR specific authorization: \(specificAuthStatus.rawValue)")
        
        let predicate = HKQuery.predicateForSamples(withStart: startTime, end: endTime, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: rhrType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    print("❌ HEALTHKIT: RHR query error: \(error.localizedDescription)")
                    continuation.resume(throwing: HealthKitError.dataProcessingError(error.localizedDescription))
                    return
                }
                
                guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else {
                    print("⚠️ HEALTHKIT: No RHR data available for time range")
                    print("🔍 HEALTHKIT: Let's try a broader search for RHR data...")
                    
                    // Try searching for RHR data in the past 7 days
                    let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
                    let broadPredicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: Date(), options: .strictStartDate)
                    let broadQuery = HKSampleQuery(
                        sampleType: rhrType,
                        predicate: broadPredicate,
                        limit: 10,
                        sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
                    ) { _, broadSamples, error in
                        if let broadSamples = broadSamples as? [HKQuantitySample] {
                            print("🔍 HEALTHKIT: Found \(broadSamples.count) RHR samples in past 7 days")
                            for (index, sample) in broadSamples.prefix(5).enumerated() {
                                let value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                                print("   Sample \(index + 1): \(value) bpm at \(sample.startDate)")
                            }
                        } else {
                            print("🔍 HEALTHKIT: No RHR data found in past 7 days either")
                        }
                    }
                    Task { self.healthStore.execute(broadQuery) }
                    
                    continuation.resume(throwing: HealthKitError.noDataAvailable(metric: "Resting Heart Rate"))
                    return
                }
                
                print("💓 HEALTHKIT: Found \(quantitySamples.count) RHR samples")
                
                guard let mostRecent = quantitySamples.first else {
                    print("❌ HEALTHKIT: No RHR samples found")
                    continuation.resume(throwing: HealthKitError.noDataAvailable(metric: "Resting Heart Rate"))
                    return
                }
                
                let rhrValue = mostRecent.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                print("✅ HEALTHKIT: Retrieved RHR value: \(rhrValue) bpm at \(mostRecent.startDate)")
                continuation.resume(returning: rhrValue)
            }
            
            healthStore.execute(query)
        }
    }
    
    func fetchSleepDataForTimeRange(startTime: Date, endTime: Date) async throws -> SleepData {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitError.dataTypeNotAvailable
        }
        
        // Look for sleep data from the night before (sleep data is typically recorded for the previous night)
        let sleepStart = Calendar.current.date(byAdding: .day, value: -1, to: startTime)!
        let predicate = HKQuery.predicateForSamples(withStart: sleepStart, end: endTime, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.dataProcessingError(error.localizedDescription))
                    return
                }
                
                guard let sleepSamples = samples as? [HKCategorySample], !sleepSamples.isEmpty else {
                    continuation.resume(throwing: HealthKitError.noDataAvailable(metric: "Sleep"))
                    return
                }
                
                // Filter for actual sleep (not just in bed)
                let sleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                let actualSleepSamples = sleepSamples.compactMap { $0 }.filter { sleepValues.contains($0.value) }
                
                guard !actualSleepSamples.isEmpty else {
                    continuation.resume(throwing: HealthKitError.noDataAvailable(metric: "Sleep"))
                    return
                }
                
                // Calculate total sleep time
                let totalSleepSeconds = actualSleepSamples.reduce(0) { total, sample in
                    total + sample.endDate.timeIntervalSince(sample.startDate)
                }
                
                let totalSleepHours = totalSleepSeconds / 3600.0
                
                // Calculate sleep quality (simplified: percentage of deep + REM sleep)
                let qualitySleepSamples = sleepSamples.filter { sample in
                    sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                }
                
                let qualitySleepSeconds = qualitySleepSamples.reduce(0) { total, sample in
                    total + sample.endDate.timeIntervalSince(sample.startDate)
                }
                
                let sleepQuality = totalSleepSeconds > 0 ? Int((qualitySleepSeconds / totalSleepSeconds) * 100) : 0
                
                // Get sleep window
                let sleepStart = actualSleepSamples.first?.startDate
                let sleepEnd = actualSleepSamples.last?.endDate
                
                let sleepData = SleepData(
                    hours: totalSleepHours,
                    quality: min(max(sleepQuality, 0), 100), // Clamp between 0-100
                    startTime: sleepStart,
                    endTime: sleepEnd
                )
                
                continuation.resume(returning: sleepData)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Historical Data Import
    
    func importHistoricalData(days: Int = 90, progressCallback: @escaping (Double, String) -> Void) async throws -> [(date: Date, hrv: Double?, rhr: Double?, sleep: SleepData?)] {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!
        
        print("📥 HEALTHKIT: Starting historical data import for \(days) days (from \(startDate) to \(endDate))")
        
        var results: [(date: Date, hrv: Double?, rhr: Double?, sleep: SleepData?)] = []
        
        // Import day by day to provide progress updates
        for dayOffset in 0..<days {
            // Check for cancellation
            if Task.isCancelled {
                print("⚠️ HEALTHKIT: Historical data import cancelled at day \(dayOffset)")
                throw CancellationError()
            }
            
            let currentDate = Calendar.current.date(byAdding: .day, value: -dayOffset, to: endDate)!
            let dayStart = Calendar.current.startOfDay(for: currentDate)
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
            
            let progress = Double(dayOffset) / Double(days)
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            progressCallback(progress, "Importing data for \(dateFormatter.string(from: currentDate))")
            
            // Fetch data for this day (with error handling)
            let hrvValue = try? await fetchHRVForTimeRange(startTime: dayStart, endTime: dayEnd)
            let rhrValue = try? await fetchRestingHeartRateForTimeRange(startTime: dayStart, endTime: dayEnd)
            let sleepValue = try? await fetchSleepDataForTimeRange(startTime: dayStart, endTime: dayEnd)
            
            // Log what we found for this day
            if hrvValue != nil || rhrValue != nil || sleepValue != nil {
                print("📊 HEALTHKIT: Day \(dateFormatter.string(from: currentDate)) - HRV: \(hrvValue?.description ?? "nil"), RHR: \(rhrValue?.description ?? "nil"), Sleep: \(sleepValue?.hours.description ?? "nil")h")
            }
            
            results.append((date: dayStart, hrv: hrvValue, rhr: rhrValue, sleep: sleepValue))
            
            // Small delay to prevent overwhelming HealthKit
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }
        
        let validDataCount = results.filter { $0.hrv != nil || $0.rhr != nil || $0.sleep != nil }.count
        print("📥 HEALTHKIT: Historical data import complete - Found data for \(validDataCount) out of \(days) days")
        
        progressCallback(1.0, "Historical data import complete")
        return results.reversed() // Return in chronological order
    }
    
    // MARK: - Background Delivery
    
    func enableBackgroundDelivery() async throws {
        print("🔄 HEALTHKIT: Enabling background delivery for health data types")
        
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
              let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate),
              let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitError.dataTypeNotAvailable
        }
        
        // Enable background delivery for each data type
        try await enableBackgroundDelivery(for: hrvType, frequency: .daily, identifier: "HRV")
        try await enableBackgroundDelivery(for: rhrType, frequency: .daily, identifier: "RHR")
        try await enableBackgroundDelivery(for: sleepType, frequency: .daily, identifier: "Sleep")
        
        print("✅ HEALTHKIT: Background delivery enabled for all data types")
    }
    
    private func enableBackgroundDelivery(for type: HKObjectType, frequency: HKUpdateFrequency, identifier: String) async throws {
        print("🔄 HEALTHKIT: Enabling background delivery for \(identifier)")
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.enableBackgroundDelivery(for: type, frequency: frequency) { success, error in
                if let error = error {
                    print("❌ HEALTHKIT: Failed to enable background delivery for \(identifier): \(error)")
                    continuation.resume(throwing: error)
                } else {
                    print("✅ HEALTHKIT: Successfully enabled background delivery for \(identifier)")
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    func disableBackgroundDelivery() async throws {
        print("🔄 HEALTHKIT: Disabling background delivery for health data types")
        
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
              let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate),
              let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitError.dataTypeNotAvailable
        }
        
        try await disableBackgroundDelivery(for: hrvType, identifier: "HRV")
        try await disableBackgroundDelivery(for: rhrType, identifier: "RHR")
        try await disableBackgroundDelivery(for: sleepType, identifier: "Sleep")
        
        print("✅ HEALTHKIT: Background delivery disabled for all data types")
    }
    
    private func disableBackgroundDelivery(for type: HKObjectType, identifier: String) async throws {
        print("🔄 HEALTHKIT: Disabling background delivery for \(identifier)")
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.disableBackgroundDelivery(for: type) { success, error in
                if let error = error {
                    print("❌ HEALTHKIT: Failed to disable background delivery for \(identifier): \(error)")
                    continuation.resume(throwing: error)
                } else {
                    print("✅ HEALTHKIT: Successfully disabled background delivery for \(identifier)")
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    // MARK: - Widget Data Sharing
    
    var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupIdentifier)
    }
    
    func updateSharedHealthData() async {
        guard let sharedDefaults = sharedDefaults else { return }
        
        do {
            // Fetch latest data
            let hrv = try await fetchHRV()
            let rhr = try await fetchRestingHeartRate()
            let sleep = try await fetchSleepData()
            
            // Store in shared UserDefaults for widget access
            sharedDefaults.set(hrv, forKey: "latestHRV")
            sharedDefaults.set(rhr, forKey: "latestRHR")
            sharedDefaults.set(sleep.hours, forKey: "latestSleepHours")
            sharedDefaults.set(sleep.quality, forKey: "latestSleepQuality")
            sharedDefaults.set(Date(), forKey: "lastHealthDataUpdate")
            
        } catch {
            // Store error state for widget
            sharedDefaults.set(true, forKey: "healthDataError")
            sharedDefaults.set(error.localizedDescription, forKey: "healthDataErrorMessage")
        }
    }
} 
