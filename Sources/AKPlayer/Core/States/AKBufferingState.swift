//
//  AKBufferingState.swift
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

// MARK: - AKBufferingState

/// Concrete state representing active media buffering prior to starting or resuming playback.
@MainActor
public class AKBufferingState: AKBaseState {
    
    // MARK: - Properties
    
    /// Optional target playback speed multiplier.
    private var rate: AKPlaybackRate?
    
    /// Indicates whether playback should start automatically once buffer readiness is met.
    public private(set) var autoPlay: Bool
    
    /// The player state to transition into after buffering resolves if not autoplaying.
    private var stateToNavigateAfterBuffering: AKPlayerState
    
    /// Optional pending seek command to process during buffering.
    private var targetSeek: AKSeek?
    
    /// Flag indicating whether the buffering state lifecycle has become fully active.
    private var isActiveState: Bool = false
    
    /// Task tracking the buffering timeout countdown.
    private var timeoutTask: Task<Void, Never>?
    
    /// Container holding reactive Combine event subscriptions. Marked `nonisolated(unsafe)` for safe disposal in `deinit`.
    private nonisolated(unsafe) var subscriptions = Set<AnyCancellable>()
    
    // MARK: - Init & Deinit
    
    /// Initializes a buffering state instance.
    /// - Parameters:
    ///   - playerController: The underlying player controller driving execution.
    ///   - autoPlay: Whether playback should start automatically once buffer readiness is met.
    ///   - rate: Optional target playback speed multiplier.
    ///   - stateToNavigateAfterBuffering: State to transition into after buffering resolves if not autoplaying.
    ///   - targetSeek: Optional pending seek command to process during buffering.
    public init(
        playerController: any AKPlayerControllerProtocol,
        autoPlay: Bool = false,
        rate: AKPlaybackRate? = nil,
        stateToNavigateAfterBuffering: AKPlayerState? = nil,
        targetSeek: AKSeek? = nil
    ) {
        self.stateToNavigateAfterBuffering = stateToNavigateAfterBuffering ?? playerController.state
        self.autoPlay = autoPlay
        self.rate = rate
        self.targetSeek = targetSeek
        super.init(playerController: playerController, state: .buffering)
        
        print("Init called from: \(#file):\(#function):\(#line)")
    }
    
    deinit {
        subscriptions.removeAll()
        timeoutTask?.cancel()
        print("Deinit called from: \(#file):\(#function):\(#line)")
    }
    
    // MARK: - Lifecycle Hooks
    
    /// Called when the player transitions into this buffering state, setting up observation streams and handling pending operations.
    public override func processStateChange() {
        guard let currentMedia = playerController.currentMedia else {
            stop()
            return
        }
        
        startObservingPlayerStatus()
        playerController.performPause()
        
        if let targetSeek {
            playerController.performSeek(to: targetSeek)
        }
        
        startObservingPlayerItemBufferingStatus()
        startObservingPlayerItemNotifications()
        startBufferTimeoutWatcher()
        
        if currentMedia.isOverNetwork() {
            observeNetworkChanges()
        }
        
        isActiveState = true
    }
    
    // MARK: - Commands
    
    /// Commands the player to begin media playback, or updates autoplay status if already buffering.
    public override func play() {
        if autoPlay {
            playerController.delegate?.playerController(
                playerController,
                didEncounterUnavailableAction: .alreadyTryingToPlay
            )
        } else {
            self.autoPlay = true
            startPlayingIfPossible()
        }
    }
    
    /// Commands the player to begin media playback at a specified speed multiplier while buffering.
    /// - Parameter rate: The targeted playback rate.
    public override func play(at rate: AKPlaybackRate) {
        guard let currentMedia = playerController.currentMedia,
              currentMedia.canPlay(at: rate) else {
            playerController.delegate?.playerController(
                playerController,
                didEncounterUnavailableAction: .canNotPlayAtSpecifiedRate
            )
            return
        }
        self.rate = rate
        autoPlay = true
        startPlayingIfPossible()
    }
    
    // MARK: - Async Seek Handlers
    
    /// Asynchronously seeks to a given target position while buffering, using a completion handler callback.
    /// - Parameters:
    ///   - target: The destination target (`.time`, `.seconds`, `.offset`, or `.percentage`).
    ///   - completionHandler: A callback invoked when the seek operation completes or is canceled, receiving a boolean indicating success.
    public override func seek(
        to target: AKSeekTarget,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        targetSeek = AKSeek(
            target: target,
            completionHandler: completionHandler
        )
        performTargetSeekIfActive()
    }
    
    /// Asynchronously seeks to a given target position with custom tolerance bounds while buffering.
    /// - Parameters:
    ///   - target: The destination target (`.time`, `.seconds`, `.offset`, or `.percentage`).
    ///   - toleranceBefore: The allowable tolerance before the target time.
    ///   - toleranceAfter: The allowable tolerance after the target time.
    ///   - completionHandler: A callback invoked when the seek operation completes or is canceled, receiving a boolean indicating success.
    public override func seek(
        to target: AKSeekTarget,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        targetSeek = AKSeek(
            target: target,
            toleranceBefore: toleranceBefore,
            toleranceAfter: toleranceAfter,
            completionHandler: completionHandler
        )
        performTargetSeekIfActive()
    }
    
    // MARK: - Additional Helper Functions
    
