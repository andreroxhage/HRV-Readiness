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
    
    // Create a new background context for bulk operations
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
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
    
    // Save a specific context (for background contexts)
    func saveContext(_ context: NSManagedObjectContext) {
        context.performAndWait {
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    let nserror = error as NSError
                    print("Unresolved error \(nserror), \(nserror.userInfo)")
                }
            }
        }
    }
    
    // MARK: - Health Metrics Operations
    
    func saveHealthMetrics(date: Date, hrv: Double, restingHeartRate: Double, sleepHours: Double, sleepQuality: Int) -> HealthMetrics {
        print("💾 COREDATA: saveHealthMetrics called for date: \(date)")
        print("💾 COREDATA: Values - HRV: \(hrv), RHR: \(restingHeartRate), Sleep: \(sleepHours)h")
        
        let context = viewContext
        var result: HealthMetrics!
        
        context.performAndWait {
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
                result = existingMetrics
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
                result = healthMetrics
            }
        }
        
        saveContext()
        return result
    }
    
    // Background-safe version for bulk imports
    func saveHealthMetricsInBackground(context: NSManagedObjectContext, date: Date, hrv: Double, restingHeartRate: Double, sleepHours: Double, sleepQuality: Int) -> HealthMetrics {
        var result: HealthMetrics!
        context.performAndWait {
            // Check if we already have metrics for this date in this context
            let calendar = Calendar.current
            let startDate = calendar.startOfDay(for: date)
            let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
            
            let fetchRequest: NSFetchRequest<HealthMetrics> = HealthMetrics.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate)
            fetchRequest.fetchLimit = 1
            
            if let existing = try? context.fetch(fetchRequest).first {
                // Update existing
                existing.hrv = hrv
                existing.restingHeartRate = restingHeartRate
                existing.sleepHours = sleepHours
                existing.sleepQuality = Int16(sleepQuality)
                result = existing
            } else {
                // Create new
                let metrics = HealthMetrics(context: context)
                metrics.date = date
                metrics.hrv = hrv
                metrics.restingHeartRate = restingHeartRate
                metrics.sleepHours = sleepHours
                metrics.sleepQuality = Int16(sleepQuality)
                result = metrics
            }
        }
        return result
    }
    
    func getHealthMetricsForDate(_ date: Date) -> HealthMetrics? {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        
        let fetchRequest: NSFetchRequest<HealthMetrics> = HealthMetrics.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate)
        fetchRequest.fetchLimit = 1
        
        var result: HealthMetrics?
        viewContext.performAndWait {
            do {
                let results = try viewContext.fetch(fetchRequest)
                result = results.first
            } catch {
                print("Error fetching health metrics for date \(date): \(error)")
                result = nil
            }
        }
        return result
    }
    
    func getHealthMetricsForPastDays(_ days: Int) -> [HealthMetrics] {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date().addingTimeInterval(86400)) // Tomorrow at midnight
        let requestedStart = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: Date()))!
        let cutoff = Date().addingTimeInterval(-365 * 24 * 3600)
        let startDate = max(requestedStart, cutoff)
        
        let fetchRequest: NSFetchRequest<HealthMetrics> = HealthMetrics.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        var result: [HealthMetrics] = []
        viewContext.performAndWait {
            do {
                result = try viewContext.fetch(fetchRequest)
            } catch {
                print("Error fetching health metrics for past \(days) days: \(error)")
                result = []
            }
        }
        return result
    }
    
    // Fetch HealthMetrics within a specific date interval [startDate, endDate)
    func getHealthMetrics(from startDate: Date, to endDate: Date) -> [HealthMetrics] {
        let cutoff = Date().addingTimeInterval(-365 * 24 * 3600)
        let clampedStart = max(startDate, cutoff)
        let fetchRequest: NSFetchRequest<HealthMetrics> = HealthMetrics.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", clampedStart as NSDate, endDate as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        var result: [HealthMetrics] = []
        viewContext.performAndWait {
            do {
                result = try viewContext.fetch(fetchRequest)
            } catch {
                print("Error fetching health metrics between dates: \(error)")
                result = []
            }
        }
        return result
    }
    
    // MARK: - Readiness Score Operations
    
    func saveReadinessScore(date: Date, score: Double, hrvBaseline: Double, hrvDeviation: Double, readinessCategory: String, rhrAdjustment: Double, sleepAdjustment: Double, readinessMode: String, baselinePeriod: Int, healthMetrics: HealthMetrics) -> ReadinessScore {
        let context = viewContext
        var result: ReadinessScore!
        
        context.performAndWait {
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
            
            result = readinessScore
        }
        
        saveContext()
        return result
    }
    
    // Background-safe version for bulk imports
    func saveReadinessScoreInBackground(context: NSManagedObjectContext, date: Date, score: Double, hrvBaseline: Double, hrvDeviation: Double, readinessCategory: String, rhrAdjustment: Double, sleepAdjustment: Double, readinessMode: String, baselinePeriod: Int, healthMetrics: HealthMetrics) -> ReadinessScore {
        var result: ReadinessScore!
        context.performAndWait {
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
            
            result = readinessScore
        }
        return result
    }
    
    func getReadinessScoreForDate(_ date: Date) -> ReadinessScore? {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        
        let fetchRequest: NSFetchRequest<ReadinessScore> = ReadinessScore.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate)
        fetchRequest.fetchLimit = 1
        
        var result: ReadinessScore?
        viewContext.performAndWait {
            do {
                let results = try viewContext.fetch(fetchRequest)
                result = results.first
            } catch {
                print("Error fetching readiness score for date \(date): \(error)")
                result = nil
            }
        }
        return result
    }
    
    func getReadinessScoresForPastDays(_ days: Int) -> [ReadinessScore] {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date().addingTimeInterval(86400)) // Tomorrow at midnight
        let requestedStart = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: Date()))!
        let cutoff = Date().addingTimeInterval(-365 * 24 * 3600)
        let startDate = max(requestedStart, cutoff)
        
        let fetchRequest: NSFetchRequest<ReadinessScore> = ReadinessScore.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        var result: [ReadinessScore] = []
        viewContext.performAndWait {
            do {
                result = try viewContext.fetch(fetchRequest)
            } catch {
                print("Error fetching readiness scores for past \(days) days: \(error)")
                result = []
            }
        }
        return result
    }

    // MARK: - Retention Cleanup (delete records older than N days)
    func cleanupDataOlderThan(days: Int) {
        let cutoff = Date().addingTimeInterval(-Double(days) * 24 * 3600)
        let context = viewContext

        context.performAndWait {
            // HealthMetrics
            do {
                let req: NSFetchRequest<HealthMetrics> = HealthMetrics.fetchRequest()
                req.predicate = NSPredicate(format: "date < %@", cutoff as NSDate)
                let oldMetrics = try context.fetch(req)
                for m in oldMetrics { context.delete(m) }
                if !oldMetrics.isEmpty { print("🧹 COREDATA: Deleted \(oldMetrics.count) HealthMetrics older than \(days)d") }
            } catch {
                print("❌ COREDATA: Failed to fetch old HealthMetrics: \(error)")
            }

            // ReadinessScore
            do {
                let req: NSFetchRequest<ReadinessScore> = ReadinessScore.fetchRequest()
                req.predicate = NSPredicate(format: "date < %@", cutoff as NSDate)
                let oldScores = try context.fetch(req)
                for s in oldScores { context.delete(s) }
                if !oldScores.isEmpty { print("🧹 COREDATA: Deleted \(oldScores.count) ReadinessScore older than \(days)d") }
            } catch {
                print("❌ COREDATA: Failed to fetch old ReadinessScore: \(error)")
            }
        }

        saveContext()
    }
    
    // MARK: - Data Cleanup Methods
    
    func cleanupDuplicateHealthMetrics() {
        print("🧹 COREDATA: Starting cleanup of duplicate health metrics...")
        
        let context = viewContext
        let fetchRequest: NSFetchRequest<HealthMetrics> = HealthMetrics.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        context.performAndWait {
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
                } else {
                    print("🧹 COREDATA: No duplicates found to delete")
                }
                
            } catch {
                print("❌ COREDATA: Error during cleanup: \(error)")
            }
        }
        
        saveContext()
    }
} 
