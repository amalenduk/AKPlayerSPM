//
//   AKWaitingForNetworkState.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Combine

// MARK: - AKWaitingForNetworkState

/// Concrete state representing a period where playback is paused while waiting
/// for network connectivity to restore.
@MainActor
public class AKWaitingForNetworkState: AKBaseState {
    // MARK: - Properties
    
    /// Optional target playback speed multiplier to apply once network
    /// connection recovers.
    private var rate: AKPlaybackRate?
    
    /// Indicates whether playback should resume automatically when network
    /// connectivity is re-established.
    public private(set) var autoPlay = false
    
    /// The player state to transition into after buffering resolves following
    /// network restoration.
    private var stateToNavigateAfterBuffering: AKPlayerState?
    
    /// Optional pending seek command to preserve across network waiting state.
    private var targetSeek: AKSeek?
    
    /// Container holding reactive Combine event subscriptions.
    private var subscriptions = Set<AnyCancellable>()
    
    private var hasStartedPlaying = false
    
    // MARK: - Initialization & Deinitialization
    
    /// Initializes a waiting-for-network state instance.
    /// - Parameters:
    ///   - playerController: The underlying player controller driving
    /// execution.
    ///   - autoPlay: Whether playback should resume automatically when network
    /// recovers.
    ///   - rate: Optional target playback speed multiplier.
    ///   - stateToNavigateAfterBuffering: State to transition into after
    /// network buffering resolves.
    ///   - targetSeek: Optional pending seek command to preserve across network
    /// waiting.
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
        self.stateToNavigateAfterBuffering = stateToNavigateAfterBuffering
        self.autoPlay = autoPlay
        self.rate = rate
        self.targetSeek = targetSeek
        super.init(
            playerController: playerController,
            state: .waitingForNetwork
        )
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
    
    /// Entry point for state setup. Ensures player is paused, starts observer
    /// pipelines, and monitors network changes.
    override public func processStateChange() {
        if !playerController.player.timeControlStatus.isPaused {
            playerController.performPause()
        }
        
        startObservingPlayerItemNotifications()
        observeNetworkChanges()
    }
    
    /// Cleans up Combine observation pipelines before transitioning to another
    /// state.
    override public func beforeStateChange() {
        subscriptions.forEach({ $0.cancel() })
        subscriptions.removeAll()
    }
    
    // MARK: - Commands
    
    /// Commands the player to play, updating the autoplay flag or notifying
    /// delegate if already attempting to play.
    override public func play() {
        if autoPlay {
            playerController
                .emit(.commandUnavailable(reason: .alreadyTryingToPlay))
        } else {
            autoPlay = true
        }
    }
    
    /// Commands the player to play at a target rate once network is
    /// established.
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
    }
    
    // MARK: - Seeking Through Media
    
    /// Stores target seek configuration to perform once network connectivity
    /// resumes.
    /// - Parameters:
    ///   - target: The destination target position.
    ///   - completionHandler: Callback closure invoked when seek executes
    /// post-reconnection.
    override public func seek(
        to target: AKSeekTarget,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        targetSeek = AKSeek(
            target: target,
            completionHandler: completionHandler
        )
    }
    
    /// Stores target seek configuration with custom bounds to perform once
    /// network connectivity resumes.
    /// - Parameters:
    ///   - target: The destination target position.
    ///   - toleranceBefore: The allowable tolerance before the target time.
    ///   - toleranceAfter: The allowable tolerance after the target time.
    ///   - completionHandler: Callback closure invoked when seek executes
    /// post-reconnection.
    override public func seek(
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
    }
    
    // MARK: - Private Helper Functions
    
    public override func handlePlayerStatusChange(_ status: AVPlayer.Status) {
        guard status == .failed else { return }
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
        case .playing:
            hasStartedPlaying = true
        case .waitingToPlayAtSpecifiedRate:
            if hasStartedPlaying {
                guard let reasonForWaitingToPlay = playerController.player.reasonForWaitingToPlay else { return }
                switch reasonForWaitingToPlay {
                case .evaluatingBufferingRate, .interstitialEvent, .toMinimizeStalls, .waitingForCoordinatedPlayback:
                    let controller = AKBufferingState(
                        playerController: playerController,
                        autoPlay: autoPlay,
                        rate: rate,
                        stateToNavigateAfterBuffering: stateToNavigateAfterBuffering ?? .paused,
                        targetSeek: targetSeek
                    )
                    change(controller)
                case .noItemToPlay:
                    stop()
                default:
                    break
                }
            }
        case .paused:
            pause()
        default:
            break
        }
    }
    
    /// Registers notification center listeners for player item playback failure
    /// notifications.
    private func startObservingPlayerItemNotifications() {
        guard let playerItem = playerController.currentMedia?.playerItem
        else { return }
        
        NotificationCenter.default.publisher(
            for: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            guard let self,
                  let error = notification
                .userInfo?[
                    AVPlayerItemFailedToPlayToEndTimeErrorKey
                ] as? NSError
            else { return }
            
            guard error is URLError else {
                let controller = AKFailedState(
                    playerController: playerController,
                    error: .itemFailedToPlayToEndTime
                )
                return change(controller)
            }
            
            /*
             If playback failed for internet issue will wait till internet gets activated
             */
        }
        .store(in: &subscriptions)
    }
    
    /// Monitors system network state changes and transitions to buffering state
    /// when connection is satisfied.
    private func observeNetworkChanges() {
        observeNetworkStatus(in: &subscriptions) { [weak self] status in
            guard let self, status == .satisfied else { return }
            
            // Context and targetSeek are restored cleanly into buffering state
            let controller = AKBufferingState(
                playerController: playerController,
                autoPlay: autoPlay,
                rate: rate,
                stateToNavigateAfterBuffering: stateToNavigateAfterBuffering ?? .paused,
                targetSeek: targetSeek
            )
            change(controller)
        }
    }
    
    // MARK: - Availability Overrides
    
    /// Evaluates preflight permission and unavailable reasons for a given
    /// player action when waiting for network.
    /// - Parameter action: The candidate action to evaluate.
    /// - Returns: A tuple returning `false` and `.waitingForEstablishedNetwork`
    /// for step action; base availability otherwise.
    override public func availability(for action: AKPlayerAction) -> (
        allowed: Bool, reason: AKPlayerUnavailableCommandReason?
    ) {
        switch action {
        case .step:
            (false, .waitingForEstablishedNetwork)
        default:
            super.availability(for: action)
        }
    }
}
