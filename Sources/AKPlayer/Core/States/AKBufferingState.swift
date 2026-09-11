//
//   AKBufferingState.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Combine

// MARK: - AKBufferingState

/// Concrete state representing active media buffering prior to starting or
/// resuming playback.
@MainActor
public class AKBufferingState: AKBaseState {
    // MARK: - Properties
    
    /// Optional target playback speed multiplier to apply once buffering
    /// completes.
    private var rate: AKPlaybackRate?
    
    /// Indicates whether playback should start automatically once buffer
    /// readiness is met.
    public private(set) var autoPlay: Bool
    
    /// The player state to transition into after buffering resolves if autoPlay
    /// is false.
    private var stateToNavigateAfterBuffering: AKPlayerState
    
    /// Optional pending seek command to process during or immediately after
    /// buffering.
    private var targetSeek: AKSeek?
    
    /// Flag indicating whether the buffering state lifecycle has become fully
    /// active after initialization.
    private var isActiveState = false
    
    /// Guard flag to prevent duplicate state transitions during asynchronous
    /// completion steps.
    private var hasTransitioned = false
    
    /// Task tracking the active buffering timeout countdown loop.
    private var timeoutTask: Task<Void, Never>?
    
    /// Container holding reactive Combine event subscriptions (strictly
    /// MainActor isolated).
    private var subscriptions = Set<AnyCancellable>()
    
    // MARK: - Init & Deinit
    
    /// Initializes a buffering state instance.
    /// - Parameters:
    ///   - playerController: The underlying player controller driving
    /// execution.
    ///   - autoPlay: Whether playback should start automatically once buffer
    /// readiness is met.
    ///   - rate: Optional target playback speed multiplier.
    ///   - stateToNavigateAfterBuffering: State to transition into after
    /// buffering resolves if autoPlay is false.
    ///   - targetSeek: Optional pending seek command to process during
    /// buffering.
    public init(
        playerController: any AKPlayerControllerProtocol,
        autoPlay: Bool = false,
        rate: AKPlaybackRate? = nil,
        stateToNavigateAfterBuffering: AKPlayerState? = nil,
        targetSeek: AKSeek? = nil
    ) {
        defer {
            AKLogger.logInit(self)
        }
        self.stateToNavigateAfterBuffering = stateToNavigateAfterBuffering ?? playerController.state
        self.autoPlay = autoPlay
        self.rate = rate
        self.targetSeek = targetSeek
        super.init(playerController: playerController, state: .buffering)
    }
    
    deinit {
        defer {
            AKLogger.logDeinit(
                String(describing: Self.self),
                pointer: Unmanaged.passUnretained(self)
            )
        }
    }
    
    // MARK: - Lifecycle Hooks
    
    /// Called when the player transitions into this state, setting up
    /// observation streams, handling pauses, pending seeks, and network
    /// monitoring.
    override public func processStateChange() {
        guard let currentMedia = playerController.currentMedia else {
            stop()
            return
        }
        
        isActiveState = true
        
        if !playerController.player.timeControlStatus.isPaused && !autoPlay {
            playerController.performPause()
        }
        
        if let targetSeek {
            playerController.performSeek(to: targetSeek)
        }
        
        startObservingPlayerItemBufferingStatus()
        startObservingPlayerItemNotifications()
        startBufferTimeoutWatcher()
        
        if currentMedia.isOverNetwork() {
            observeNetworkChanges()
        }
    }
    
    // MARK: - Commands
    
    /// Commands the player to begin media playback, updating autoplay
    /// parameters if already buffering.
    override public func play() {
        if autoPlay {
            playerController
                .emit(.commandUnavailable(reason: .alreadyTryingToPlay))
        } else {
            autoPlay = true
            startPlayingIfPossible()
        }
    }
    
    /// Commands the player to begin media playback at a specified speed
    /// multiplier while buffering.
    /// - Parameter rate: The targeted playback rate.
    override public func play(at rate: AKPlaybackRate) {
        guard let currentMedia = playerController.currentMedia,
              currentMedia.canPlay(at: rate)
        else {
            playerController
                .emit(.commandUnavailable(reason: .canNotPlayAtSpecifiedRate))
            return
        }
        self.rate = rate
        autoPlay = true
        startPlayingIfPossible()
    }
    
    // MARK: - Async Seek Handlers
    
    /// Asynchronously seeks to a specified target position using structured
    /// swift concurrency.
    /// - Parameter target: The position or time offset to seek toward.
    /// - Returns: A boolean indicating whether the seek action completed
    /// successfully.
    @discardableResult
    override public func seek(to target: AKSeekTarget) async -> Bool {
        await withCheckedContinuation { con in
            seek(to: target) { finished in
                con.resume(returning: finished)
            }
        }
    }
    
