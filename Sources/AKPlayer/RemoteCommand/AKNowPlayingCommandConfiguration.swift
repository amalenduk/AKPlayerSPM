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

/// Builder pattern for configuring Now Playing session with predefined command sets.
public class AKNowPlayingCommandConfiguration {
    
    // MARK: - Properties
    
    private var commands: Set<AKRemoteCommand> = []
    private var commandEnablementMap: [String: Bool] = [:]
    private var customHandlers: [AKRemoteCommand: AKRemoteCommandHandler] = [:]
    
    // MARK: - Initialization & Deinitialization
    
    public init() {}
    
    // MARK: - Builder Methods
    
    /// Adds a single command to the configuration.
    @discardableResult
    public func add(_ command: AKRemoteCommand) -> Self {
        commands.insert(command)
        commandEnablementMap[command.hashKey] = true
        return self
    }
    
    /// Adds multiple commands to the configuration.
    @discardableResult
    public func add(commands: [AKRemoteCommand]) -> Self {
        commands.forEach { add($0) }
        return self
    }
    
    /// Removes a command from configuration.
    @discardableResult
    public func remove(_ command: AKRemoteCommand) -> Self {
        commands.remove(command)
        commandEnablementMap.removeValue(forKey: command.hashKey)
        return self
    }
    
    /// Removes multiple commands from configuration.
    @discardableResult
    public func remove(commands: [AKRemoteCommand]) -> Self {
        commands.forEach { remove($0) }
        return self
    }
    
    /// Applies standard audio/podcast preset (iOS 17.0+).
    @discardableResult
    public func useAudioPreset() -> Self {
        add(commands: AKRemoteCommand.standardAudioPreset)
        return self
    }
    
    /// Applies standard video preset (iOS 17.0+).
    @discardableResult
    public func useVideoPreset() -> Self {
        add(commands: AKRemoteCommand.standardVideoPreset)
        return self
    }
    
    /// Applies playback commands only.
    @discardableResult
    public func usePlaybackCommands() -> Self {
        add(commands: AKRemoteCommand.playbackCommands)
        return self
    }
    
    /// Applies track navigation commands.
    @discardableResult
    public func useTrackNavigationCommands() -> Self {
        add(commands: AKRemoteCommand.trackNavigationCommands)
        return self
    }
    
    /// Applies seeking commands with custom intervals.
    @discardableResult
    public func useSeekingCommands(intervals: [Double] = [15.0]) -> Self {
        add(commands: AKRemoteCommand.seekingCommands(intervals: intervals))
        return self
    }
    
    /// Applies feedback/rating commands.
    @discardableResult
    public func useFeedbackCommands() -> Self {
        add(commands: AKRemoteCommand.feedbackCommands)
        return self
    }
    
    /// Applies language/subtitle selection commands.
    @discardableResult
    public func useLanguageCommands() -> Self {
        add(commands: AKRemoteCommand.languageCommands)
        return self
    }
    
    /// Enables a specific command.
    @discardableResult
    public func enable(_ command: AKRemoteCommand) -> Self {
        commandEnablementMap[command.hashKey] = true
        return self
    }
    
    /// Enables multiple commands.
    @discardableResult
    public func enable(commands: [AKRemoteCommand]) -> Self {
        commands.forEach { enable($0) }
        return self
    }
    
    /// Disables a specific command.
    @discardableResult
    public func disable(_ command: AKRemoteCommand) -> Self {
        commandEnablementMap[command.hashKey] = false
        return self
    }
    
    /// Disables multiple commands.
    @discardableResult
    public func disable(commands: [AKRemoteCommand]) -> Self {
        commands.forEach { disable($0) }
        return self
    }
    
    /// Sets a custom handler for a command.
    @discardableResult
    public func setHandler(for command: AKRemoteCommand,
                           handler: @escaping AKRemoteCommandHandler) -> Self {
        customHandlers[command] = handler
        if !commands.contains(command) {
            commands.insert(command)
            commandEnablementMap[command.hashKey] = true
        }
        return self
    }
    
    /// Clears all configured commands and handlers.
    @discardableResult
    public func clear() -> Self {
        commands.removeAll()
        commandEnablementMap.removeAll()
        customHandlers.removeAll()
        return self
    }
    
    // MARK: - Query Methods
    
    /// Gets all configured commands.
    public func getCommands() -> [AKRemoteCommand] {
        return Array(commands)
    }
    
    /// Gets enabled commands.
    public func getEnabledCommands() -> [AKRemoteCommand] {
        return commands.filter { commandEnablementMap[$0.hashKey] ?? false }
    }
    
    /// Gets disabled commands.
    public func getDisabledCommands() -> [AKRemoteCommand] {
        return commands.filter { !(commandEnablementMap[$0.hashKey] ?? false) }
    }
    
    /// Gets custom handler for command if exists.
    public func getHandler(for command: AKRemoteCommand) -> AKRemoteCommandHandler? {
        return customHandlers[command]
    }
    
    /// Checks if command is enabled in this configuration.
    public func isEnabled(_ command: AKRemoteCommand) -> Bool {
        return commandEnablementMap[command.hashKey] ?? false
    }
}

// MARK: - Preset Configurations

extension AKNowPlayingCommandConfiguration {
    
    /// Creates a preset configuration for music/podcast streaming (iOS 17.0+).
    public static func audio() -> AKNowPlayingCommandConfiguration {
        return AKNowPlayingCommandConfiguration().useAudioPreset()
    }
    
    /// Creates a preset configuration for video playback (iOS 17.0+).
    public static func video() -> AKNowPlayingCommandConfiguration {
        return AKNowPlayingCommandConfiguration().useVideoPreset()
    }
    
    /// Creates a minimal configuration with only basic playback controls.
    public static func minimal() -> AKNowPlayingCommandConfiguration {
        return AKNowPlayingCommandConfiguration()
            .add(commands: [.play, .pause, .togglePlayPause])
    }
    
    /// Creates a comprehensive configuration with all available commands.
    public static func full() -> AKNowPlayingCommandConfiguration {
        return AKNowPlayingCommandConfiguration()
            .add(commands: AKRemoteCommand.all())
    }
    
    /// Creates a custom configuration starting from scratch.
    public static func custom() -> AKNowPlayingCommandConfiguration {
        return AKNowPlayingCommandConfiguration()
    }
}
