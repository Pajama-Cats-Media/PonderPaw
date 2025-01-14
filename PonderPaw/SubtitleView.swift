import SwiftUI

struct SubtitleView: View {
    @ObservedObject var viewModel: SubtitleViewModel

    var body: some View {
        ZStack {
            // Full content as the background text
            Text(viewModel.content)
                .font(.system(size: 24))
                .multilineTextAlignment(.center)
                .foregroundColor(.gray.opacity(0.5)) // Light gray color for background text
                .padding()
            
            // Highlighted current subtitle text
            Text(viewModel.currentSubtitle)
                .font(.system(size: 24))
                .multilineTextAlignment(.center)
                .foregroundColor(.yellow) // Highlighted text in yellow
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: 100)
        .background(Color.white.opacity(0.8)) // To differentiate the box visually
        .onAppear {
            print("SubtitleView appeared") // Debug log
        }
    }
}