    /// Asynchronously seeks to a specified target position with precise
    /// tolerances using structured concurrency.
    /// - Parameters:
    ///   - target: The position or time offset to seek toward.
    ///   - toleranceBefore: The allowed time delta before the requested
    /// position.
    ///   - toleranceAfter: The allowed time delta after the requested position.
    /// - Returns: A boolean indicating whether the seek action completed
    /// successfully.
    @discardableResult
    override public func seek(
        to target: AKSeekTarget,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime
    ) async -> Bool {
        await withCheckedContinuation { con in
            seek(
                to: target,
                toleranceBefore: toleranceBefore,
                toleranceAfter: toleranceAfter
            ) {
                finished in
                con.resume(returning: finished)
            }
        }
    }
    
    /// Seeks to a target location and executes a callback upon completion.
    /// - Parameters:
    ///   - target: The position or time offset to seek toward.
    ///   - completionHandler: Closure called with `true` if the seek finished
    /// or `false` if cancelled.
    override public func seek(
        to target: AKSeekTarget,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        performIfAllowed(
            check: { [unowned self] in
                availability(for: .seek(to: target))
            },
            action: { [weak self] in
                guard let s = self else {
                    completionHandler(false)
                    return
                }
                let seekToken = AKSeek(
                    target: target,
                    completionHandler: completionHandler
                )
                s.targetSeek = seekToken
                s.performTargetSeekIfActive()
                s.restartBufferTimeoutWatcher()
            },
            blocked: { [weak self] reason in
                completionHandler(false)
                guard let self else { return }
                playerController.emit(.commandUnavailable(reason: reason))
            },
            fallback: ()
        )
    }
    
    /// Seeks to a target position using tolerance limits and invokes a
    /// completion closure.
    /// - Parameters:
    ///   - target: The position or time offset to seek toward.
    ///   - toleranceBefore: Maximum allowed offset prior to target time.
    ///   - toleranceAfter: Maximum allowed offset after target time.
    ///   - completionHandler: Closure called upon seek completion with success
    /// state.
    override public func seek(
        to target: AKSeekTarget,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime,
        completionHandler: @Sendable @escaping (Bool) -> Void
    ) {
        performIfAllowed(
            check: { [unowned self] in
                availability(for: .seek(to: target))
            },
            action: { [weak self] in
                guard let s = self else {
                    completionHandler(false)
                    return
                }
                let seekToken = AKSeek(
                    target: target,
                    toleranceBefore: toleranceBefore,
                    toleranceAfter: toleranceAfter,
                    completionHandler: completionHandler
                )
                s.targetSeek = seekToken
                s.performTargetSeekIfActive()
                s.restartBufferTimeoutWatcher()
            },
            blocked: { [weak self] reason in
                completionHandler(false)
                guard let s = self else { return }
                s.playerController.emit(.commandUnavailable(reason: reason))
            },
            fallback: ()
        )
    }
    
    // MARK: - Additional Helper Functions
    
    public override func handlePlayerStatusChange(_ status: AVPlayer.Status) {
        guard !hasTransitioned, status == .failed
        else { return }
        hasTransitioned = true
        let controller = AKFailedState(
            playerController: playerController,
            error: .playerCanNoLongerPlay(
                error: playerController.player
                    .error
            )
        )
        change(controller)
    }
    
    public override func handleTimeControlStatusChange(_ status: AVPlayer.TimeControlStatus) {
        switch status {
        case .waitingToPlayAtSpecifiedRate:
            guard let reasonForWaitingToPlay = playerController.player.reasonForWaitingToPlay else { return }
            switch reasonForWaitingToPlay {
            case .noItemToPlay:
                stop()
            default:
                break
            }
        default:
            break
        }
    }
    
    /// Subscribes to player item notification publishers to detect item errors
    /// (e.g. playback failures).
    private func startObservingPlayerItemNotifications() {
        guard let playerItem = playerController.currentMedia?.playerItem
        else { return }
        
        NotificationCenter.default.publisher(
            for: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            guard let self, !self.hasTransitioned,
                  let error = notification
                .userInfo?[
                    AVPlayerItemFailedToPlayToEndTimeErrorKey
                ] as? NSError
            else { return }
            
            hasTransitioned = true
            guard error is URLError else {
                let controller = AKFailedState(
                    playerController: playerController,
                    error: .playerItemFailedToPlay(
                        reason: .failedToPlayToEndTime(error: error)
                    )
                )
                return change(controller)
            }
            
            let controller = AKWaitingForNetworkState(
                playerController: playerController,
                autoPlay: autoPlay,
                rate: rate,
                stateToNavigateAfterBuffering: stateToNavigateAfterBuffering,
                targetSeek: targetSeek
            )
            change(controller)
        }
        .store(in: &subscriptions)
    }
    
