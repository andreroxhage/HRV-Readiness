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
        let context = viewContext
        let healthMetrics = HealthMetrics(context: context)
        
        healthMetrics.date = date
        healthMetrics.hrv = hrv
        healthMetrics.restingHeartRate = restingHeartRate
        healthMetrics.sleepHours = sleepHours
        healthMetrics.sleepQuality = Int16(sleepQuality)
 
        saveContext()
        return healthMetrics
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
} 