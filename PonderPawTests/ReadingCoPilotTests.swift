//
//  ReadingCoPilotTests.swift
//  PonderPaw
//
//  Created by Homer Quan on 1/13/25.
//
import XCTest
@testable import PonderPaw

class ReadingCoPilotTests: XCTestCase {
    var coPilot: ReadingCoPilot!
    let jsonManifest = """
    {
      "pages": [
        {
          "pageNumber": 1,
          "actions": [
            {"type": "read", "content": "Once upon a time..."},
            {"type": "suggestion", "content": "Think about the main character."}
          ]
        },
        {
          "pageNumber": 2,
          "actions": [
            {"type": "read", "content": "The cat jumped over the moon."},
            {"type": "suggestion", "content": "Why do you think the cat jumped?"}
          ]
        }
      ]
    }
    """

    override func setUp() {
        super.setUp()
        // Initialize the ReadingCoPilot instance with the JSON manifest
        coPilot = ReadingCoPilot(jsonManifest: jsonManifest)
    }

    override func tearDown() {
        coPilot = nil
        super.tearDown()
    }

    func testInitialState() {
        // Ensure the initial state is StartState
        XCTAssertTrue(coPilot.stateMachine.currentState is StartState, "Initial state should be StartState.")
    }

    func testStartReadingTransitions() {
        // Start reading and check transitions to PageReadyState
        coPilot.startReading()
        XCTAssertTrue(coPilot.stateMachine.currentState is PageReadyState, "Should transition to PageReadyState.")
        
        let currentPageState = coPilot.stateMachine.currentState as? PageReadyState
        XCTAssertEqual(currentPageState?.page?["pageNumber"] as? Int, 1, "Page number should be 1.")
    }

    func testActionsExecution() {
        // Start reading to PageReadyState
        coPilot.startReading()
        XCTAssertTrue(coPilot.stateMachine.currentState is PageReadyState, "Should transition to PageReadyState.")

        // Transition to ActionState
        let currentPage = coPilot.pages[coPilot.currentPageIndex - 1]
        let actions = currentPage["actions"] as? [[String: Any]]
        coPilot.stateMachine.enter(ActionState.self)
        (coPilot.stateMachine.currentState as? ActionState)?.actions = actions

        XCTAssertTrue(coPilot.stateMachine.currentState is ActionState, "Should transition to ActionState.")
        XCTAssertEqual(actions?.count, 2, "There should be 2 actions on page 1.")
    }

    func testFinishState() {
        // Process all pages
        coPilot.startReading() // Page 1
        coPilot.startReading() // Page 2
        coPilot.startReading() // Finish

        XCTAssertTrue(coPilot.stateMachine.currentState is FinishState, "Should transition to FinishState after all pages are processed.")
    }
}
