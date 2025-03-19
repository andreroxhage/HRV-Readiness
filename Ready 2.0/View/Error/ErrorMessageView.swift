import SwiftUI

struct ErrorMessageView: View {
    let error: ReadinessError
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Error", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                    .foregroundColor(.red)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            
            Divider()
            
            Text(error.errorDescription ?? "Unknown error")
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            if let recovery = error.recoverySuggestion {
                Text(recovery)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
        .padding(.bottom, 8)
    }
}

#Preview {
    ErrorMessageView(
        error: .dataProcessingFailed(
            component: "HRV data", 
            reason: "Unable to fetch recent measurements"
        ),
        onDismiss: {}
    )
    .padding()
}
