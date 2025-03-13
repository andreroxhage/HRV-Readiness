//
//  ContentView.swift
//  Ready 2.0
//
//  Created by André Roxhage on 2025-03-13.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @State private var steps: Double = 0
    @State private var activeEnergy: Double = 0
    @State private var heartRate: Double = 0
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        NavigationView {
            List {
                Section("Today's Activity") {
                    HStack {
                        Image(systemName: "figure.walk")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text("Steps")
                                .font(.headline)
                            Text("\(Int(steps))")
                                .font(.title2)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading) {
                            Text("Active Energy")
                                .font(.headline)
                            Text("\(Int(activeEnergy)) kcal")
                                .font(.title2)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                        VStack(alignment: .leading) {
                            Text("Heart Rate")
                                .font(.headline)
                            Text("\(Int(heartRate)) BPM")
                                .font(.title2)
                        }
                    }
                }
            }
            .navigationTitle("Health Data")
            .refreshable {
                await fetchHealthData()
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") {
                    error = nil
                }
            } message: {
                Text(error?.localizedDescription ?? "Unknown error")
            }
        }
        .task {
            await fetchHealthData()
        }
    }
    
    private func fetchHealthData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch steps
            steps = try await HealthKitManager.shared.fetchSteps()

            // Directly update widget data for steps even if other queries fail
            HealthKitManager.shared.sharedDefaults?.set(steps, forKey: HealthKitManager.StorageKeys.lastSteps)
            HealthKitManager.shared.sharedDefaults?.set(Date(), forKey: HealthKitManager.StorageKeys.lastUpdateTime)

            // Try getting the other data but don't let failures stop us
            do {
                activeEnergy = try await HealthKitManager.shared.fetchActiveEnergy()
                HealthKitManager.shared.sharedDefaults?.set(activeEnergy, forKey: HealthKitManager.StorageKeys.lastActiveEnergy)
            } catch {
                print("Energy data error: \(error)")
                // Keep going
            }

            do {
                heartRate = try await HealthKitManager.shared.fetchHeartRate()
                HealthKitManager.shared.sharedDefaults?.set(heartRate, forKey: HealthKitManager.StorageKeys.lastHeartRate)
            } catch {
                print("Heart rate error: \(error)")
                // Keep going
            }

            error = nil
        } catch {
            self.error = error
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