    /// Observes the current `AVPlayerItem` buffer state flags to transition out
    /// of buffering as soon as possible.
    private func startObservingPlayerItemBufferingStatus() {
        guard let playerItem = playerController.currentMedia?.playerItem
        else { return }
        
        Publishers.CombineLatest(
            playerItem.publisher(
                for: \.isPlaybackBufferFull,
                options: [.initial, .new]
            ),
            playerItem.publisher(
                for: \.isPlaybackLikelyToKeepUp,
                options: [.initial, .new]
            )
        )
        .sink { @MainActor [weak self] isPlaybackBufferFull, isPlaybackLikelyToKeepUp in
            guard let self, !self.hasTransitioned else { return }
            guard isPlaybackBufferFull && isPlaybackLikelyToKeepUp else {
                return
            }
            autoPlay ? startPlayingIfPossible() : changeToPreviousState()
        }
        .store(in: &subscriptions)
    }
    
    /// Starts a recurring timer task to monitor whether buffering is taking
    /// longer than configured limits.
    private func startBufferTimeoutWatcher() {
        timeoutTask?.cancel()
        
        let timeout = playerController.configuration.bufferObservingTimeout
        let interval = playerController.configuration
            .bufferObservingTimeInterval
        let totalSteps = Int(timeout / interval)
        
        timeoutTask = Task { @MainActor [weak self] in
            for _ in 0 ..< totalSteps {
                try? await Task
                    .sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard let self, !Task.isCancelled,
                      !self.hasTransitioned
                else { return }
                
                if canPlay() {
                    if autoPlay {
                        startPlayingIfPossible()
                    } else {
                        changeToPreviousState()
                    }
                    return
                }
            }
            
            guard let self, !Task.isCancelled,
                  !self.hasTransitioned
            else { return }
            hasTransitioned = true
            let controller = AKWaitingForNetworkState(
                playerController: playerController,
                autoPlay: autoPlay,
                rate: rate,
                stateToNavigateAfterBuffering: stateToNavigateAfterBuffering,
                targetSeek: targetSeek
            )
            change(controller)
        }
    }
    
    /// Cancels and restarts the buffer timeout watcher task.
    private func restartBufferTimeoutWatcher() {
        startBufferTimeoutWatcher()
    }
    
    /// Transitions back to the designated state prior to buffering if autoplay
    /// is not requested.
    private func changeToPreviousState() {
        guard !hasTransitioned,
              let playerItem = playerController.currentMedia?.playerItem,
              !playerController.isSeeking,
              playerItem.isPlaybackBufferFull
                && playerItem
            .isPlaybackLikelyToKeepUp
        else { return }
        
        hasTransitioned = true
        switch stateToNavigateAfterBuffering {
        case .loaded:
            let controller = AKLoadedState(
                playerController: playerController,
                rate: rate
            )
            change(controller)
        case .paused:
            let controller = AKPausedState(playerController: playerController)
            change(controller)
        default:
            hasTransitioned = false
        }
    }
    
    /// Determines whether the media buffer conditions are sufficient to allow
    /// playback.
    /// - Returns: `true` if the item is not seeking and either buffer is full
    /// or likely to keep up.
    private func canPlay() -> Bool {
        guard let playerItem = playerController.currentMedia?.playerItem,
              !playerController.isSeeking,
              playerItem.isPlaybackBufferFull
                && playerItem
            .isPlaybackLikelyToKeepUp
        else { return false }
        return true
    }
    
    /// Checks buffer availability and transitions into `AKPlayingState` if
    /// ready.
    private func startPlayingIfPossible() {
        guard !hasTransitioned, canPlay() else { return }
        hasTransitioned = true
        let controller = AKPlayingState(
            playerController: playerController,
            rate: rate
        )
        change(controller)
    }
    
    /// Listens for network reachability changes to drop into network waiting
    /// state if connectivity fails.
    private func observeNetworkChanges() {
        observeNetworkStatus(in: &subscriptions) { [weak self] status in
            guard let self, !self.hasTransitioned,
                  status != .satisfied
            else { return }
            
            hasTransitioned = true
            let controller = AKWaitingForNetworkState(
                playerController: playerController,
                autoPlay: autoPlay,
                rate: rate,
                stateToNavigateAfterBuffering: stateToNavigateAfterBuffering,
                targetSeek: targetSeek
            )
            change(controller)
        }
    }
    
    /// Performs the pending seek command if the state instance is active, and
    /// resets the timeout timer.
    private func performTargetSeekIfActive() {
        guard isActiveState, let targetSeek else { return }
        playerController.performSeek(to: targetSeek)
        restartBufferTimeoutWatcher()
    }
    
    /// Called immediately before transitioning out of this state to cancel
    /// tasks and clear subscriptions.
    override public func beforeStateChange() {
        hasTransitioned = true
        subscriptions.forEach({ $0.cancel() })
        subscriptions.removeAll()
        timeoutTask?.cancel()
        timeoutTask = nil
    }
}
