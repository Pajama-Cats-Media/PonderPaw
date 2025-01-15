import Foundation
import Combine

class PlayerViewModel: ObservableObject {
    let webContentViewModel: WebContentViewModel
    private var cancellables = Set<AnyCancellable>()

    // Published property to propagate DOM ready state
    @Published var isDOMReady: Bool = false

    init() {
        self.webContentViewModel = WebContentViewModel()

        // Observe the DOM ready state from WebContentViewModel
        webContentViewModel.$isDOMReady
            .receive(on: DispatchQueue.main)
            .assign(to: &$isDOMReady)
    }

    func turnPage() {
        webContentViewModel.sendEvent("pageTurned")
    }
}
