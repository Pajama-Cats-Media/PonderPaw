import SwiftUI

struct SubtitleView: View {
    @ObservedObject var viewModel: SubtitleViewModel

    var body: some View {
        if !viewModel.currentChunk.isEmpty {
            Text(viewModel.currentChunk) // Display the current subtitle chunk
                .font(.system(size: 20)) // Set font size
                .multilineTextAlignment(.center) // Center-align text
                .foregroundColor(.white) // White text color
                .padding() // Add padding around the text
                .frame(maxWidth: .infinity, alignment: .bottom) // Align at the bottom
                .background(Color.black.opacity(0.8)) // Semi-transparent black background
                .onAppear {
                    viewModel.startPlayback()
                }
                .onDisappear {
                    viewModel.stopPlayback()
                }
        }
    }
}
