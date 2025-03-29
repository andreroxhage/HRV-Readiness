import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(\.appearanceViewModel) private var viewModel
    @Environment(\.dismiss) private var dismiss
    
    // Local state to track changes and ensure UI updates
    @State private var useSystemAppearance: Bool = false
    @State private var appAppearance: String = "light"
    @State private var showParticles: Bool = false
    
    var body: some View {
        List {
            Section {
                Toggle("Use System Settings", isOn: $useSystemAppearance)
                    .onChange(of: useSystemAppearance) { oldValue, newValue in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.useSystemAppearance = newValue
                        }
                    }
                
                if !useSystemAppearance {
                    Picker("Appearance", selection: $appAppearance) {
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: appAppearance) { oldValue, newValue in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.appAppearance = newValue
                        }
                    }
                }
            } header: {
                Text("Theme")
            } footer: {
                Text("Choose between system settings or a custom theme.")
            }
            
            Section {
                Toggle("Show Score Particles", isOn: $showParticles)
                    .onChange(of: showParticles) { oldValue, newValue in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.showParticles = newValue
                        }
                    }
            } header: {
                Text("Visual Effects")
            } footer: {
                Text("Particles show a visual representation of your readiness score.")
            }
            
            Section {
                Button(role: .destructive) {
                    viewModel.resetToDefaults()
                    
                    // Update local state with the new defaults after reset
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        useSystemAppearance = viewModel.useSystemAppearance
                        appAppearance = viewModel.appAppearance
                        showParticles = viewModel.showParticles
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset to Defaults")
                    }
                }
            } footer: {
                Text("Restore all appearance settings to their default values.")
            }
        }
        .navigationTitle("Appearance")
        .preferredColorScheme(viewModel.colorScheme)
        .onAppear {
            // Initialize local state from view model when view appears
            useSystemAppearance = viewModel.useSystemAppearance
            appAppearance = viewModel.appAppearance
            showParticles = viewModel.showParticles
        }
        .onChange(of: viewModel.useSystemAppearance) { oldValue, newValue in
            withAnimation(.easeInOut(duration: 0.2)) {
                useSystemAppearance = newValue
            }
        }
        .onChange(of: viewModel.appAppearance) { oldValue, newValue in
            withAnimation(.easeInOut(duration: 0.2)) {
                appAppearance = newValue
            }
        }
        .onChange(of: viewModel.showParticles) { oldValue, newValue in
            withAnimation(.easeInOut(duration: 0.2)) {
                showParticles = newValue
            }
        }
    }
}

#Preview {
    NavigationView {
        AppearanceSettingsView()
            .environment(\.appearanceViewModel, AppearanceViewModel())
    }
} 