import Foundation
import RxSwift
import Combine

class WebContentViewModel: ObservableObject {
    private let disposeBag = DisposeBag()

    // Published property to notify DOM ready state
    @Published var isDOMReady: Bool = false

    // Input: Stream for incoming events
    private let eventStream = PublishSubject<String>()

    // Output: Exposed throttled event stream for binding
    var throttledEvent: Observable<String> {
        eventStream
            .throttle(.milliseconds(500), scheduler: MainScheduler.instance)
    }

    /// Sends a new event into the stream
    func sendEvent(_ message: String) {
        eventStream.onNext(message)
    }

    /// Notifies when the DOM is ready
    func notifyDOMReady() {
        isDOMReady = true
        sendEvent("ready")
    }
}
