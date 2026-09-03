//
//  AKRemoteCommandController.swift
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

// MARK: - Command Event (Observable Pattern)

/// Event emitted when a remote command is received.
/// Multiple listeners can subscribe to these events.
public struct AKRemoteCommandEvent {
    public let command: AKRemoteCommand
    public let event: MPRemoteCommandEvent
    public let timestamp: Date
    
    public init(_ command: AKRemoteCommand, _ event: MPRemoteCommandEvent) {
        self.command = command
        self.event = event
        self.timestamp = Date()
    }
}

// MARK: - Event Emitter (Observable)

/// Simple event emitter/observable for remote commands.
/// Listeners register callbacks and are notified when commands occur.
public class AKRemoteCommandEventEmitter {
    
    // MARK: - Properties
    
    private var listeners: [String: [(AKRemoteCommandEvent) -> Void]] = [:]
    private let lock = NSRecursiveLock()
    
    // MARK: - Subscribe/Unsubscribe
    
    /// Subscribe to all commands
    public func subscribe(callback: @escaping (AKRemoteCommandEvent) -> Void) -> AKRemoteCommandSubscription {
        return subscribe(to: nil, callback: callback)
    }
    
    /// Subscribe to specific command
    public func subscribe(to command: AKRemoteCommand?, callback: @escaping (AKRemoteCommandEvent) -> Void) -> AKRemoteCommandSubscription {
        lock.lock()
        defer { lock.unlock() }
        
        let key = command?.id ?? "*"
        var callbacks = listeners[key] ?? []
        callbacks.append(callback)
        listeners[key] = callbacks
        
        return AKRemoteCommandSubscription { [weak self] in
            self?.unsubscribe(key: key)
        }
    }
    
    private func unsubscribe(key: String) {
        lock.lock()
        defer { lock.unlock() }
        
        listeners.removeValue(forKey: key)
    }
    
    // MARK: - Emit Events
    
    /// Emit a command event to all listeners
    public func emit(_ event: AKRemoteCommandEvent) {
        lock.lock()
        defer { lock.unlock() }
        
        // Send to "all commands" listeners (wildcard)
        listeners["*"]?.forEach { $0(event) }
        
        // Send to specific command listeners
        listeners[event.command.id]?.forEach { $0(event) }
    }
}

/// Subscription token for event listeners
public class AKRemoteCommandSubscription {
    private let unsubscribe: () -> Void
    
    init(unsubscribe: @escaping () -> Void) {
        self.unsubscribe = unsubscribe
    }
    
    deinit {
        unsubscribe()
    }
}

public protocol AKNowPlayingSessionControllerProtocol: AnyObject {
    
    var remoteCommandCenter: MPRemoteCommandCenter { get }
    var nowPlayingInfoCenter: MPNowPlayingInfoCenter { get }
    var isActive: Bool { get }
    var eventEmitter: AKRemoteCommandEventEmitter { get }
    
    func register(commands: [AKRemoteCommand])
    func unregister(commands: [AKRemoteCommand])
    func enable(commands: [AKRemoteCommand])
    func disable(commands: [AKRemoteCommand])
    func isCommandEnabled(_ command: AKRemoteCommand) -> Bool
    
    func setHandler(for command: AKRemoteCommand, handler: @escaping AKRemoteCommandHandler)
    func removeHandler(for command: AKRemoteCommand)
    
    func setNowPlayingInfo(_ metadata: AKNowPlayableMetadata?)
    func clearNowPlayingPlaybackInfo()
    
    func canBecomeActive() -> Bool
    func becomeActiveIfPossible() async -> Bool
}

public class AKNowPlayingSessionController: AKNowPlayingSessionControllerProtocol {
    
    // MARK: - Properties
    
    public private(set) var nowPlayingSession: MPNowPlayingSession?
    private let _remoteCommandCenter: MPRemoteCommandCenter
    private let _nowPlayingInfoCenter: MPNowPlayingInfoCenter
    
    public var remoteCommandCenter: MPRemoteCommandCenter {
        return nowPlayingSession?.remoteCommandCenter ?? _remoteCommandCenter
    }
    
    public var nowPlayingInfoCenter: MPNowPlayingInfoCenter {
        return nowPlayingSession?.nowPlayingInfoCenter ?? _nowPlayingInfoCenter
    }
    
