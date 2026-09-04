//
//  AKBaseState.swift
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

import AVFoundation
import Combine
import Foundation
import Network

// MARK: - AKPlayerAction

/// Enumeration representing actionable playback intents evaluated by player state machine preflight checks.
public enum AKPlayerAction: Equatable {
    case load
    case play
    case pause
    case stop
    case seek(to: AKSeekTarget)
    case step(by: Int)
    case fastForward
    case rewind
}

// MARK: - AKBaseState

/// Base class for player states implementing state machine logic, preflight validation checks, and action handling.
@MainActor
public class AKBaseState: AKPlayerStateControllerProtocol {
    
    // MARK: - Properties
    
    /// Unowned reference to the parent player controller context.
    unowned public let playerController: any AKPlayerControllerProtocol
    
    /// The explicit player state represented by this class instance.
    public let state: AKPlayerState
    
    // MARK: - Initialization
    
    /// Initializes a base state instance associated with a specific player controller and state classification.
    /// - Parameters:
    ///   - playerController: The target player controller executing playback commands.
    ///   - state: The concrete player state classification represented by this instance.
    public init(playerController: any AKPlayerControllerProtocol, state: AKPlayerState) {
        self.playerController = playerController
        self.state = state
    }
    
    deinit { }
    
    /// Called when the player transitions into this state. Concrete state subclasses override to perform setup.
    public func processStateChange() {
        // Default no-op; internal state implementations may override
    }
    
    // MARK: - Commands
    
    /// Initiates loading of a new playable media item into the player pipeline.
    /// - Parameters:
    ///   - media: The playable media target.
    ///   - autoPlay: Controls whether playback should automatically start when media is ready.
    ///   - position: An optional initial seek target position to apply on load.
    public func load(
        media: any AKPlayable,
        autoPlay: Bool,
        at position: AKSeekTarget?
    ) {
        startLoad(media: media, autoPlay: autoPlay, at: position)
    }
    
    /// Commands the player to begin media playback.
    public func play() {
        performIfAllowed(
            check: { [unowned self] in
                availability(for: .play)
            },
            action: { [weak self] in
                guard let self else { return }
                let controller = AKBufferingState(
                    playerController: playerController,
                    autoPlay: true
                )
                change(controller)
            },
            blocked: { [weak self] reason in
                guard let self else { return }
                playerController.delegate?.playerController(playerController, didEncounterUnavailableAction: reason)
            },
            fallback: ()
        )
    }
    
    /// Commands the player to begin media playback at a specified speed multiplier.
    /// - Parameter rate: The targeted playback rate.
    public func play(at rate: AKPlaybackRate) {
        performIfAllowed(
            check: { [unowned self] in
                availability(for: .play)
            },
            action: { [weak self] in
                guard let self else { return }
                let controller = AKBufferingState(
                    playerController: playerController,
                    autoPlay: true,
                    rate: rate
                )
                change(controller)
            },
            blocked: { [weak self] reason in
                guard let self else { return }
                playerController.delegate?.playerController(playerController, didEncounterUnavailableAction: reason)
            },
            fallback: ()
        )
    }
    
    /// Commands the player to pause active media playback.
    public func pause() {
        performIfAllowed(
            check: { [unowned self] in
                availability(for: .pause)
            },
            action: { [weak self] in
                guard let self else { return }
                let controller = AKPausedState(playerController: playerController)
                change(controller)
            },
            blocked: { [weak self] reason in
                guard let self else { return }
                playerController.delegate?.playerController(playerController, didEncounterUnavailableAction: reason)
            },
            fallback: ()
        )
    }
    
    /// Toggles between play and pause states depending on current active playback state.
    public func togglePlayPause() {
        if state.isPlaying || autoPlay {
            pause()
        } else {
            play()
        }
    }
    
    /// Stops playback and tears down active player pipeline.
    public func stop() {
        performIfAllowed(
            check: { [unowned self] in
                availability(for: .stop)
            },
            action: { [weak self] in
                guard let self else { return }
                beforeStop()
                let controller = AKStoppedState(playerController: playerController)
                change(controller)
            },
            blocked: { [weak self] reason in
                guard let self else { return }
                playerController.delegate?.playerController(playerController, didEncounterUnavailableAction: reason)
            },
            fallback: ()
        )
    }
    
