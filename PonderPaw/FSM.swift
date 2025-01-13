//
//  FSM.swift
//  PonderPaw
//
//  Created by Homer Quan on 1/13/25.
//

import Foundation
import GameplayKit
import RxSwift

class StartState: GKState {
    override func didEnter(from previousState: GKState?) {
        print("Starting the reading co-pilot...")
    }

    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass == PageReadyState.self
    }
}

class PageReadyState: GKState {
    weak var coPilot: ReadingCoPilot?
    var page: [String: Any]?

    func configure(with page: [String: Any]) {
        self.page = page
    }

    override func didEnter(from previousState: GKState?) {
        guard let page = page, let pageNumber = page["pageNumber"] as? Int else { return }
        print("Page \(pageNumber) is ready.")
    }

    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass == ActionState.self || stateClass == FinishState.self
    }
}

class ActionState: GKState {
    weak var coPilot: ReadingCoPilot?

    override func didEnter(from previousState: GKState?) {
        print("Entered ActionState. Waiting for ReadingCoPilot to execute actions.")
    }

    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass == PageReadyState.self || stateClass == FinishState.self
    }
}

class FinishState: GKState {
    override func didEnter(from previousState: GKState?) {
        print("Reading completed.")
    }

    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return false
    }
}
