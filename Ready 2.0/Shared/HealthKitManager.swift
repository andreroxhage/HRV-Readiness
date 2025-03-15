import Foundation
import HealthKit
import WidgetKit

class HealthKitManager {
    static let shared = HealthKitManager()

    let healthStore = HKHealthStore()

    // Define the types we want to read from HealthKit
    let typesToRead: Set<HKSampleType> = [
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    ] as Set<HKSampleType>

    // Define types we want to share with HealthKit (if any)
    let typesToShare: Set<HKSampleType> = [] // Empty for now since we're only reading

    private init() {}

    func requestAuthorization() async throws {
        // Check if HealthKit is available on this device
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        // Request authorization for the health data types
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
        
        // After authorization, enable background delivery
        await enableBackgroundDelivery()
        
        // Setup observers for health data changes
        setupBackgroundObservers()
    }
    
    private func enableBackgroundDelivery() async {
        do {            
            // Enable background delivery for HRV
            if let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
                try await healthStore.enableBackgroundDelivery(for: hrvType, frequency: .immediate)
            }
            
            // Enable background delivery for resting heart rate
            if let restingHRType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
                try await healthStore.enableBackgroundDelivery(for: restingHRType, frequency: .immediate)
            }
            
            // Enable background delivery for sleep analysis
            if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
                try await healthStore.enableBackgroundDelivery(for: sleepType, frequency: .immediate)
            }
            
            print("Background delivery enabled for all health metrics")
        } catch {
            print("Error enabling background delivery: \(error)")
        }
    }

    // Setup background observers for health data updates
    func setupBackgroundObservers() {        
        // New observers for HRV and resting heart rate
        setupObserver(for: .heartRateVariabilitySDNN)
        setupObserver(for: .restingHeartRate)
        
        // Observer for sleep analysis (category type)
        setupSleepObserver()
    }
    
    private func setupObserver(for typeIdentifier: HKQuantityTypeIdentifier) {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: typeIdentifier) else { return }
        
        let query = HKObserverQuery(sampleType: quantityType, predicate: nil) { [weak self] query, completionHandler, error in
            if let error = error {
                print("Error observing \(typeIdentifier): \(error)")
                completionHandler()
                return
            }
            
            // Update the data when changes occur
            Task {
                await self?.updateSharedHealthData()
                // Reload widget timeline when health data changes
                WidgetCenter.shared.reloadTimelines(ofKind: "Widget_2_0")
                completionHandler()
            }
        }
        
        healthStore.execute(query)
    }
    
    private func setupSleepObserver() {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        let query = HKObserverQuery(sampleType: sleepType, predicate: nil) { [weak self] query, completionHandler, error in
            if let error = error {
                print("Error observing sleep analysis: \(error)")
                completionHandler()
                return
            }
            
            // Update the data when changes occur
            Task {
                await self?.updateSharedHealthData()
                // Reload widget timeline when health data changes
                WidgetCenter.shared.reloadTimelines(ofKind: "Widget_2_0")
                completionHandler()
            }
        }
        
        healthStore.execute(query)
    }

    enum HealthKitError: Error {
        case notAvailable
    }
}

// Extension to share data between app and widget
extension HealthKitManager {
    // App Group identifier for sharing data between app and widget
    static let appGroupIdentifier = "group.andreroxhage.Ready-2-0"