    /// Asynchronously seeks to a given target position within current media.
    /// - Parameter target: The target position (`.time`, `.seconds`, `.offset`, `.percentage`, or `.date`).
    /// - Returns: `true` if the seek command was accepted and successfully executed; `false` otherwise.
    @discardableResult
    public func seek(to target: AKSeekTarget) async -> Bool {
        await performIfAllowed(
            check: { [unowned self] in
                availability(for: .seek(to: target))
            },
            action: { [weak self] in
                guard let self else { return false }
                let controller = AKBufferingState(
                    playerController: playerController,
                    autoPlay: state.isPlaying || autoPlay
                )
                let success = await controller.seek(to: target)
                change(controller)
                return success
            },
            blocked: { [weak self] reason in
                guard let self else { return }
                playerController.delegate?.playerController(playerController, didEncounterUnavailableAction: reason)
            },
            fallback: false
        )
    }
    
    /// Asynchronously seeks to a given target position with explicit tolerance parameters.
    /// - Parameters:
    ///   - target: The target position.
    ///   - toleranceBefore: Acceptable time offset before the target.
    ///   - toleranceAfter: Acceptable time offset after the target.
    /// - Returns: `true` if the seek command was accepted and successfully executed; `false` otherwise.
    @discardableResult
    public func seek(
        to target: AKSeekTarget,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime
    ) async -> Bool {
        await performIfAllowed(
            check: { [unowned self] in
                availability(for: .seek(to: target))
            },
            action: { [weak self] in
                guard let self else { return false }
                let controller = AKBufferingState(
                    playerController: playerController,
                    autoPlay: state.isPlaying || autoPlay
                )
                let success = await controller.seek(
                    to: target,
                    toleranceBefore: toleranceBefore,
                    toleranceAfter: toleranceAfter
                )
                change(controller)
                return success
            },
            blocked: { [weak self] reason in
                guard let self else { return }
                playerController.delegate?.playerController(playerController, didEncounterUnavailableAction: reason)
            },
            fallback: false
        )
    }
    
    /// Steps frame-by-frame through video media by a specified frame count offset.
    /// - Parameter count: The frame offset count (positive for forward, negative for reverse).
    public func step(by count: Int) {
        performIfAllowed(
            check: { [unowned self] in
                availability(for: .step(by: count))
            },
            action: { [weak self] in
                guard let self else { return }
                playerController.performStep(by: count)
            },
            blocked: { [weak self] reason in
                guard let self else { return }
                playerController.delegate?.playerController(playerController, didEncounterUnavailableAction: reason)
            },
            fallback: ()
        )
    }
    
    /// Fast-forwards playback using default fast-forward speed defined in player configuration.
    public func fastForward() {
        play(at: playerController.configuration.fastForwardRate)
    }
    
    /// Fast-forwards playback at a custom speed multiplier.
    /// - Parameter rate: The target fast-forward playback speed rate.
    public func fastForward(at rate: AKPlaybackRate) {
        play(at: rate)
    }
    
    /// Rewinds playback using default rewind speed defined in player configuration.
    public func rewind() {
        play(at: playerController.configuration.rewindRate)
    }
    
    /// Rewinds playback at a custom speed multiplier.
    /// - Parameter rate: The target rewind playback speed rate.
    public func rewind(at rate: AKPlaybackRate) {
        play(at: rate)
    }
    
    // MARK: - State Management Helpers
    
    /// Transitions the state machine context to a new target state instance.
    /// - Parameter controller: The target state controller to activate.
    public func change(_ controller: AKPlayerStateControllerProtocol) {
        beforeStateChange()
        playerController.change(controller)
        afterStateChange()
    }
    
    /// Validates an action requirement and executes an asynchronous task if permission check succeeds.
    /// - Parameters:
    ///   - check: Preflight verification closure evaluating action permission and returning blocking reasons on failure.
    ///   - action: Asynchronous operation closure executed if permission check succeeds.
    ///   - blocked: Closure called on preflight failure with the associated reason.
    ///   - fallback: Fallback value returned when action execution is blocked or prohibited.
    /// - Returns: The result of `action` if allowed; otherwise, `fallback`.
    @discardableResult
    public func performIfAllowed<T: Sendable>(
        check: @MainActor () -> (Bool, AKPlayerUnavailableCommandReason?),
        action: @MainActor () async -> T,
        blocked: (@MainActor (AKPlayerUnavailableCommandReason) -> Void)? = nil,
        fallback: T
    ) async -> T {
        let (allowed, reason) = check()
        guard allowed else {
            if let reason {
                blocked?(reason)
            }
            return fallback
        }
        
        return await action()
    }
    
