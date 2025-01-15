import SwiftUI

struct SubtitleView: View {
    @ObservedObject var viewModel: SubtitleViewModel

    var body: some View {
        ZStack {
            // Display the current chunk of subtitle
            Text(viewModel.currentChunk)
                .font(.system(size: 24))
                .multilineTextAlignment(.center)
                .foregroundColor(.red) // Highlighted text in red
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: 100)
        .background(Color.white.opacity(0.8))
        .onAppear {
            viewModel.startPlayback()
        }
        .onDisappear {
            viewModel.stopPlayback()
        }
    }
}
