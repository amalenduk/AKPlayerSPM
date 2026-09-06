//
//  AKLogCategory.swift
//  AKPlayer
//
//  Created by Amalendu Kar on 04/09/26.
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
