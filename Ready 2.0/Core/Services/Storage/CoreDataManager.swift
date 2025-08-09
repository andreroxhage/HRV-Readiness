import CoreData
import Foundation

// CoreDataManager
// Responsible for:
// - Managing the Core Data stack
// - Providing low-level data access methods
// - Handling save operations and errors
// - Not responsible for business logic or feature-specific operations

class CoreDataManager {
    static let shared = CoreDataManager()
    
    // MARK: - Initialization
    
    private init() {
        // Private initializer to ensure singleton pattern
    }
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ReadyDataModel")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                print("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    // MARK: - Health Metrics Operations
    
    func saveHealthMetrics(date: Date, hrv: Double, restingHeartRate: Double, sleepHours: Double, sleepQuality: Int) -> HealthMetrics {
        print("💾 COREDATA: saveHealthMetrics called for date: \(date)")
        print("💾 COREDATA: Values - HRV: \(hrv), RHR: \(restingHeartRate), Sleep: \(sleepHours)h")
        
        let context = viewContext
        
        // Check if we already have metrics for this date
        if let existingMetrics = getHealthMetricsForDate(date) {
            print("💾 COREDATA: Found existing health metrics for \(date) - updating instead of creating duplicate")
            print("💾 COREDATA: Old values - HRV: \(existingMetrics.hrv), RHR: \(existingMetrics.restingHeartRate), Sleep: \(existingMetrics.sleepHours)h")
            
            // Update existing record
            existingMetrics.hrv = hrv
            existingMetrics.restingHeartRate = restingHeartRate
            existingMetrics.sleepHours = sleepHours
            existingMetrics.sleepQuality = Int16(sleepQuality)
            
            print("💾 COREDATA: Updated existing record with new values")
            saveContext()
            return existingMetrics
        } else {
            print("💾 COREDATA: No existing metrics found for \(date) - creating new record")
            
            // Create new record
            let healthMetrics = HealthMetrics(context: context)
            
            healthMetrics.date = date
            healthMetrics.hrv = hrv
            healthMetrics.restingHeartRate = restingHeartRate
            healthMetrics.sleepHours = sleepHours
            healthMetrics.sleepQuality = Int16(sleepQuality)
     
            print("💾 COREDATA: Created new health metrics record")
            saveContext()
            return healthMetrics
        }
    }
    
    func getHealthMetricsForDate(_ date: Date) -> HealthMetrics? {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        
        let fetchRequest: NSFetchRequest<HealthMetrics> = HealthMetrics.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            return results.first
        } catch {
            print("Error fetching health metrics for date \(date): \(error)")
            return nil
        }
    }
    
    func getHealthMetricsForPastDays(_ days: Int) -> [HealthMetrics] {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date().addingTimeInterval(86400)) // Tomorrow at midnight
        let startDate = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: Date()))!
        
        let fetchRequest: NSFetchRequest<HealthMetrics> = HealthMetrics.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching health metrics for past \(days) days: \(error)")
            return []
        }
    }
    
    // Fetch HealthMetrics within a specific date interval [startDate, endDate)
    func getHealthMetrics(from startDate: Date, to endDate: Date) -> [HealthMetrics] {
        let fetchRequest: NSFetchRequest<HealthMetrics> = HealthMetrics.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching health metrics between dates: \(error)")
            return []
        }
    }
    
    // MARK: - Readiness Score Operations
    
    func saveReadinessScore(date: Date, score: Double, hrvBaseline: Double, hrvDeviation: Double, readinessCategory: String, rhrAdjustment: Double, sleepAdjustment: Double, readinessMode: String, baselinePeriod: Int, healthMetrics: HealthMetrics) -> ReadinessScore {
        let context = viewContext
        let readinessScore = ReadinessScore(context: context)
        
        readinessScore.date = date
        readinessScore.score = score
        readinessScore.hrvBaseline = hrvBaseline
        readinessScore.hrvDeviation = hrvDeviation
        readinessScore.readinessCategory = readinessCategory
        readinessScore.rhrAdjustment = rhrAdjustment
        readinessScore.sleepAdjustment = sleepAdjustment
        readinessScore.readinessMode = readinessMode
        readinessScore.baselinePeriod = Int16(baselinePeriod)
        readinessScore.calculationTimestamp = Date()
        readinessScore.healthMetrics = healthMetrics
        
        saveContext()
        return readinessScore
    }
    
    func getReadinessScoreForDate(_ date: Date) -> ReadinessScore? {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        
        let fetchRequest: NSFetchRequest<ReadinessScore> = ReadinessScore.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            return results.first
        } catch {
            print("Error fetching readiness score for date \(date): \(error)")
            return nil
        }
    }
    
    func getReadinessScoresForPastDays(_ days: Int) -> [ReadinessScore] {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date().addingTimeInterval(86400)) // Tomorrow at midnight
        let startDate = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: Date()))!
        
        let fetchRequest: NSFetchRequest<ReadinessScore> = ReadinessScore.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching readiness scores for past \(days) days: \(error)")
            return []
        }
    }
    
    // MARK: - Data Cleanup Methods
    
    func cleanupDuplicateHealthMetrics() {
        print("🧹 COREDATA: Starting cleanup of duplicate health metrics...")
        
        let context = viewContext
        let fetchRequest: NSFetchRequest<HealthMetrics> = HealthMetrics.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        do {
            let allMetrics = try context.fetch(fetchRequest)
            print("🧹 COREDATA: Found \(allMetrics.count) health metric records")
            
            // Group by date (using date components to ignore time)
            var dateGroups: [String: [HealthMetrics]] = [:]
            let calendar = Calendar.current
            
            for metric in allMetrics {
                if let date = metric.date {
                    let dateString = calendar.startOfDay(for: date).description
                    if dateGroups[dateString] == nil {
                        dateGroups[dateString] = []
                    }
                    dateGroups[dateString]?.append(metric)
                }
            }
            
            print("🧹 COREDATA: Found \(dateGroups.count) unique date groups")
            
            // Remove duplicates - keep the most recent record for each date
            var deletedCount = 0
            for (dateString, metrics) in dateGroups {
                if metrics.count > 1 {
                    print("🧹 COREDATA: Date \(dateString) has \(metrics.count) duplicates")
                    
                    // Sort by creation time and keep the last one
                    let sortedMetrics = metrics.sorted { first, second in
                        // Use object ID as a proxy for creation order
                        return first.objectID.uriRepresentation().absoluteString < second.objectID.uriRepresentation().absoluteString
                    }
                    
                    // Delete all but the last one
                    for i in 0..<(sortedMetrics.count - 1) {
                        context.delete(sortedMetrics[i])
                        deletedCount += 1
                    }
                }
            }
            
            if deletedCount > 0 {
                print("🧹 COREDATA: Deleted \(deletedCount) duplicate records")
                saveContext()
            } else {
                print("🧹 COREDATA: No duplicates found to delete")
            }
            
        } catch {
            print("❌ COREDATA: Error during cleanup: \(error)")
        }
    }
} 
