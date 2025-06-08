import SwiftUI

struct InitialSetupView: View {
    @ObservedObject var viewModel: ReadinessViewModel
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            VStack(spacing: isLandscape ? 20 : 30) {
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
                        .rotationEffect(.degrees(360))
                        .animation(Animation.linear(duration: 2).repeatForever(autoreverses: false), value: viewModel.isPerformingInitialSetup)
                }
                
                // Title
                Text("Setting Up Ready")
                    .font(.system(size: isLandscape ? 28 : 32, weight: .bold, design: .rounded))
                
                // Status message
                VStack(spacing: 8) {
                    Text(viewModel.initialSetupStatus)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text("This will only take a moment. We're importing your historical health data to establish your personalized baseline.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(height: 100)
                
                // Progress bar
                VStack(spacing: 10) {
                    ProgressView(value: viewModel.initialSetupProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color.accentColor))
                        .padding(.horizontal, 40)
                    
                    Text("\(Int(viewModel.initialSetupProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                if !isLandscape {
                    Spacer()
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemBackground))
    }
}

struct InitialSetupView_Previews: PreviewProvider {
    static var previews: some View {
        InitialSetupView(viewModel: ReadinessViewModel())
    }
} 