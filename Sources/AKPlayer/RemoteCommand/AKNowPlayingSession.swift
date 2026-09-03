//
//  AKNowPlayingSession.swift
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
import MediaPlayer
import AVFoundation

/// High-level manager for Now Playing session management with command configuration.
/// Provides production-ready session management with easy enable/disable capabilities.
public protocol AKNowPlayingSessionProtocol: AKNowPlayingSessionControllerProtocol {
    
    /// The command registry for this session.
    var commandRegistry: AKNowPlayingCommandRegistry { get }
    
    /// Applies a command configuration to this session.
    func applyConfiguration(_ config: AKNowPlayingCommandConfiguration) async
    
    /// Checks if the session is currently active.
    var isActive: Bool { get }
}

/// Production-ready implementation of AKNowPlayingSessionManager.
public final class AKNowPlayingSession: AKNowPlayingSessionProtocol {
    
    // MARK: - Properties
    
    public var eventEmitter: AKRemoteCommandEventEmitter {
        return controller.eventEmitter
    }
    
    public let commandRegistry: AKNowPlayingCommandRegistry
    private let controller: AKNowPlayingSessionController
    
    public var remoteCommandCenter: MPRemoteCommandCenter {
        return controller.remoteCommandCenter
    }
    
    public var nowPlayingInfoCenter: MPNowPlayingInfoCenter {
        return controller.nowPlayingInfoCenter
    }
    
    public var isActive: Bool {
        return controller.isActive
    }
    
    // MARK: - Initialization & Deinitialization
    
    /// Initializes a new Now Playing session with audio players.
    public init(players: [AVPlayer], registry: AKNowPlayingCommandRegistry? = nil) {
        self.controller = AKNowPlayingSessionController(players: players)
        self.commandRegistry = registry ?? AKNowPlayingCommandRegistry()
    }
    
    /// Initializes a standalone Now Playing session.
    public init(remoteCommandCenter: MPRemoteCommandCenter = .shared(),
                nowPlayingInfoCenter: MPNowPlayingInfoCenter = .default(),
                registry: AKNowPlayingCommandRegistry? = nil) {
        self.controller = AKNowPlayingSessionController(
            remoteCommandCenter: remoteCommandCenter,
            nowPlayingInfoCenter: nowPlayingInfoCenter
        )
        self.commandRegistry = registry ?? AKNowPlayingCommandRegistry()
    }
    
    // MARK: - Configuration
    
    /// Applies a command configuration to this session.
    /// Registers, enables, and sets up handlers for configured commands.
    public func applyConfiguration(_ config: AKNowPlayingCommandConfiguration) async {
        let commands = config.getCommands()
        
        // Register all commands
        for command in commands {
            commandRegistry.register(command, isEnabled: config.isEnabled(command))
        }
        
        // Apply handlers
        for command in commands {
            if let handler = config.getHandler(for: command) {
                commandRegistry.setCustomHandler(command, handler: handler)
                controller.setHandler(for: command, handler: handler)
            }
        }
        
        // Register with remote command center
        controller.register(commands: commands)
        
        // Enable/disable as configured
        for command in commands {
            if config.isEnabled(command) {
                controller.enable(commands: [command])
            } else {
                controller.disable(commands: [command])
            }
        }
    }
    
    // MARK: - Command Management
    
    public func register(commands: [AKRemoteCommand]) {
        for command in commands {
            commandRegistry.register(command)
        }
        controller.register(commands: commands)
    }
    
    public func unregister(commands: [AKRemoteCommand]) {
        for command in commands {
            commandRegistry.unregister(command)
        }
        controller.unregister(commands: commands)
    }
    
    public func enable(commands: [AKRemoteCommand]) {
        let enabledCommands = commands.filter { commandRegistry.enable($0) }
        controller.enable(commands: enabledCommands)
    }
    
    public func disable(commands: [AKRemoteCommand]) {
        let disabledCommands = commands.filter { commandRegistry.disable($0) }
        controller.disable(commands: disabledCommands)
    }
    
    public func isCommandEnabled(_ command: AKRemoteCommand) -> Bool {
        return commandRegistry.isEnabled(command)
    }
    
    public func setHandler(for command: AKRemoteCommand, handler: @escaping AKRemoteCommandHandler) {
        commandRegistry.setCustomHandler(command, handler: handler)
        controller.setHandler(for: command, handler: handler)
    }
    
    public func removeHandler(for command: AKRemoteCommand) {
        commandRegistry.removeCustomHandler(command)
        controller.removeHandler(for: command)
    }
    
    // MARK: - Metadata Management
    
    public func setNowPlayingInfo(_ metadata: AKNowPlayableMetadata?) {
        controller.setNowPlayingInfo(metadata)
    }
    
    public func clearNowPlayingPlaybackInfo() {
        controller.clearNowPlayingPlaybackInfo()
    }
    
    public func canBecomeActive() -> Bool {
        controller.canBecomeActive()
    }
    
    // MARK: - Player Management
    
    public func addPlayer(_ player: AVPlayer) {
        controller.addPlayer(player)
    }
    
    public func removePlayer(_ player: AVPlayer) {
        controller.removePlayer(player)
    }
    
    public func becomeActiveIfPossible() async -> Bool {
        return await controller.becomeActiveIfPossible()
    }
    
    // MARK: - Cleanup
    
    deinit {
        commandRegistry.clear()
    }
}

// MARK: - Convenience Extensions

extension AKNowPlayingSession {
    
    /// Configures session with a preset configuration asynchronously.
    public func configureWithPreset(_ preset: AKNowPlayingCommandConfiguration) async {
        await applyConfiguration(preset)
    }
}
