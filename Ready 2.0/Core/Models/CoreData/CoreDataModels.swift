import Foundation
import CoreData

// This file serves as a centralized import for CoreData model classes
// It helps prevent import errors and simplifies imports in other files

// Re-export all CoreData model extensions
@_exported import HealthKit

// Typealias to ensure the CoreData models are properly imported
public typealias HealthMetricsEntity = HealthMetrics
public typealias ReadinessScoreEntity = ReadinessScore
public typealias AppearanceSettingsEntity = AppearanceSettings 