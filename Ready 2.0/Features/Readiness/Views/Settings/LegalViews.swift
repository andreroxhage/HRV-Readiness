import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("Privacy Policy")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Last Updated: \(formattedCurrentDate())")
                        .foregroundStyle(.secondary)
                    
                    LegalSection(title: "1. Information We Collect", content: """
                        1.1. Health Data
                        • Heart Rate Variability (HRV)
                        • Resting Heart Rate
                        • Sleep Analysis Data
                        
                        This data is collected through Apple HealthKit and is used solely for calculating your readiness score and providing health insights.
                        
                        1.2. User-Provided Information
                        • App preferences and settings
                        """)
                    
                    LegalSection(title: "2. Data Usage & Storage", content: """
                        2.1. Your health data remains on your device and is never transmitted to our servers.
                        
                        2.2. We utilize Apple's HealthKit framework in accordance with Apple's guidelines and privacy standards.
                        
                        2.3. Your preferences are stored locally using Apple's UserDefaults system.
                        """)
                    
                    LegalSection(title: "3. Data Protection", content: """
                        3.1. We implement industry-standard security measures to protect your data.
                        
                        3.2. We do not sell, trade, or transfer your personal information to third parties.
                        
                        3.3. All health data processing occurs locally on your device.
                        """)
                }
                
                Group {
                    LegalSection(title: "4. Your Rights", content: """
                        4.1. You have the right to:
                        • Access your data through the Health app
                        • Modify health data permissions
                        • Delete your data from the Health app
                        
                        4.2. You can manage app permissions through your device settings.
                        """)
                    
                    LegalSection(title: "5. Contact", content: """
                        For privacy-related inquiries, contact us at:
                        ready@andreroxhage.com
                        """)
                }
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("Terms of Service")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Last Updated: \(formattedCurrentDate())")
                        .foregroundStyle(.secondary)
                    
                    LegalSection(title: "1. Acceptance of Terms", content: """
                        By accessing or using Ready, you agree to be bound by these Terms of Service and all applicable laws and regulations.
                        """)
                    
                    LegalSection(title: "2. Health Data Usage", content: """
                        2.1. The app uses Apple HealthKit to access and process your health data.
                        
                        2.2. You acknowledge that:
                        • The app is not a medical device
                        • The app's insights are not medical advice
                        • Consult healthcare professionals for medical decisions
                        """)
                    
                    LegalSection(title: "3. User Responsibilities", content: """
                        3.1. You are responsible for:
                        • Maintaining accurate health data
                        • Keeping your device secure
                        • Using the app as intended
                        
                        3.2. You agree not to:
                        • Modify or reverse engineer the app
                        • Use the app for unauthorized purposes
                        • Circumvent any app limitations
                        """)
                }
                
                Group {
                    LegalSection(title: "4. Limitation of Liability", content: """
                        4.1. The app is provided "as is" without warranties of any kind.
                        
                        4.2. We are not liable for:
                        • Data accuracy issues
                        • Service interruptions
                        • Decisions made based on app insights
                        """)
                    
                    LegalSection(title: "5. Changes to Terms", content: """
                        We reserve the right to modify these terms at any time. Continued use of the app constitutes acceptance of modified terms.
                        """)
                    
                    LegalSection(title: "6. Contact", content: """
                        For legal inquiries, contact us at:
                        ready@andreroxhage.com
                        """)
                }
            }
            .padding()
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LegalSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
        }
    }
}

private func formattedCurrentDate() -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    return formatter.string(from: Date())
}

#Preview {
    NavigationView {
        PrivacyPolicyView()
    }
} 