    // UserDefaults container for sharing data
    var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: HealthKitManager.appGroupIdentifier)
    }

    // Keys for stored data
    struct StorageKeys {
        static let lastUpdateTime = "lastUpdateTime"
        static let lastHRV = "lastHRV"
        static let lastRestingHeartRate = "lastRestingHeartRate"
        static let lastSleepHours = "lastSleepHours"
        static let sleepQuality = "sleepQuality"
        static let sleepStartTime = "sleepStartTime"
        static let sleepEndTime = "sleepEndTime"
    }

    func updateSharedHealthData() async {
        // Fetch HRV data
        do {
            let hrv = try await fetchHRV()
            sharedDefaults?.set(hrv, forKey: StorageKeys.lastHRV)
        } catch {
            print("Error fetching HRV: \(error)")
            // Keep using the old value
        }
        
        // Fetch resting heart rate
        do {
            let restingHR = try await fetchRestingHeartRate()
            sharedDefaults?.set(restingHR, forKey: StorageKeys.lastRestingHeartRate)
        } catch {
            print("Error fetching resting heart rate: \(error)")
            // Keep using the old value
        }
        
        // Fetch sleep data
        do {
            let sleepData = try await fetchSleepData()
            sharedDefaults?.set(sleepData.hours, forKey: StorageKeys.lastSleepHours)
            sharedDefaults?.set(sleepData.quality, forKey: StorageKeys.sleepQuality)
            sharedDefaults?.set(sleepData.startTime, forKey: StorageKeys.sleepStartTime)
            sharedDefaults?.set(sleepData.endTime, forKey: StorageKeys.sleepEndTime)
        } catch {
            print("Error fetching sleep data: \(error)")
            // Keep using the old value
        }
        
        // After updating all health data, calculate and save readiness score
        do {
            // Get the current readiness mode from UserDefaults
            let userDefaults = UserDefaults.standard
            let modeString = userDefaults.string(forKey: "readinessMode") ?? "morning"
            print("DEBUG: HealthKitManager using readiness mode: \(modeString)")
            
            // Use the ReadinessService to calculate and save the score based on the current mode
            // Note: We're using a direct import approach here since we can't access ReadinessService directly
            // This is a workaround for the dependency issue
            let restingHR = try await fetchRestingHeartRate()
            let sleepData = try await fetchSleepData()
            
            // Save the data to UserDefaults for the app to use
            sharedDefaults?.set(restingHR, forKey: "lastRestingHeartRate")
            sharedDefaults?.set(sleepData.hours, forKey: "lastSleepHours")
            sharedDefaults?.set(sleepData.quality, forKey: "lastSleepQuality")
            sharedDefaults?.set(modeString, forKey: "currentReadinessMode")
            
            // The app will handle the readiness calculation when it launches
            print("Health data updated for readiness calculation with mode: \(modeString)")
        } catch {
            print("Error calculating readiness score: \(error)")
        }
        
        // Always update the timestamp
        sharedDefaults?.set(Date(), forKey: StorageKeys.lastUpdateTime)

        // Add after updating the shared defaults
        print("healthkitmanager shared updated")
    }
    
    public func fetchHRV() async throws -> Double {
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        
        // Get data from the past 7 days
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate
        )

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
            let query = HKStatisticsQuery(
                quantityType: hrvType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let hrv = result?.averageQuantity()?.doubleValue(for: HKUnit.secondUnit(with: .milli)) ?? 0
                continuation.resume(returning: hrv)
            }
            
            healthStore.execute(query)
        }
    }
    
    public func fetchRestingHeartRate() async throws -> Double {
        let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        
        // Get the most recent resting heart rate
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-24 * 3600), // Last 24 hours
            end: Date()
        )

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
            let query = HKStatisticsQuery(
                quantityType: restingHRType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let restingHR = result?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0
                continuation.resume(returning: restingHR)
            }
            
            healthStore.execute(query)
        }
    }
    
    // Sleep data structure
    struct SleepData {
        let hours: Double
        let quality: Int // 0-100 scale
        let startTime: Date?
        let endTime: Date?
    }
    
    public func fetchSleepData() async throws -> SleepData {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        
        // Get sleep data from the past 24 hours
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -1, to: now)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now
        )
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SleepData, Error>) in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: SleepData(hours: 0, quality: 0, startTime: nil, endTime: nil))
                    return
                }
                
                // Filter for asleep samples (not in bed but awake)
                // Use the new API for iOS 16+ and fall back to the old one for older versions
                let asleepSamples = samples.filter { sample in
                    if #available(iOS 16.0, *) {
                        return sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                    } else {
                        // For older iOS versions, use the deprecated value
                        return sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue
                    }
                }
                
                // Calculate total sleep time
                var totalSleepTime: TimeInterval = 0
                var earliestStartTime: Date?
                var latestEndTime: Date?
                
                for sample in asleepSamples {
                    totalSleepTime += sample.endDate.timeIntervalSince(sample.startDate)
                    
                    if earliestStartTime == nil || sample.startDate < earliestStartTime! {
                        earliestStartTime = sample.startDate
                    }
                    
                    if latestEndTime == nil || sample.endDate > latestEndTime! {
                        latestEndTime = sample.endDate
                    }
                }
                
                // Convert to hours
                let sleepHours = totalSleepTime / 3600
                
                // Calculate a simple sleep quality score (0-100)
                // This is a simplified approach - in a real app you might use more factors
                let sleepQuality: Int
                if sleepHours >= 7 && sleepHours <= 9 {
                    sleepQuality = 90 // Optimal sleep duration
                } else if sleepHours >= 6 && sleepHours < 7 {
                    sleepQuality = 70 // Slightly below optimal
                } else if sleepHours > 9 && sleepHours <= 10 {
                    sleepQuality = 80 // Slightly above optimal
                } else if sleepHours < 6 {
                    sleepQuality = Int(min(60, sleepHours * 10)) // Poor sleep
                } else {
                    sleepQuality = 65 // Too much sleep
                }
                
                continuation.resume(returning: SleepData(
                    hours: sleepHours,
                    quality: sleepQuality,
                    startTime: earliestStartTime,
                    endTime: latestEndTime
                ))
            }
            
            healthStore.execute(query)
        }
    }
    
    // Method to fetch HRV data for the past 7 days using HKStatisticsCollectionQuery
    public func fetchHRVForPastWeek() async throws -> [(Date, Double)] {
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        
        // Get data from the past 7 days
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate
        )
        
        // Use day as the interval
        let interval = DateComponents(day: 1)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[(Date, Double)], Error>) in
            let query = HKStatisticsCollectionQuery(
                quantityType: hrvType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage,
                anchorDate: calendar.startOfDay(for: startDate),
                intervalComponents: interval
            )
            
            query.initialResultsHandler = { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let results = results else {
                    continuation.resume(returning: [])
                    return
                }
                
                var hrvValues: [(Date, Double)] = []
                
                results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    if let quantity = statistics.averageQuantity() {
                        let date = statistics.startDate
                        let value = quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                        hrvValues.append((date, value))
                    }
                }
                
                continuation.resume(returning: hrvValues)
            }
            
            healthStore.execute(query)
        }
    }
    
    // Method to fetch resting heart rate for the past 7 days
    public func fetchRestingHeartRateForPastWeek() async throws -> [(Date, Double)] {
        let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        
        // Get data from the past 7 days
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate
        )
        
        // Use day as the interval
        let interval = DateComponents(day: 1)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[(Date, Double)], Error>) in
            let query = HKStatisticsCollectionQuery(
                quantityType: restingHRType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage,
                anchorDate: calendar.startOfDay(for: startDate),
                intervalComponents: interval
            )
            
            query.initialResultsHandler = { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let results = results else {
                    continuation.resume(returning: [])
                    return
                }
                
                var restingHRValues: [(Date, Double)] = []
                
                results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    if let quantity = statistics.averageQuantity() {
                        let date = statistics.startDate
                        let value = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                        restingHRValues.append((date, value))
                    }
                }
                
                continuation.resume(returning: restingHRValues)
            }
            
            healthStore.execute(query)
        }
    }
    
    // Method to fetch sleep data for the past 7 days
    public func fetchSleepDataForPastWeek() async throws -> [(Date, Double)] {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        
        // Get data from the past 7 days
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate
        )
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[(Date, Double)], Error>) in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                // Filter for asleep samples
                // Use the new API for iOS 16+ and fall back to the old one for older versions
                let asleepSamples = samples.filter { sample in
                    if #available(iOS 16.0, *) {
                        return sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                    } else {
                        // For older iOS versions, use the deprecated value
                        return sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue
                    }
                }
                
                // Group samples by day
                var sleepByDay: [Date: TimeInterval] = [:]
                
                for sample in asleepSamples {
                    let day = calendar.startOfDay(for: sample.startDate)
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)
                    
                    if let existingDuration = sleepByDay[day] {
                        sleepByDay[day] = existingDuration + duration
                    } else {
                        sleepByDay[day] = duration
                    }
                }
                
                // Convert to hours and create result array
                let sleepData = sleepByDay.map { (day, duration) in
                    return (day, duration / 3600) // Convert seconds to hours
                }.sorted { $0.0 < $1.0 } // Sort by date
                
                continuation.resume(returning: sleepData)
            }
            
            healthStore.execute(query)
        }
    }

    // Method to fetch HRV data for a specific time range
    public func fetchHRVForTimeRange(startTime: Date, endTime: Date) async throws -> Double {
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startTime,
            end: endTime
        )
        
        print("DEBUG: Fetching HRV for time range: \(startTime) to \(endTime)")

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
            let query = HKStatisticsQuery(
                quantityType: hrvType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, error in
                if let error = error {
                    print("DEBUG: Error fetching HRV: \(error)")
                    continuation.resume(throwing: error)
                    return
                }
                
                if let quantity = result?.averageQuantity() {
                    let hrv = quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    print("DEBUG: Found HRV value: \(hrv) ms")
                    continuation.resume(returning: hrv)
                } else {
                    // No data available for this time range
                    print("DEBUG: No HRV data available for time range: \(startTime) to \(endTime)")
                    continuation.resume(returning: 0)
                }
            }
            
            healthStore.execute(query)
        }
    }
} 
