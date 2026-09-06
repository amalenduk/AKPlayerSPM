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

/// Thread-safe actor registry for managing remote commands and their configurations.
/// Uses Swift Concurrency (actor isolation) to ensure data synchronization without manual locks.
public actor AKNowPlayingCommandRegistry {
    
    // MARK: - Properties
    
    /// Map storing internal configurations indexed by command string key.
    private var commandConfigs: [String: CommandConfig] = [:]
    
    /// Map storing runtime execution and active state indexed by command string key.
    private var commandStates: [String: CommandState] = [:]
    
    /// Direct mapping of `AKRemoteCommand` targets to custom action closures.
    private var customHandlers: [AKRemoteCommand: AKRemoteCommandHandler] = [:]
    
    // MARK: - Types
    
    /// Internal structure encapsulating command configuration options.
    private struct CommandConfig: Sendable {
        let command: AKRemoteCommand
        var isEnabled: Bool
        var canBeDisabled: Bool
        var customHandler: AKRemoteCommandHandler?
    }
    
    /// Internal structure tracking runtime activity and execution metrics.
    private struct CommandState: Sendable {
        let commandKey: String
        var isActive: Bool
        var lastExecutedDate: Date?
        var executionCount: Int
    }
    
    // MARK: - Initialization
    
    /// Creates a new isolated actor instance of `AKNowPlayingCommandRegistry`.
    public init() {}
    
    /// Creates a new isolated actor instance initialized with a given `AKNowPlayingCommandConfiguration`.
    /// - Parameter configuration: The configuration object to apply upon initialization.
    public init(configuration: AKNowPlayingCommandConfiguration) async {
        self.init()
        await apply(configuration: configuration)
    }
    
    // MARK: - Registration
    
    /// Registers a command with optional configuration.
    /// - Parameters:
    ///   - command: The target remote command to register.
    ///   - isEnabled: Indicates if the command should start in an enabled state. Default is `true`.
    ///   - canBeDisabled: Indicates whether this command can be dynamically disabled later. Default is `true`.
    public func register(_ command: AKRemoteCommand,
                         isEnabled: Bool = true,
                         canBeDisabled: Bool = true) {
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
    
    /// Registers multiple commands at once with uniform parameters.
    /// - Parameters:
    ///   - commands: Array of commands to register.
    ///   - isEnabled: Initial state applied to all commands. Default is `true`.
    ///   - canBeDisabled: Flag determining whether commands can be disabled. Default is `true`.
    public func register(commands: [AKRemoteCommand],
                         isEnabled: Bool = true,
                         canBeDisabled: Bool = true) {
        for command in commands {
            register(command, isEnabled: isEnabled, canBeDisabled: canBeDisabled)
        }
    }
    
    /// Unregisters a single command and removes its associated configurations and handlers.
    /// - Parameter command: The target remote command to remove.
    public func unregister(_ command: AKRemoteCommand) {
        let key = command.hashKey
        commandConfigs.removeValue(forKey: key)
        commandStates.removeValue(forKey: key)
        customHandlers.removeValue(forKey: command)
    }
    
    /// Unregisters multiple commands at once.
    /// - Parameter commands: Array of commands to unregister.
    public func unregister(commands: [AKRemoteCommand]) {
        for command in commands {
            unregister(command)
        }
    }
    
    // MARK: - Command State Management
    
    /// Enables a registered remote command.
    /// - Parameter command: Target command to enable.
    /// - Returns: `true` if state was mutated, or `false` if command is unregistered or non-mutable.
    @discardableResult
    public func enable(_ command: AKRemoteCommand) -> Bool {
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
    
    /// Disables a registered remote command.
    /// - Parameter command: Target command to disable.
    /// - Returns: `true` if state was mutated, or `false` if command is unregistered or protected (`canBeDisabled == false`).
    @discardableResult
    public func disable(_ command: AKRemoteCommand) -> Bool {
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
    
    /// Checks if a command is currently registered and enabled.
    /// - Parameter command: Target remote command to query.
    /// - Returns: `true` if enabled; otherwise `false`.
    public func isEnabled(_ command: AKRemoteCommand) -> Bool {
        let key = command.hashKey
        return commandConfigs[key]?.isEnabled ?? false
    }
    
    /// Checks if a command allows dynamic enable/disable state mutations.
    /// - Parameter command: Target remote command to query.
    /// - Returns: `true` if command state can be toggled; otherwise `false`.
    public func canBeDisabled(_ command: AKRemoteCommand) -> Bool {
        let key = command.hashKey
        return commandConfigs[key]?.canBeDisabled ?? false
    }
    
    /// Checks if a command is registered in the registry.
    /// - Parameter command: Target command to check.
    /// - Returns: `true` if registered; otherwise `false`.
    public func isRegistered(_ command: AKRemoteCommand) -> Bool {
        return commandConfigs[command.hashKey] != nil
    }
    
    // MARK: - Custom Handlers
    
    /// Attaches a custom `@Sendable` action handler to a registered command.
    /// - Parameters:
    ///   - command: The remote command to attach the handler to.
    ///   - handler: Thread-safe closure invoked when the remote command event triggers.
    public func setCustomHandler(_ command: AKRemoteCommand,
                                 handler: @escaping AKRemoteCommandHandler) {
        guard isRegistered(command) else { return }
        
        let key = command.hashKey
        customHandlers[command] = handler
        
        if var config = commandConfigs[key] {
            config.customHandler = handler
            commandConfigs[key] = config
        }
    }
    
    /// Removes the custom handler assigned to a command.
    /// - Parameter command: Target command whose handler should be removed.
    public func removeCustomHandler(_ command: AKRemoteCommand) {
        customHandlers.removeValue(forKey: command)
        
        let key = command.hashKey
        if var config = commandConfigs[key] {
            config.customHandler = nil
            commandConfigs[key] = config
        }
    }
    
    /// Retrieves the assigned custom handler for a command if available.
    /// - Parameter command: Target command to query.
    /// - Returns: The registered closure handler, or `nil` if none exists.
    public func customHandler(for command: AKRemoteCommand) -> AKRemoteCommandHandler? {
        return customHandlers[command]
    }
    
    // MARK: - Query Operations
    
    /// Retrieves all currently registered remote commands.
    /// - Returns: An array of `AKRemoteCommand` objects held in the registry.
    public func allRegisteredCommands() -> [AKRemoteCommand] {
        return Array(commandConfigs.values.map { $0.command })
    }
    
    /// Retrieves all currently enabled remote commands.
    /// - Returns: Filtered array containing only enabled `AKRemoteCommand` targets.
    public func enabledCommands() -> [AKRemoteCommand] {
        return commandConfigs.values
            .filter { $0.isEnabled }
            .map { $0.command }
    }
    
    /// Retrieves all currently disabled remote commands.
    /// - Returns: Filtered array containing only disabled `AKRemoteCommand` targets.
    public func disabledCommands() -> [AKRemoteCommand] {
        return commandConfigs.values
            .filter { !$0.isEnabled }
            .map { $0.command }
    }
    
    // MARK: - Execution Tracking
    
    /// Records command execution timestamp and increments the run count for analytics.
    /// - Parameter command: The remote command being executed.
    public func recordExecution(for command: AKRemoteCommand) {
        let key = command.hashKey
        if var state = commandStates[key] {
            state.lastExecutedDate = Date()
            state.executionCount += 1
            commandStates[key] = state
        }
    }
    
    /// Retrieves execution statistics for a given command.
    /// - Parameter command: Target remote command to query.
    /// - Returns: Tuple containing execution count and last executed date, or `nil` if unregistered.
    public func executionInfo(for command: AKRemoteCommand) -> (count: Int, lastExecuted: Date?)? {
        guard let state = commandStates[command.hashKey] else { return nil }
        return (count: state.executionCount, lastExecuted: state.lastExecutedDate)
    }
    
    // MARK: - Cleanup
    
    /// Resets the registry, purging all stored configs, active states, and custom handlers.
    public func clear() {
        commandConfigs.removeAll()
        commandStates.removeAll()
        customHandlers.removeAll()
    }
}

// MARK: - Actor Integration Extensions

extension AKNowPlayingCommandRegistry {
    
    /// Applies a complete `AKNowPlayingCommandConfiguration` snapshot to this registry actor.
    /// - Parameter configuration: The configuration object to apply.
    public func apply(configuration: AKNowPlayingCommandConfiguration) async {
        for command in configuration.allCommands {
            let isEnabled = configuration.isEnabled(command)
            
            // Ensure the command is registered if not already present
            if !isRegistered(command) {
                register(command, isEnabled: isEnabled)
            } else {
                if isEnabled {
                    _ = enable(command)
                } else {
                    _ = disable(command)
                }
            }
            
            // Apply custom handler if present
            if let handler = configuration.handler(for: command) {
                setCustomHandler(command, handler: handler)
            }
        }
    }
}

// MARK: - Extensions

extension AKRemoteCommand {
    /// String identifier derived from the command representation.
    var hashKey: String {
        return String(describing: self)
    }
}
