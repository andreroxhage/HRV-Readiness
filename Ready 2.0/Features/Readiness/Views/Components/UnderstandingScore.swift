import SwiftUI

struct UnderstandingScore: View {
    @ObservedObject var viewModel: ReadinessViewModel
    @State private var showingInfoOverlay = false
    @State private var showingDisclaimer = false
    @Namespace private var animation
    @Environment(\.appearanceViewModel) private var appearanceViewModel
    
    var body: some View {
        Button(action: {
            showingInfoOverlay = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.gray)
                    .font(.system(size: 12))
                
                Text("Understand Your Score")
                  .font(.system(size: 12))

                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.top, 12)
        }
        .buttonStyle(ScaleButtonStyle())
        .sheet(isPresented: $showingInfoOverlay) {
            ScoreInfoOverlay(
                viewModel: viewModel,
                showingDisclaimer: $showingDisclaimer,
                isPresented: $showingInfoOverlay
            )
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct ScoreInfoOverlay: View {
    @ObservedObject var viewModel: ReadinessViewModel
    @Binding var showingDisclaimer: Bool
    @Binding var isPresented: Bool
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Score Categories")
                            .font(.headline.weight(.semibold))
                        
                        ScoreCategoryRow(
                            title: "Optimal (80-100)",
                            description: "Fully Recovered – Ready for high-intensity training and maximum effort.",
                            color: ReadinessCategory.optimal.color
                        )
                        
                        ScoreCategoryRow(
                            title: "Moderate (50-79)",
                            description: "Partial Recovery – Moderate training recommended. Avoid high-intensity sessions.",
                            color: ReadinessCategory.moderate.color
                        )
                        
                        ScoreCategoryRow(
                            title: "Low (30-49)",
                            description: "Low Recovery – Light training only. Focus on active recovery and mobility.",
                            color: ReadinessCategory.low.color
                        )
                        
                        ScoreCategoryRow(
                            title: "Fatigue (0-29)",
                            description: "Overtrained – Full recovery needed. Rest is essential, avoid all intense training.",
                            color: ReadinessCategory.fatigue.color
                        )
                    }
                    
                    Divider()
                    
                    // Score calculation section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How Your Score Is Calculated")
                            .font(.headline.weight(.semibold))
                        
                        Text("Your readiness score is primarily based on Heart Rate Variability (HRV) deviation from your baseline:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Within ±3% of baseline → Optimal (80-100)")
                            Text("3–7% below baseline → Moderate (50–79)")
                            Text("7–10% below baseline → Low (30–49)")
                            Text(">10% below baseline → Fatigue (0–29)")
                            Text(">10% above baseline → Supercompensation (90–100)")
                                .foregroundStyle(viewModel.hrvDeviation > 10 ? viewModel.hrvDeviationColor : .secondary)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        
                        Text("Adjustment factors (applied when enabled):")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Elevated resting heart rate (>5 bpm above baseline): -10%")
                            Text("Poor sleep quality (<6 hours): -15%")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    // Readiness modes section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Measurement Window")
                            .font(.headline.weight(.semibold))
                        
                        HStack(alignment: .top) {
                            Image(systemName: "sunrise")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading) {
                                Text("Morning Measurement")
                                    .font(.subheadline)
                                    .bold()
                                Text("Ready measures your HRV during sleep (00:00-\(String(format: "%02d", UserDefaultsManager.shared.morningEndHour)):00) to provide consistent and accurate morning readiness scores.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Disclaimer section
                    VStack(alignment: .leading, spacing: 0) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingDisclaimer.toggle()
                            }
                        }) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("Important Disclaimer")
                                    .font(.headline.weight(.semibold))
                                Spacer()
                                Image(systemName: showingDisclaimer ? "chevron.up" : "chevron.down")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if showingDisclaimer {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Readiness scores are not exact measurements and their reliability depends on:")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Quality and accuracy of your measuring device")
                                    Text("Consistency and quantity of data points collected")
                                    Text("Individual variations in physiological responses")
                                    Text("Environmental factors and measurement conditions")
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                
                                Text("These scores are intended for informational purposes only and should not be used as medical advice or to diagnose, treat, cure or prevent any disease or health condition. Always consult with a healthcare professional for medical advice.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                            .transition(.opacity)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .navigationTitle("Understand Your Score")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ScoreCategoryRow: View {
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 4, height: 36)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(color)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct UnderstandingScore_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            UnderstandingScore(viewModel: ReadinessViewModel())
                .padding()
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Button")
            
            ScoreInfoOverlay(
                viewModel: ReadinessViewModel(),
                showingDisclaimer: .constant(true),
                isPresented: .constant(true)
            )
            .previewDisplayName("Overlay")
        }
    }
}
