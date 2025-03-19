import Foundation

extension UserDefaults {
    /// Check if a key exists in UserDefaults
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}
