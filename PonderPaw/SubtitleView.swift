import SwiftUI

struct SubtitleView: View {
    @ObservedObject var viewModel: SubtitleViewModel

    var body: some View {
        Text(viewModel.currentSubtitle)
            .font(.system(size: 24))
            .multilineTextAlignment(.center)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: 100)
            .background(Color.white.opacity(0.8)) // To differentiate the box visually
            .onAppear {
                print("SubtitleView appeared") // Debug log
            }
    }
}
