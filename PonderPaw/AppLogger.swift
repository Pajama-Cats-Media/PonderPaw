//
//  AppLogger.swift
//  PonderPaw
//
//  Created by Homer Quan on 1/13/25.
//


import os
import Foundation

class AppLogger {
    static let shared = AppLogger()

    private init() {}

    private var subsystem: String {
        #if DEBUG
        return Bundle.main.bundleIdentifier ?? "com.default.identifier.debug"
        #else
        return Bundle.main.bundleIdentifier ?? "com.default.identifier"
        #endif
    }

    func logger(forCategory category: String) -> Logger {
        return Logger(subsystem: subsystem, category: category)
    }

    func logInfo(category: String, message: String) {
        let logger = logger(forCategory: category)
        logger.info("\(message, privacy: .public)")
    }

    func logError(category: String, message: String) {
        let logger = logger(forCategory: category)
        logger.error("\(message, privacy: .public)")
    }

    func logDebug(category: String, message: String) {
        let logger = logger(forCategory: category)
        logger.debug("\(message, privacy: .public)")
    }
}
