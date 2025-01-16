import SwiftUI

struct PlayerView: View {
    let url: URL
    @ObservedObject var viewModel: PlayerViewModel

    var body: some View {
        ZStack {
            // Pass the WebContentViewModel instead of the event controller
            WebContentView(url: url, viewModel: viewModel.webContentViewModel)
        }
    }
}
