import Foundation
import Combine

class PlayerViewModel: ObservableObject {
    let webContentViewModel: WebContentViewModel
    private var cancellables = Set<AnyCancellable>()

    // Event name constants
    private let nextPageEvent = "next_page"
    private let prevPageEvent = "prev_page"
    private let gotoPageEvent = "goto_page"

    // Published property to propagate DOM ready state
    @Published var isDOMReady: Bool = false

    init() {
        self.webContentViewModel = WebContentViewModel()

        // Observe the DOM ready state from WebContentViewModel
        webContentViewModel.$isDOMReady
            .receive(on: DispatchQueue.main)
            .assign(to: &$isDOMReady)
    }

    // Function to go to the next page
    func nextPage() {
        webContentViewModel.sendEvent(topic:nextPageEvent)
    }

    // Function to go to the previous page
    func prevPage() {
        webContentViewModel.sendEvent(topic:prevPageEvent)
    }

    // Function to go to a specific page by number
    func gotoPage(number: Int) {
        webContentViewModel.sendEvent(topic:gotoPageEvent, data:["pageNumber": number])
    }
}
