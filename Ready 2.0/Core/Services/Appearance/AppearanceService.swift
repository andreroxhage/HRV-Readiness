import Foundation
import CoreData

// AppearanceService
// Responsible for:
// - Managing persistence of appearance settings
// - Abstracting CoreData operations for appearance settings
// - Providing data access methods with proper error handling
// - Not responsible for UI state

class AppearanceService {
    static let shared = AppearanceService()
    
    // MARK: - Dependencies
    
    private let coreDataManager: CoreDataManager
    
    // MARK: - Initialization
    
    init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        self.coreDataManager = coreDataManager
    }
    
    // MARK: - Data Access Methods
    
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
        
        // If no settings exist, create new ones with defaults
        let settings = AppearanceSettings(context: context)
        settings.useSystemAppearance = true
        settings.appAppearance = "light"
        settings.showParticles = true
        settings.lastUpdated = Date()
        
        coreDataManager.saveContext()
        return settings
    }
    
    // MARK: - Data Update Methods
    
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
    
    // MARK: - Utility Methods
    
    func resetAppearanceSettings() {
        let settings = getAppearanceSettings()
        
        settings.useSystemAppearance = true
        settings.appAppearance = "light"
        settings.showParticles = true
        settings.lastUpdated = Date()
        
        coreDataManager.saveContext()
    }
} 
