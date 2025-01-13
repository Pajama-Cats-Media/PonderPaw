//
//  ReadingCoPilotTests.swift
//  PonderPaw
//
//  Created by Homer Quan on 1/13/25.
//
import XCTest
@testable import PonderPaw

final class CoPilotTests: XCTestCase {
    var coPilot: CoPilot!
    let testJson = """
    {
        "meta": {
            "book_id": "8e28a441-7be5-40b0-a9b5-f207a8977197",
            "book_name": "The Three Little Pigs",
            "language": "en-US",
            "age_group": "4+",
            "voice_engine": "native",
            "default_mode": "interactive"
        },
        "playbook": {
            "pages": [
                {
                    "pageNumber": 1,
                    "actions": [
                        {"type": "read", "content": "Once upon a time...", "audio": "0dbdbb39-6ff6-55a2-a436-0da2d017c126.mp3"},
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
    }
    """

    class LogCollector: TextOutputStream {
        var logs: [String] = []

        func write(_ string: String) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                logs.append(trimmed)
            }
        }
    }

    override func setUp() {
        super.setUp()
        coPilot = CoPilot()
    }

    override func tearDown() {
        coPilot = nil
        super.tearDown()
    }

    func testCoPilotProcessesPagesAndActionsCorrectly() {
        // Load the JSON manifest
        coPilot.loadJson(jsonManifest: testJson)

        // Prepare the log collector
        let logCollector = LogCollector()
        let originalPrint = Swift.print

        // Expectation for the reading to complete
        let expectation = XCTestExpectation(description: "Reading process should complete")

        // Start reading
        coPilot.startReading()

        // Wait for the process to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {

            // Print captured logs to verify manually
            for log in logCollector.logs {
                print(log)
            }

            // Fulfill the expectation
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 25)
    }
}

class LogCollector: TextOutputStream {
    var logs: [String] = []

    func write(_ string: String) {
        logs.append(string.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
