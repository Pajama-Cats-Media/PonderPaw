import SwiftUI

struct SubtitleView: View {
    @ObservedObject var viewModel: SubtitleViewModel

    var body: some View {
        ZStack {
//            // Full content as the background text
//            Text(viewModel.content)
//                .font(.system(size: 24))
//                .multilineTextAlignment(.center)
//                .foregroundColor(.gray.opacity(0.5)) // Light gray color for background text
//                .padding()

            // Highlighted current chunk
            Text(viewModel.currentChunk)
                .font(.system(size: 24))
                .multilineTextAlignment(.center)
                .foregroundColor(.red) // Highlighted text in yellow
                .padding()

//            // Progressive highlighting text
//            Text(viewModel.highlightedText)
//                .font(.system(size: 24))
//                .multilineTextAlignment(.center)
//                .foregroundColor(.green) // Highlighted progressive text in green
//                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: 100)
        .background(Color.white.opacity(0.8))
        .onAppear {
            print("SubtitleView appeared")
        }
    }
}
