import SwiftUI

struct InitialSetupView: View {
    @ObservedObject var viewModel: ReadinessViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            VStack(spacing: isLandscape ? 16 : 24) {
                if !isLandscape {
                    Spacer()
                }
                
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: isLandscape ? 100 : 120, height: isLandscape ? 100 : 120)
                    
                    Image(systemName: "arrow.clockwise")
                        .resizable()
                        .scaledToFit()
                        .frame(width: isLandscape ? 65 : 80, height: isLandscape ? 65 : 80)
                        .foregroundColor(.accentColor)
                        .rotationEffect(.degrees(rotation))
                        .onAppear {
                            if !reduceMotion {
                                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                                    rotation = 360
                                }
                            }
                        }
                }
                .padding(.bottom, 8)
                
                // Title
                Text("Setting Up Ready")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .padding(.bottom, 8)
                
                // Status message
                VStack(spacing: 12) {
                    Text(viewModel.initialSetupStatus)
                        .font(.headline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                    
                    Text("This will only take a moment. We're importing your historical health data to establish your personalized baseline.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .frame(minHeight: 100)
                
                // Progress bar
                VStack(spacing: 12) {
                    ProgressView(value: viewModel.initialSetupProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color.accentColor))
                        .padding(.horizontal, 40)
                    
                    Text("\(Int(viewModel.initialSetupProgress * 100))%")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 16)
                
                if !isLandscape {
                    Spacer()
                }
            }
            .padding(16)
        }
        .background(Color(UIColor.systemBackground))
    }
}

struct InitialSetupView_Previews: PreviewProvider {
    static var previews: some View {
        InitialSetupView(viewModel: ReadinessViewModel())
    }
} 