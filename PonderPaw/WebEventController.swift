//
//  WebEventController.swift
//  PonderPaw
//
//  Created by Homer Quan on 1/9/25.
//

import Foundation
import RxSwift

class WebEventController {
    private let disposeBag = DisposeBag()
    private let throttledEventStream: PublishSubject<String> = PublishSubject()

    init() {
        setupThrottling()
    }

    /// Adds a new event to the stream
    func sendEvent(_ message: String) {
        throttledEventStream.onNext(Base64Utils.utoa(data:message) ?? "")
    }

    /// Subscribes to the throttled event stream
    func onEventReceived(_ callback: @escaping (String) -> Void) {
        throttledEventStream
            .throttle(.milliseconds(500), scheduler: MainScheduler.instance) // Throttling events
            .subscribe(onNext: { message in
                callback(message)
            })
            .disposed(by: disposeBag)
    }

    /// Sets up throttling for the event stream
    private func setupThrottling() {
        // This can be customized if needed
    }
}
