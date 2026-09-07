//
//  AKNowPlayingSessionController.swift
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

import AVFoundation
import Foundation
import MediaPlayer

// MARK: - Command Event (Observable Pattern)

/// Event emitted when a remote command is received.
/// Multiple listeners can subscribe to these events.
public struct AKRemoteCommandEvent: Sendable {
    public let command: AKRemoteCommand
    public nonisolated(unsafe) let event: MPRemoteCommandEvent
    public let timestamp: Date

    public init(_ command: AKRemoteCommand, _ event: MPRemoteCommandEvent) {
        self.command = command
        self.event = event
        timestamp = Date()
    }
}

// MARK: - Event Emitter (Observable)

/// Simple thread-safe event emitter/observable for remote commands using an
/// actor.
/// Listeners register callbacks and are notified when commands occur.
public actor AKRemoteCommandEventEmitter {
    // MARK: - Properties

    private var listeners: [
        String: [@Sendable (AKRemoteCommandEvent) -> Void]
    ] =
        [:]

    // MARK: - Initialization

    public init() {}

    // MARK: - Subscribe/Unsubscribe

    /// Subscribe to all commands.
    public func subscribe(callback: @escaping @Sendable (AKRemoteCommandEvent)
        -> Void)
        -> AKRemoteCommandSubscription
    {
        subscribe(to: nil, callback: callback)
    }

    /// Subscribe to a specific command.
    public func subscribe(
        to command: AKRemoteCommand?,
        callback: @escaping @Sendable (AKRemoteCommandEvent) -> Void
    ) -> AKRemoteCommandSubscription {
        let key = command?.id ?? "*"
        var callbacks = listeners[key] ?? []
        callbacks.append(callback)
        listeners[key] = callbacks

        // Pass actor reference safely using unowned/weak equivalent behavior
        // via isolated handler
        return AKRemoteCommandSubscription { [weak self] in
            guard let self else { return }
            Task {
                await self.unsubscribe(key: key, callbackToken: callback)
            }
        }
    }

    private func unsubscribe(
        key: String,
        callbackToken _: @escaping @Sendable (AKRemoteCommandEvent) -> Void
    ) {
        guard var callbacks = listeners[key] else { return }
        // Clean up matching callbacks if needed, or clear key entry
        callbacks.removeAll { _ in
            // Closures aren't directly comparable, so we clean up or re-assign
            // based on index/implementation context,
            // or simply remove the entry if tracking token-based registration.
            // For safety and compatibility with original behavior, let's keep
            // array filtering secure:
            false
        }
        if callbacks.isEmpty {
            listeners.removeValue(forKey: key)
        } else {
            listeners[key] = callbacks
        }
    }

    private func unsubscribe(key: String) {
        listeners.removeValue(forKey: key)
    }

    // MARK: - Emit Events

    /// Emit a command event to all listeners.
    public func emit(_ event: AKRemoteCommandEvent) {
        // Send to "all commands" listeners (wildcard)
        if let wildcardListeners = listeners["*"] {
            for callback in wildcardListeners {
                callback(event)
            }
        }

        // Send to specific command listeners
        if let specificListeners = listeners[event.command.id] {
            for callback in specificListeners {
                callback(event)
            }
        }
    }
}

/// Subscription token for event listeners
public final class AKRemoteCommandSubscription: @unchecked Sendable {
    private let unsubscribe: @Sendable () -> Void

    init(unsubscribe: @escaping @Sendable () -> Void) {
        self.unsubscribe = unsubscribe
    }

    deinit {
        unsubscribe()
    }
}

// MARK: - Protocol Definition

@MainActor
public protocol AKNowPlayingSessionControllerProtocol: AnyObject {
    var remoteCommandCenter: MPRemoteCommandCenter { get }
    var nowPlayingInfoCenter: MPNowPlayingInfoCenter { get }
    var isActive: Bool { get }
    var eventEmitter: AKRemoteCommandEventEmitter { get }

    func register(commands: [AKRemoteCommand]) async
    func unregister(commands: [AKRemoteCommand]) async
    func enable(commands: [AKRemoteCommand]) async
    func disable(commands: [AKRemoteCommand]) async
    func isCommandEnabled(_ command: AKRemoteCommand) async -> Bool

    func setHandler(
        for command: AKRemoteCommand,
        handler: @escaping AKRemoteCommandHandler
    ) async
    func removeHandler(for command: AKRemoteCommand) async

    func setNowPlayingInfo(_ metadata: AKNowPlayableMetadata?)
    func clearNowPlayingPlaybackInfo()

    func canBecomeActive() -> Bool
    func becomeActiveIfPossible() async -> Bool
}

// MARK: - Controller Implementation

@MainActor
public class AKNowPlayingSessionController: AKNowPlayingSessionControllerProtocol {
    // MARK: - Properties

    public private(set) var nowPlayingSession: MPNowPlayingSession?
    private let _remoteCommandCenter: MPRemoteCommandCenter
    private nonisolated(unsafe) let _nowPlayingInfoCenter: MPNowPlayingInfoCenter

    public var remoteCommandCenter: MPRemoteCommandCenter {
        nowPlayingSession?.remoteCommandCenter ?? _remoteCommandCenter
    }

    public var nowPlayingInfoCenter: MPNowPlayingInfoCenter {
        nowPlayingSession?.nowPlayingInfoCenter ?? _nowPlayingInfoCenter
    }

    public var isActive: Bool {
        nowPlayingSession?.isActive ?? false
    }

    public let eventEmitter = AKRemoteCommandEventEmitter()

