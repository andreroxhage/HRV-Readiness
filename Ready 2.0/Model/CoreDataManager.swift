import CoreData
import Foundation

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {
        // Private initializer to ensure singleton pattern
    }
    
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
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        
        print("DEBUG: Fetching health metrics for date: \(formatter.string(from: date))")
        print("DEBUG: Date range: \(formatter.string(from: startOfDay)) to \(formatter.string(from: endOfDay))")
        
        let fetchRequest: NSFetchRequest<HealthMetrics> = HealthMetrics.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            
            if results.isEmpty {
                print("DEBUG: No health metrics found for date: \(formatter.string(from: date))")
                return nil
            } else if results.count > 1 {
                print("DEBUG: WARNING - Found multiple (\(results.count)) health metrics for date: \(formatter.string(from: date))")
                
                // Print details of all found metrics
                formatter.timeStyle = .short
                for (index, metric) in results.enumerated() {
                    if let metricDate = metric.date {
                        print("DEBUG: Metric \(index+1): Date=\(formatter.string(from: metricDate)), HRV=\(metric.hrv), RHR=\(metric.restingHeartRate)")
                    }
                }
                
                // Return the most recent one
                return results.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }.first
            } else {
                let metric = results.first!
                if let metricDate = metric.date {
                    formatter.timeStyle = .short
                    print("DEBUG: Found health metric: Date=\(formatter.string(from: metricDate)), HRV=\(metric.hrv), RHR=\(metric.restingHeartRate)")
                }
                return metric
            }
        } catch {
            print("DEBUG: Error fetching health metrics: \(error)")
            return nil
        }
    }
    
    func getHealthMetricsForPastDays(_ days: Int) -> [HealthMetrics] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: endDate))!
        
        print("DEBUG: Fetching health metrics from \(startDate) to \(endDate)")
        
        let fetchRequest: NSFetchRequest<HealthMetrics> = HealthMetrics.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@", startDate as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            print("DEBUG: Found \(results.count) health metrics")
            
            // Print the first few results for debugging
            if !results.isEmpty {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                
                for (index, metric) in results.prefix(3).enumerated() {
                    if let date = metric.date {
                        print("DEBUG: Metric \(index): Date=\(formatter.string(from: date)), HRV=\(metric.hrv), RHR=\(metric.restingHeartRate)")
                    }
                }
            }
            
            return results
        } catch {
            print("DEBUG: Error fetching health metrics: \(error)")
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
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        
        print("DEBUG: Fetching readiness score for date: \(formatter.string(from: date))")
        print("DEBUG: Date range: \(formatter.string(from: startOfDay)) to \(formatter.string(from: endOfDay))")
        
        let fetchRequest: NSFetchRequest<ReadinessScore> = ReadinessScore.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            
            if results.isEmpty {
                print("DEBUG: No readiness score found for date: \(formatter.string(from: date))")
                return nil
            } else if results.count > 1 {
                print("DEBUG: WARNING - Found multiple (\(results.count)) readiness scores for date: \(formatter.string(from: date))")
                
                // Print details of all found scores
                formatter.timeStyle = .short
                for (index, score) in results.enumerated() {
                    if let scoreDate = score.date {
                        print("DEBUG: Score \(index+1): Date=\(formatter.string(from: scoreDate)), Score=\(score.score), Mode=\(score.readinessMode ?? "unknown")")
                    }
                }
                
                // Return the most recent one
                return results.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }.first
            } else {
                let score = results.first!
                if let scoreDate = score.date {
                    formatter.timeStyle = .short
                    print("DEBUG: Found readiness score: Date=\(formatter.string(from: scoreDate)), Score=\(score.score), Mode=\(score.readinessMode ?? "unknown")")
                }
                return score
            }
        } catch {
            print("DEBUG: Error fetching readiness score: \(error)")
            return nil
        }
    }
    
    func getReadinessScoresForPastDays(_ days: Int) -> [ReadinessScore] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: endDate))!
        
        let fetchRequest: NSFetchRequest<ReadinessScore> = ReadinessScore.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@", startDate as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching readiness scores: \(error)")
            return []
        }
    }
} 
