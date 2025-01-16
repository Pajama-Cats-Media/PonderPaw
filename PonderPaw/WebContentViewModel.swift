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
            .throttle(.milliseconds(200), scheduler: MainScheduler.instance)
    }

    /// Sends a new event into the stream with type and data
    func sendEvent(topic: String, data: [String: Any]? = nil) {
        var message: [String: Any] = ["topic": topic]
        if let data = data {
            message["data"] = data
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: message),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            eventStream.onNext(jsonString)
        } else {
            print("Failed to serialize message to JSON")
        }
    }

    /// Notifies when the DOM is ready
    func notifyDOMReady() {
        isDOMReady = true
    }
}
