//
//  AKLogger.swift
//  AKPlayer
//
//  Copyright (c) 2020 Amalendu Kar
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE
//  SOFTWARE.
//

import Foundation
import os

// MARK: - AKLogCategory

/// Categories used to organize AKPlayer's internal logging.
public enum AKLogCategory: String, Sendable {
    case player = "Player"
    case media = "Media"
    case session = "AudioSession"
    case remote = "RemoteCommands"
    case lifecycle = "Lifecycle"
}

// MARK: - AKLogger

/// Internal logger used throughout AKPlayer.
///
/// AKLogger is intentionally internal. Applications using AKPlayer should
/// receive diagnostics through the system Console app rather than depending
/// on AKPlayer's internal logging implementation.
public enum AKLogger: Sendable {
    // MARK: - Subsystem & Static Loggers

    private static let subsystem = "com.AKPlayer.framework"

    private static let player = Logger(
        subsystem: subsystem,
        category: AKLogCategory.player.rawValue
    )

    private static let media = Logger(
        subsystem: subsystem,
        category: AKLogCategory.media.rawValue
    )

    private static let session = Logger(
        subsystem: subsystem,
        category: AKLogCategory.session.rawValue
    )

    private static let remote = Logger(
        subsystem: subsystem,
        category: AKLogCategory.remote.rawValue
    )

    private static let lifecycle = Logger(
        subsystem: subsystem,
        category: AKLogCategory.lifecycle.rawValue
    )

    // MARK: - Logger Resolution

    private static func logger(for category: AKLogCategory) -> Logger {
        switch category {
        case .player:
            player
        case .media:
            media
        case .session:
            session
        case .remote:
            remote
        case .lifecycle:
            lifecycle
        }
    }
}

// MARK: - AKLogger + Autoclosure Logging API

public extension AKLogger {
    // MARK: - Debug

    /// Logs a debug-level message.
    ///
    /// - Parameters:
    ///   - message: The log message.
    ///   - category: The logging category.
    static func debug(
        _ message: String,
        category: AKLogCategory
    ) {
        logger(for: category).debug(
            "\(message, privacy: .public)"
        )
    }

    // MARK: - Info

    /// Logs an info-level message.
    ///
    /// - Parameters:
    ///   - message: The log message.
    ///   - category: The logging category.
    static func info(
        _ message: String,
        category: AKLogCategory
    ) {
        logger(for: category).info(
            "\(message, privacy: .public)"
        )
    }

    // MARK: - Warning

    /// Logs a warning-level message.
    ///
    /// - Parameters:
    ///   - message: The log message.
    ///   - category: The logging category.
    static func warning(
        _ message: String,
        category: AKLogCategory
    ) {
        logger(for: category).warning(
            "\(message, privacy: .public)"
        )
    }

    // MARK: - Error

    /// Logs an error-level message, optionally including an underlying error.
    ///
    /// - Parameters:
    ///   - message: The log message.
    ///   - category: The logging category.
    ///   - error: An optional error associated with the log event.
    static func error(
        _ message: String,
        category: AKLogCategory,
        error: Error? = nil
    ) {
        if let error {
            logger(for: category).error(
                "\(message, privacy: .public) - Error: \(error.localizedDescription, privacy: .public)"
            )
        } else {
            logger(for: category).error(
                "\(message, privacy: .public)"
            )
        }
    }
}
