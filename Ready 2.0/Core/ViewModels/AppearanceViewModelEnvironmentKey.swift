import SwiftUI

// Environment key for AppearanceViewModel
// This allows the appearance settings to be accessed from any view in the app
// through the Environment property wrapper

private struct AppearanceViewModelKey: EnvironmentKey {
    static let defaultValue = AppearanceViewModel()
}

extension EnvironmentValues {
    var appearanceViewModel: AppearanceViewModel {
        get { self[AppearanceViewModelKey.self] }
        set { self[AppearanceViewModelKey.self] = newValue }
    }
} 