import Foundation
import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()

    let healthStore = HKHealthStore()

    // Define the types we want to read from HealthKit
    let typesToRead: Set<HKSampleType> = [
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!
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
        static let lastSteps = "lastSteps"
        static let lastActiveEnergy = "lastActiveEnergy"
        static let lastHeartRate = "lastHeartRate"
        static let lastUpdateTime = "lastUpdateTime"
    }

    func updateSharedHealthData() async {
        // Fetch steps - this seems to be working
        do {
            let steps = try await fetchSteps()
            sharedDefaults?.set(steps, forKey: StorageKeys.lastSteps)
        } catch {
            print("Error fetching steps: \(error)")
            // Keep using the old value if there's an error
        }
        
        // Fetch energy - handle separately so one error doesn't prevent the others
        do {
            let energy = try await fetchActiveEnergy()
            sharedDefaults?.set(energy, forKey: StorageKeys.lastActiveEnergy)
        } catch {
            print("Error fetching active energy: \(error)")
            // Keep using the old value
        }
        
        // Fetch heart rate - handle separately
        do {
            let heartRate = try await fetchHeartRate()
            sharedDefaults?.set(heartRate, forKey: StorageKeys.lastHeartRate)
        } catch {
            print("Error fetching heart rate: \(error)")
            // Keep using the old value
        }
        
        // Always update the timestamp
        sharedDefaults?.set(Date(), forKey: StorageKeys.lastUpdateTime)

        // Add after updating the shared defaults
        print("healthkitmanager shared updated")
    }

    public func fetchSteps() async throws -> Double {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: Date()),
            end: Date()
        )

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: steps)
            }
            
            healthStore.execute(query)
        }
    }

    public func fetchActiveEnergy() async throws -> Double {
        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: Date()),
            end: Date()
        )

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
            let query = HKStatisticsQuery(
                quantityType: energyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let energy = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: energy)
            }
            
            healthStore.execute(query)
        }
    }

    public func fetchHeartRate() async throws -> Double {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-3600), // Last hour
            end: Date()
        )

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let heartRate = result?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0
                continuation.resume(returning: heartRate)
            }
            
            healthStore.execute(query)
        }
    }
}
