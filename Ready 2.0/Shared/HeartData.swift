import Foundation

// Make HealthData accessible to both the main app and widget
public struct HealthData {
    public let steps: Int
    public let activeEnergy: Double
    public let heartRate: Double

    public init(steps: Int, activeEnergy: Double, heartRate: Double) {
        self.steps = steps
        self.activeEnergy = activeEnergy
        self.heartRate = heartRate
    }

    public static let preview = HealthData(steps: 8432, activeEnergy: 320.5, heartRate: 72.0)
} 