    /// Validates an action requirement and executes a synchronous task if permission check succeeds.
    /// - Parameters:
    ///   - check: Preflight verification closure evaluating action permission and returning blocking reasons on failure.
    ///   - action: Synchronous operation closure executed if permission check succeeds.
    ///   - blocked: Closure called on preflight failure with the associated reason.
    ///   - fallback: Fallback value returned when action execution is blocked or prohibited.
    /// - Returns: The result of `action` if allowed; otherwise, `fallback`.
    @discardableResult
    public func performIfAllowed<T: Sendable>(
        check: @MainActor () -> (Bool, AKPlayerUnavailableCommandReason?),
        action: @MainActor () -> T,
        blocked: (@MainActor (AKPlayerUnavailableCommandReason) -> Void)? = nil,
        fallback: T
    ) -> T {
        let (allowed, reason) = check()
        guard allowed else {
            if let reason {
                blocked?(reason)
            }
            return fallback
        }
        
        return action()
    }
    
    /// Evaluates preflight permission and unavailable reasons for a given player action.
    /// - Parameter action: The candidate action to evaluate.
    /// - Returns: A tuple containing a boolean flag indicating if allowed, and an optional unavailability reason.
    public func availability(for action: AKPlayerAction) -> (allowed: Bool, reason: AKPlayerUnavailableCommandReason?) {
        switch action {
        case .seek(to: let target):
            guard let currentMedia = playerController.currentMedia else {
                return (false, .loadMediaFirst)
            }
            
            let (flag, reason) = currentMedia.seekingThroughMedia.canSeek(to: target)
            return (allowed: flag, reason: reason)
            
        case .step(by: let count):
            guard let currentMedia = playerController.currentMedia else {
                return (false, .loadMediaFirst)
            }
            
            let result = currentMedia.canStep(by: count)
            return (
                allowed: result,
                reason: result
                ? nil
                : (count > 0 ? .canNotStepForward : .canNotStepBackward)
            )
            
        default:
            return (true, nil)
        }
    }
    
    /// Subscribes to system network status changes to inform streaming decisions.
    /// - Parameters:
    ///   - subscriptions: The set of `AnyCancellable` storing active Combine subscriptions.
    ///   - handler: Closure invoked when network connectivity status changes.
    public func observeNetworkStatus(
        in subscriptions: inout Set<AnyCancellable>,
        handler: @escaping (NWPath.Status) -> Void
    ) {
        guard let currentMedia = playerController.currentMedia, currentMedia.isOverNetwork() else {
            return
        }
        
        playerController.networkStatusMonitor.networkStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { status in
                handler(status)
            }
            .store(in: &subscriptions)
    }
    
    // MARK: - Private Pipeline
    
    /// Internal helper method executing pre-load lifecycle hooks and constructing initial loading state.
    /// - Parameters:
    ///   - media: The playable media item to load.
    ///   - autoPlay: Whether playback should start automatically upon load completion.
    ///   - position: An optional seek target position to apply once loading completes.
    private func startLoad(media: any AKPlayable, autoPlay: Bool, at position: AKSeekTarget?) {
        beforeLoad(media: media, autoPlay: autoPlay, position: position)
        let controller = AKLoadingState(
            playerController: playerController,
            media: media,
            autoPlay: autoPlay,
            position: position
        )
        change(controller)
    }
    
    // MARK: - Lifecycle Hooks
    
    /// Hook executed immediately prior to starting media loading.
    /// - Parameters:
    ///   - media: The media item being loaded.
    ///   - autoPlay: Controls whether playback starts automatically upon load completion.
    ///   - position: The optional initial seek target position.
    public func beforeLoad(media: any AKPlayable, autoPlay: Bool, position: AKSeekTarget?) { }
    
    /// Hook executed immediately prior to stopping media playback.
    public func beforeStop() { }
    
    /// Hook executed immediately prior to performing state transitions.
    public func beforeStateChange() { }
    
    /// Hook executed immediately after state transitions complete.
    public func afterStateChange() { }
}
