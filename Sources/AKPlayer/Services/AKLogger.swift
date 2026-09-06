//
//  AKLogCategory.swift
//  AKPlayer
//
//  Copyright (c) 2020 Amalendu Kar
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation
import os.log

public enum AKLogCategory: String, Sendable {
    case player = "Player"
    case media = "Media"
    case session = "AudioSession"
    case remote = "RemoteCommands"
    case lifecycle = "Lifecycle"
}

public struct AKLogger: Sendable {
    private static let subsystem = "com.AKPlayer.framework"
    
    /// Global toggle to enable or disable logging across the framework.
    public static var isEnabled: Bool = true
    
    private static func logger(for category: AKLogCategory) -> Logger {
        return Logger(subsystem: subsystem, category: category.rawValue)
    }
    
    public static func debug(_ message: String, category: AKLogCategory) {
        guard isEnabled else { return }
        logger(for: category).debug("\(message, privacy: .public)")
    }
    
    public static func info(_ message: String, category: AKLogCategory) {
        guard isEnabled else { return }
        logger(for: category).info("\(message, privacy: .public)")
    }
    
    public static func warning(_ message: String, category: AKLogCategory) {
        guard isEnabled else { return }
        logger(for: category).warning("\(message, privacy: .public)")
    }
    
    public static func error(_ message: String, category: AKLogCategory, error: Error? = nil) {
        guard isEnabled else { return }
        if let error = error {
            logger(for: category).error("\(message) - Error: \(error.localizedDescription, privacy: .public)")
        } else {
            logger(for: category).error("\(message, privacy: .public)")
        }
    }
}