    public var isActive: Bool {
        return nowPlayingSession?.isActive ?? false
    }
    
    public let eventEmitter = AKRemoteCommandEventEmitter()
    
    private var commandTargets: [String: Any] = [:]
    private var commandHandlers: [String: AKRemoteCommandHandler] = [:]
    
    // MARK: - Initialization & Deinitialization
    
    public init(players: [AVPlayer]) {
        let session = MPNowPlayingSession(players: players)
        self.nowPlayingSession = session
        self._remoteCommandCenter = session.remoteCommandCenter
        self._nowPlayingInfoCenter = session.nowPlayingInfoCenter
    }
    
    public init(remoteCommandCenter: MPRemoteCommandCenter = .shared(),
                nowPlayingInfoCenter: MPNowPlayingInfoCenter = .default()) {
        self.nowPlayingSession = nil
        self._remoteCommandCenter = remoteCommandCenter
        self._nowPlayingInfoCenter = nowPlayingInfoCenter
    }
    
    deinit {
        unregister(commands: AKRemoteCommand.all())
        clearNowPlayingPlaybackInfo()
    }
    
    // MARK: - Player Management
    
    public func addPlayer(_ player: AVPlayer) {
        nowPlayingSession?.addPlayer(player)
    }
    
    public func removePlayer(_ player: AVPlayer) {
        nowPlayingSession?.removePlayer(player)
    }
    
    public func canBecomeActive() -> Bool {
        return nowPlayingSession?.canBecomeActive ?? true
    }
    
    public func becomeActiveIfPossible() async -> Bool {
        guard let session = nowPlayingSession else { return true }
        return await session.becomeActiveIfPossible()
    }
    
    // MARK: - Custom Handlers
    
    public func setHandler(for command: AKRemoteCommand, handler: @escaping AKRemoteCommandHandler) {
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
        case .skipBackward(let intervals):
            remoteCommandCenter.skipBackwardCommand.preferredIntervals = intervals
        case .skipForward(let intervals):
            remoteCommandCenter.skipForwardCommand.preferredIntervals = intervals
        case .changePlaybackRate(let rates):
            remoteCommandCenter.changePlaybackRateCommand.supportedPlaybackRates = rates
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
        guard let keyPath = command.metadata.keyPath as? KeyPath<MPRemoteCommandCenter, MPRemoteCommand> else { return false }
        return remoteCommandCenter[keyPath: keyPath].isEnabled
    }
    
    private func setCommandEnabled(_ enabled: Bool, for command: AKRemoteCommand) {
        guard let keyPath = command.metadata.keyPath as? KeyPath<MPRemoteCommandCenter, MPRemoteCommand> else { return }
        remoteCommandCenter[keyPath: keyPath].isEnabled = enabled
    }
    
    // MARK: - Metadata Management
    
    public func setNowPlayingInfo(_ metadata: AKNowPlayableMetadata?) {
        guard let metadata = metadata,
              let nowPlayingInfo = metadata.getNowPlayingInfo() else {
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
        guard let keyPath = command.metadata.keyPath as? PartialKeyPath<MPRemoteCommandCenter> else {
            return NSNull()
        }
        
        guard let remoteCommand = remoteCommandCenter[keyPath: keyPath] as? MPRemoteCommand else {
            return NSNull()
        }
        
        let handler: (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus = { [weak self] event in
            return self?.handleCommand(command, event: event) ?? .commandFailed
        }
        
        return remoteCommand.addTarget(handler: handler)
    }
    
    private func removeTarget(_ target: Any, for command: AKRemoteCommand) {
        guard let keyPath = command.metadata.keyPath as? PartialKeyPath<MPRemoteCommandCenter>,
              let remoteCommand = remoteCommandCenter[keyPath: keyPath] as? MPRemoteCommand else {
            return
        }
        remoteCommand.removeTarget(target)
    }
    
    // MARK: - Command Handler
    
    private func handleCommand(_ command: AKRemoteCommand, event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        if let customHandler = commandHandlers[command.id] {
            let result = customHandler(event)
            eventEmitter.emit(AKRemoteCommandEvent(command, event))
            return result
        }
        
        let commandEvent = AKRemoteCommandEvent(command, event)
        eventEmitter.emit(commandEvent)
        
        return .success
    }
}
