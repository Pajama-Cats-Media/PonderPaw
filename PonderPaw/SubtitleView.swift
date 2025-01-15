import SwiftUI

struct SubtitleView: View {
    @ObservedObject var viewModel: SubtitleViewModel

    var body: some View {
        ZStack {
            // Highlighted progressive text
            Text(viewModel.highlightedText)
                .font(.system(size: 24))
                .multilineTextAlignment(.center)
                .foregroundColor(.green.opacity(0.8)) // Progressive text in green
                .padding()

            // Highlighted current chunk
            Text(viewModel.currentChunk)
                .font(.system(size: 24))
                .multilineTextAlignment(.center)
                .foregroundColor(.red) // Current chunk in red
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
