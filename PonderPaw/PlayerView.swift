import SwiftUI

struct PlayerView: View {
    let url: URL
    @ObservedObject var viewModel: PlayerViewModel

    var body: some View {
        ZStack {
            // Pass the WebContentViewModel instead of the event controller
            WebContentView(url: url, viewModel: viewModel.webContentViewModel)
            
            Button(action: {
                viewModel.nextPage()
            }) {
                Text("Click Anywhere")
                    .padding()
                    .background(Color.blue.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .accessibility(hidden: false)
            }
            .padding()
        }
    }
}
