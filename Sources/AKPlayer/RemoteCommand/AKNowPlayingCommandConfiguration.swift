//
//  AKNowPlayingCommandConfiguration.swift
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

// MARK: - AKNowPlayingCommandConfiguration

/// Thread-safe builder for configuring Now Playing remote command sessions.
/// Designed as a value type (`struct`) conforming to `Sendable` using an immutable copy-on-write builder pattern.
public struct AKNowPlayingCommandConfiguration: Sendable {
    
    // MARK: - Properties
    
    /// Unique set of remote commands added to this configuration.
    private var commands: Set<AKRemoteCommand> = []
    
    /// Map tracking enablement state for registered commands indexed by command key.
    private var commandEnablementMap: [String: Bool] = [:]
    
    /// Dictionary mapping explicit remote commands to their custom handlers.
    private var customHandlers: [AKRemoteCommand: AKRemoteCommandHandler] = [:]
    
    // MARK: - Initialization
    
    /// Creates a new instance of `AKNowPlayingCommandConfiguration`.
    public init() {}
    
    // MARK: - Builder Methods
    
    /// Adds a single command to the configuration.
    /// - Parameter command: The remote command to add.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func add(_ command: AKRemoteCommand) -> Self {
        var copy = self
        copy.commands.insert(command)
        copy.commandEnablementMap[command.hashKey] = true
        return copy
    }
    
    /// Adds multiple commands to the configuration.
    /// - Parameter commands: Array of commands to add.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func add(commands: [AKRemoteCommand]) -> Self {
        var copy = self
        for command in commands {
            copy = copy.add(command)
        }
        return copy
    }
    
    /// Removes a command from the configuration.
    /// - Parameter command: Target command to remove.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func remove(_ command: AKRemoteCommand) -> Self {
        var copy = self
        copy.commands.remove(command)
        copy.commandEnablementMap.removeValue(forKey: command.hashKey)
        copy.customHandlers.removeValue(forKey: command)
        return copy
    }
    
    /// Removes multiple commands from the configuration.
    /// - Parameter commands: Array of target commands to remove.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func remove(commands: [AKRemoteCommand]) -> Self {
        var copy = self
        for command in commands {
            copy = copy.remove(command)
        }
        return copy
    }
    
    /// Applies the standard audio/podcast command preset.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func useAudioPreset() -> Self {
        return add(commands: AKRemoteCommand.standardAudioPreset)
    }
    
    /// Applies the standard video command preset.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func useVideoPreset() -> Self {
        return add(commands: AKRemoteCommand.standardVideoPreset)
    }
    
    /// Applies essential playback commands (play, pause, toggle, stop).
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func usePlaybackCommands() -> Self {
        return add(commands: AKRemoteCommand.playbackCommands)
    }
    
    /// Applies track navigation commands (next track, previous track).
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func useTrackNavigationCommands() -> Self {
        return add(commands: AKRemoteCommand.trackNavigationCommands)
    }
    
    /// Applies seeking commands with custom time skip intervals.
    /// - Parameter intervals: Time intervals in seconds for skip forward/backward commands.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func useSeekingCommands(intervals: [Double] = [15.0]) -> Self {
        return add(commands: AKRemoteCommand.seekingCommands(intervals: intervals))
    }
    
    /// Applies feedback and rating commands (like, dislike, bookmark).
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func useFeedbackCommands() -> Self {
        return add(commands: AKRemoteCommand.feedbackCommands)
    }
    
    /// Applies language and audio/subtitle selection commands.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func useLanguageCommands() -> Self {
        return add(commands: AKRemoteCommand.languageCommands)
    }
    
    /// Enables a specific command in this configuration.
    /// - Parameter command: Target command to enable.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func enable(_ command: AKRemoteCommand) -> Self {
        var copy = self
        copy.commandEnablementMap[command.hashKey] = true
        return copy
    }
    
    /// Enables multiple commands in this configuration.
    /// - Parameter commands: Array of commands to enable.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func enable(commands: [AKRemoteCommand]) -> Self {
        var copy = self
        for command in commands {
            copy = copy.enable(command)
        }
        return copy
    }
    
    /// Disables a specific command in this configuration.
    /// - Parameter command: Target command to disable.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func disable(_ command: AKRemoteCommand) -> Self {
        var copy = self
        copy.commandEnablementMap[command.hashKey] = false
        return copy
    }
    
    /// Disables multiple commands in this configuration.
    /// - Parameter commands: Array of commands to disable.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func disable(commands: [AKRemoteCommand]) -> Self {
        var copy = self
        for command in commands {
            copy = copy.disable(command)
        }
        return copy
    }
    
    /// Registers a custom `@Sendable` handler closure for a command.
    /// - Parameters:
    ///   - command: The target remote command to assign the handler to.
    ///   - handler: Concurrency-safe event handler closure.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func setHandler(for command: AKRemoteCommand,
                          handler: @escaping AKRemoteCommandHandler) -> Self {
        var copy = self
        copy.customHandlers[command] = handler
        if !copy.commands.contains(command) {
            copy.commands.insert(command)
            copy.commandEnablementMap[command.hashKey] = true
        }
        return copy
    }
    
    /// Clears all stored commands, enablement flags, and custom handlers.
    /// - Returns: Updated configuration copy instance for method chaining.
    @discardableResult
    public func clear() -> Self {
        var copy = self
        copy.commands.removeAll()
        copy.commandEnablementMap.removeAll()
        copy.customHandlers.removeAll()
        return copy
    }
    
    // MARK: - Query Methods
    
    /// Returns an array of all registered commands in this configuration.
    public var allCommands: [AKRemoteCommand] {
        return Array(commands)
    }
    
    /// Returns an array containing only currently enabled commands.
    public var enabledCommands: [AKRemoteCommand] {
        return commands.filter { commandEnablementMap[$0.hashKey] ?? false }
    }
    
    /// Returns an array containing only currently disabled commands.
    public var disabledCommands: [AKRemoteCommand] {
        return commands.filter { !(commandEnablementMap[$0.hashKey] ?? false) }
    }
    
    /// Retrieves the registered custom handler for a given command.
    /// - Parameter command: Target command to inspect.
    /// - Returns: The registered `@Sendable` handler, or `nil` if none exists.
    public func handler(for command: AKRemoteCommand) -> AKRemoteCommandHandler? {
        return customHandlers[command]
    }
    
    /// Checks whether a command is set as enabled in this configuration.
    /// - Parameter command: Target command to inspect.
    /// - Returns: `true` if configured and enabled; otherwise `false`.
    public func isEnabled(_ command: AKRemoteCommand) -> Bool {
        return commandEnablementMap[command.hashKey] ?? false
    }
}

// MARK: - Preset Configurations

extension AKNowPlayingCommandConfiguration {
    
    /// Factory creating a pre-configured audio preset instance.
    public static func audio() -> AKNowPlayingCommandConfiguration {
        let config = AKNowPlayingCommandConfiguration()
        return config.useAudioPreset()
    }
    
    /// Factory creating a pre-configured video preset instance.
    public static func video() -> AKNowPlayingCommandConfiguration {
        let config = AKNowPlayingCommandConfiguration()
        return config.useVideoPreset()
    }
    
    /// Factory creating a minimal configuration with primary playback controls (.play, .pause, .togglePlayPause).
    public static func minimal() -> AKNowPlayingCommandConfiguration {
        let config = AKNowPlayingCommandConfiguration()
        return config.add(commands: [.play, .pause, .togglePlayPause])
    }
    
    /// Factory creating a complete configuration with all available commands added.
    public static func full() -> AKNowPlayingCommandConfiguration {
        let config = AKNowPlayingCommandConfiguration()
        return config.add(commands: AKRemoteCommand.all())
    }
    
    /// Factory creating an empty configuration starting from scratch.
    public static func custom() -> AKNowPlayingCommandConfiguration {
        return AKNowPlayingCommandConfiguration()
    }
}