    /// Observes general player errors and time control status changes.
    private func startObservingPlayerStatus() {
        playerController.player.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self, status == .failed else { return }
                let controller = AKFailedState(
                    playerController: self.playerController,
                    error: .playerCanNoLongerPlay(error: self.playerController.player.error)
                )
                self.change(controller)
            }
            .store(in: &subscriptions)
        
        playerController.player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.playerController.player.currentItem == nil else { return }
                self.stop()
            }
            .store(in: &subscriptions)
    }
    
    /// Observes item-level notifications such as playback failures to end time.
    private func startObservingPlayerItemNotifications() {
        guard let playerItem = playerController.currentMedia?.playerItem else { return }
        
        NotificationCenter.default.publisher(
            for: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            guard let self,
                  let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError else { return }
            
            guard error is URLError else {
                let controller = AKFailedState(
                    playerController: self.playerController,
                    error: .playerItemFailedToPlay(reason: .failedToPlayToEndTime(error: error))
                )
                return self.change(controller)
            }
            
            let controller = AKWaitingForNetworkState(
                playerController: self.playerController,
                autoPlay: self.autoPlay,
                rate: self.rate,
                stateToNavigateAfterBuffering: self.stateToNavigateAfterBuffering,
                targetSeek: self.targetSeek
            )
            self.change(controller)
        }
        .store(in: &subscriptions)
    }
    
    /// Observes item-level buffering status publishers to resolve buffer readiness.
    private func startObservingPlayerItemBufferingStatus() {
        guard let playerItem = playerController.currentMedia?.playerItem else { return }
        
        Publishers.CombineLatest(
            playerItem.publisher(for: \.isPlaybackBufferFull, options: [.initial, .new]),
            playerItem.publisher(for: \.isPlaybackLikelyToKeepUp, options: [.initial, .new])
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            guard let self else { return }
            if self.autoPlay {
                self.startPlayingIfPossible()
            } else {
                self.changeToPreviousState()
            }
        }
        .store(in: &subscriptions)
    }
    
    /// Starts a timeout watcher to handle buffering stalls or switch to network waiting state if threshold is exceeded.
    private func startBufferTimeoutWatcher() {
        timeoutTask?.cancel()
        
        let timeout = playerController.configuration.bufferObservingTimeout
        let interval = playerController.configuration.bufferObservingTimeInterval
        let totalSteps = Int(timeout / interval)
        
        timeoutTask = Task { @MainActor [weak self] in
            for _ in 0..<totalSteps {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard let self, !Task.isCancelled else { return }
                
                if self.autoPlay {
                    self.startPlayingIfPossible()
                } else {
                    self.changeToPreviousState()
                }
            }
            
            guard let self, !Task.isCancelled else { return }
            let controller = AKWaitingForNetworkState(
                playerController: self.playerController,
                autoPlay: self.autoPlay,
                rate: self.rate,
                stateToNavigateAfterBuffering: self.stateToNavigateAfterBuffering,
                targetSeek: self.targetSeek
            )
            self.change(controller)
        }
    }
    
    /// Restarts the buffer timeout watcher task.
    private func restartBufferTimeoutWatcher() {
        startBufferTimeoutWatcher()
    }
    
    /// Transitions back to the designated post-buffering state if conditions are met.
    private func changeToPreviousState() {
        guard let playerItem = playerController.currentMedia?.playerItem,
              !playerController.isSeeking,
              (playerItem.isPlaybackBufferFull || playerItem.isPlaybackLikelyToKeepUp) else { return }
        
        switch stateToNavigateAfterBuffering {
        case .loaded:
            let controller = AKLoadedState(playerController: playerController, rate: rate)
            change(controller)
        case .paused:
            let controller = AKPausedState(playerController: playerController)
            change(controller)
        default:
            break
        }
    }
    
    /// Evaluates if the player item is ready to begin or resume playback.
    /// - Returns: `true` if the buffer is full or likely to keep up and seeking is not active; otherwise, `false`.
    private func canPlay() -> Bool {
        guard let playerItem = playerController.currentMedia?.playerItem,
              !playerController.isSeeking,
              (playerItem.isPlaybackBufferFull || playerItem.isPlaybackLikelyToKeepUp) else { return false }
        return true
    }
    
    /// Transitions the player state to active playback if buffer readiness is satisfied.
    private func startPlayingIfPossible() {
        guard canPlay() else { return }
        let controller = AKPlayingState(playerController: playerController, rate: rate)
        change(controller)
    }
    
    /// Observes network path changes to handle connectivity loss during buffering.
    private func observeNetworkChanges() {
        observeNetworkStatus(in: &subscriptions) { [weak self] status in
            guard let self, status != .satisfied else { return }
            
            let controller = AKWaitingForNetworkState(
                playerController: self.playerController,
                autoPlay: self.autoPlay,
                rate: self.rate,
                stateToNavigateAfterBuffering: self.stateToNavigateAfterBuffering,
                targetSeek: self.targetSeek
            )
            self.change(controller)
        }
    }
    
    /// Performs the pending target seek if the state is active and a seek token exists.
    private func performTargetSeekIfActive() {
        guard isActiveState, let targetSeek else { return }
        playerController.performSeek(to: targetSeek)
        restartBufferTimeoutWatcher()
    }
    
    /// Hook executed immediately prior to changing state, cleaning up active subscriptions and tasks.
    public override func beforeStateChange() {
        subscriptions.removeAll()
        timeoutTask?.cancel()
        timeoutTask = nil
    }
}
