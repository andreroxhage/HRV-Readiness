import Foundation
import CoreData

class AppearanceService {
    static let shared = AppearanceService()
    
    private let coreDataManager = CoreDataManager.shared
    
    private init() {}
    
    func getAppearanceSettings() -> AppearanceSettings {
        let context = coreDataManager.viewContext
        
        // Try to fetch existing settings
        let fetchRequest: NSFetchRequest<AppearanceSettings> = AppearanceSettings.fetchRequest()
        fetchRequest.fetchLimit = 1
        
        do {
            if let settings = try context.fetch(fetchRequest).first {
                return settings
            }
        } catch {
            print("Error fetching appearance settings: \(error)")
        }
        
        // If no settings exist, create new ones
        let settings = AppearanceSettings(context: context)
        settings.useSystemAppearance = true
        settings.appAppearance = "light"
        settings.showParticles = true
        settings.lastUpdated = Date()
        
        coreDataManager.saveContext()
        return settings
    }
    
    func updateAppearanceSettings(
        useSystemAppearance: Bool? = nil,
        appAppearance: String? = nil,
        showParticles: Bool? = nil
    ) {
        let settings = getAppearanceSettings()
        
        if let useSystemAppearance = useSystemAppearance {
            settings.useSystemAppearance = useSystemAppearance
        }
        
        if let appAppearance = appAppearance {
            settings.appAppearance = appAppearance
        }
        
        if let showParticles = showParticles {
            settings.showParticles = showParticles
        }
        
        settings.lastUpdated = Date()
        coreDataManager.saveContext()
    }
    
    func resetAppearanceSettings() {
        let settings = getAppearanceSettings()
        
        settings.useSystemAppearance = true
        settings.appAppearance = "light"
        settings.showParticles = true
        settings.lastUpdated = Date()
        
        coreDataManager.saveContext()
    }
} 
