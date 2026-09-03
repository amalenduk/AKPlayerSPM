//
//  AKNowPlayingCommandRegistry.swift
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

/// Thread-safe registry for managing remote commands and their configurations.
/// Provides centralized command state management and validation.
public final class AKNowPlayingCommandRegistry {
    
    // MARK: - Properties
    
    private let lock = NSRecursiveLock()
    private var commandConfigs: [String: CommandConfig] = [:]
    private var commandStates: [String: CommandState] = [:]
    private var customHandlers: [AKRemoteCommand: AKRemoteCommandHandler] = [:]
    
    // MARK: - Types
    
    private struct CommandConfig {
        let command: AKRemoteCommand
        var isEnabled: Bool
        var canBeDisabled: Bool
        var customHandler: AKRemoteCommandHandler?
    }
    
    private struct CommandState {
        let commandKey: String
        var isActive: Bool
        var lastExecutedDate: Date?
        var executionCount: Int
    }
    
    // MARK: - Initialization & Deinitialization
    
    public init() {}
    
    // MARK: - Registration
    
    /// Registers a command with optional configuration.
    public func register(_ command: AKRemoteCommand,
                         isEnabled: Bool = true,
                         canBeDisabled: Bool = true) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = command.hashKey
        commandConfigs[key] = CommandConfig(
            command: command,
            isEnabled: isEnabled,
            canBeDisabled: canBeDisabled,
            customHandler: nil
        )
        commandStates[key] = CommandState(
            commandKey: key,
            isActive: isEnabled,
            lastExecutedDate: nil,
            executionCount: 0
        )
    }
    
    /// Registers multiple commands at once.
    public func register(commands: [AKRemoteCommand],
                         isEnabled: Bool = true,
                         canBeDisabled: Bool = true) {
        commands.forEach { register($0, isEnabled: isEnabled, canBeDisabled: canBeDisabled) }
    }
    
    /// Unregisters a command.
    public func unregister(_ command: AKRemoteCommand) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = command.hashKey
        commandConfigs.removeValue(forKey: key)
        commandStates.removeValue(forKey: key)
        customHandlers.removeValue(forKey: command)
    }
    
    /// Unregisters multiple commands.
    public func unregister(commands: [AKRemoteCommand]) {
        commands.forEach { unregister($0) }
    }
    
    // MARK: - Command State Management
    
    /// Enables a registered command.
    @discardableResult
    public func enable(_ command: AKRemoteCommand) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let key = command.hashKey
        guard var config = commandConfigs[key], config.canBeDisabled else { return false }
        
        config.isEnabled = true
        commandConfigs[key] = config
        
        if var state = commandStates[key] {
            state.isActive = true
            commandStates[key] = state
        }
        
        return true
    }
    
    /// Disables a registered command.
    @discardableResult
    public func disable(_ command: AKRemoteCommand) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let key = command.hashKey
        guard var config = commandConfigs[key], config.canBeDisabled else { return false }
        
        config.isEnabled = false
        commandConfigs[key] = config
        
        if var state = commandStates[key] {
            state.isActive = false
            commandStates[key] = state
        }
        
        return true
    }
    
    /// Checks if a command is currently enabled.
    public func isEnabled(_ command: AKRemoteCommand) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let key = command.hashKey
        return commandConfigs[key]?.isEnabled ?? false
    }
    
    /// Checks if a command can be disabled.
    public func canBeDisabled(_ command: AKRemoteCommand) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let key = command.hashKey
        return commandConfigs[key]?.canBeDisabled ?? false
    }
    
    /// Checks if a command is registered.
    public func isRegistered(_ command: AKRemoteCommand) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        return commandConfigs[command.hashKey] != nil
    }
    
    // MARK: - Custom Handlers
    
    /// Sets a custom handler for a command.
    public func setCustomHandler(_ command: AKRemoteCommand,
                                 handler: @escaping AKRemoteCommandHandler) {
        lock.lock()
        defer { lock.unlock() }
        
        guard isRegistered(command) else { return }
        
        let key = command.hashKey
        customHandlers[command] = handler
        
        if var config = commandConfigs[key] {
            config.customHandler = handler
            commandConfigs[key] = config
        }
    }
    
    /// Removes custom handler for a command.
    public func removeCustomHandler(_ command: AKRemoteCommand) {
        lock.lock()
        defer { lock.unlock() }
        
        customHandlers.removeValue(forKey: command)
        
        let key = command.hashKey
        if var config = commandConfigs[key] {
            config.customHandler = nil
            commandConfigs[key] = config
        }
    }
    
    /// Gets custom handler for a command if exists.
    public func customHandler(for command: AKRemoteCommand) -> AKRemoteCommandHandler? {
        lock.lock()
        defer { lock.unlock() }
        
        return customHandlers[command]
    }
    
    // MARK: - Query Operations
    
    /// Gets all registered commands.
    public func allRegisteredCommands() -> [AKRemoteCommand] {
        lock.lock()
        defer { lock.unlock() }
        
        return Array(commandConfigs.values.map { $0.command })
    }
    
    /// Gets all enabled commands.
    public func enabledCommands() -> [AKRemoteCommand] {
        lock.lock()
        defer { lock.unlock() }
        
        return commandConfigs.values
            .filter { $0.isEnabled }
            .map { $0.command }
    }
    
    /// Gets all disabled commands.
    public func disabledCommands() -> [AKRemoteCommand] {
        lock.lock()
        defer { lock.unlock() }
        
        return commandConfigs.values
            .filter { !$0.isEnabled }
            .map { $0.command }
    }
    
    // MARK: - Execution Tracking
    
    /// Records command execution for analytics/debugging.
    public func recordExecution(for command: AKRemoteCommand) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = command.hashKey
        if var state = commandStates[key] {
            state.lastExecutedDate = Date()
            state.executionCount += 1
            commandStates[key] = state
        }
    }
    
    /// Gets execution info for a command.
    public func executionInfo(for command: AKRemoteCommand) -> (count: Int, lastExecuted: Date?)? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let state = commandStates[command.hashKey] else { return nil }
        return (count: state.executionCount, lastExecuted: state.lastExecutedDate)
    }
    
    // MARK: - Cleanup
    
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        commandConfigs.removeAll()
        commandStates.removeAll()
        customHandlers.removeAll()
    }
}

// MARK: - Extensions

extension AKRemoteCommand {
    var hashKey: String {
        return String(describing: self)
    }
}