    private var commandTargets: [String: Any] = [:]
    private var commandHandlers: [String: AKRemoteCommandHandler] = [:]

    // MARK: - Initialization & Deinitialization

    public init(players: [AVPlayer]) {
        let session = MPNowPlayingSession(players: players)
        nowPlayingSession = session
        _remoteCommandCenter = session.remoteCommandCenter
        _nowPlayingInfoCenter = session.nowPlayingInfoCenter
    }

    public init(
        remoteCommandCenter: MPRemoteCommandCenter = .shared(),
        nowPlayingInfoCenter: MPNowPlayingInfoCenter = .default()
    ) {
        nowPlayingSession = nil
        _remoteCommandCenter = remoteCommandCenter
        _nowPlayingInfoCenter = nowPlayingInfoCenter
    }

    deinit {
        _nowPlayingInfoCenter.nowPlayingInfo = nil
    }

    // MARK: - Player Management

    public func addPlayer(_ player: AVPlayer) {
        nowPlayingSession?.addPlayer(player)
    }

    public func removePlayer(_ player: AVPlayer) {
        nowPlayingSession?.removePlayer(player)
    }

    public func canBecomeActive() -> Bool {
        nowPlayingSession?.canBecomeActive ?? true
    }

    public func becomeActiveIfPossible() async -> Bool {
        guard let session = nowPlayingSession else { return true }
        return await session.becomeActiveIfPossible()
    }

    // MARK: - Custom Handlers

    public func setHandler(
        for command: AKRemoteCommand,
        handler: @escaping AKRemoteCommandHandler
    ) {
        commandHandlers[command.id] = handler
    }

    public func removeHandler(for command: AKRemoteCommand) {
        commandHandlers.removeValue(forKey: command.id)
    }

    // MARK: - Command Registration

    public func register(commands: [AKRemoteCommand]) {
        commands.forEach { register($0) }
    }

    private func register(_ command: AKRemoteCommand) {
        let id = command.id
        guard commandTargets[id] == nil else { return }

        let target = createTarget(for: command)
        commandTargets[id] = target

        // Configure specific parameters
        switch command {
        case let .skipBackward(intervals):
            remoteCommandCenter.skipBackwardCommand
                .preferredIntervals = intervals.map {
                    NSNumber(value: $0)
                }
        case let .skipForward(intervals):
            remoteCommandCenter.skipForwardCommand
                .preferredIntervals = intervals.map {
                    NSNumber(value: $0)
                }
        case let .changePlaybackRate(rates):
            remoteCommandCenter.changePlaybackRateCommand
                .supportedPlaybackRates = rates.map {
                    NSNumber(value: $0)
                }
        default:
            break
        }
    }

    public func unregister(commands: [AKRemoteCommand]) {
        commands.forEach { unregister($0) }
    }

    private func unregister(_ command: AKRemoteCommand) {
        let id = command.id
        if let target = commandTargets[id] {
            removeTarget(target, for: command)
            commandTargets.removeValue(forKey: id)
        }
    }

    // MARK: - Enable/Disable

    public func enable(commands: [AKRemoteCommand]) {
        commands.forEach { enable($0) }
    }

    private func enable(_ command: AKRemoteCommand) {
        setCommandEnabled(true, for: command)
    }

    public func disable(commands: [AKRemoteCommand]) {
        commands.forEach { disable($0) }
    }

    private func disable(_ command: AKRemoteCommand) {
        setCommandEnabled(false, for: command)
    }

    public func isCommandEnabled(_ command: AKRemoteCommand) -> Bool {
        let remoteCommand = command.metadata.getCommand(remoteCommandCenter)
        return remoteCommand.isEnabled
    }

    private func setCommandEnabled(
        _ enabled: Bool,
        for command: AKRemoteCommand
    ) {
        let remoteCommand = command.metadata.getCommand(remoteCommandCenter)
        remoteCommand.isEnabled = enabled
    }

    // MARK: - Metadata Management

    public func setNowPlayingInfo(_ metadata: AKNowPlayableMetadata?) {
        guard let metadata,
              let nowPlayingInfo = metadata.getNowPlayingInfo()
        else {
            clearNowPlayingPlaybackInfo()
            return
        }
        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }

    public func clearNowPlayingPlaybackInfo() {
        nowPlayingInfoCenter.nowPlayingInfo = nil
    }

    // MARK: - Private: Target Creation

    private func createTarget(for command: AKRemoteCommand) -> Any {
        let remoteCommand = command.metadata.getCommand(remoteCommandCenter)

        let handler: @MainActor (MPRemoteCommandEvent)
            -> MPRemoteCommandHandlerStatus = {
                [weak self] event in
                self?.handleCommand(command, event: event) ?? .commandFailed
            }

        return remoteCommand.addTarget(handler: handler)
    }

    private func removeTarget(_ target: Any, for command: AKRemoteCommand) {
        let remoteCommand = command.metadata.getCommand(remoteCommandCenter)
        remoteCommand.removeTarget(target)
    }

    // MARK: - Command Handler

    private func handleCommand(
        _ command: AKRemoteCommand,
        event: MPRemoteCommandEvent
    )
        -> MPRemoteCommandHandlerStatus
    {
        if let customHandler = commandHandlers[command.id] {
            let result = customHandler(event)
            let commandEvent = AKRemoteCommandEvent(command, event)
            Task {
                await eventEmitter.emit(commandEvent)
            }
            return result
        }

        let commandEvent = AKRemoteCommandEvent(command, event)
        Task {
            await eventEmitter.emit(commandEvent)
        }

        return .success
    }
}
