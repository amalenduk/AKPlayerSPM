//
//  AKWaitingForNetworkState.swift
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

// MARK: - AKWaitingForNetworkState

/// Concrete state representing a period where playback is paused while waiting for network connectivity to restore.
@MainActor
public class AKWaitingForNetworkState: AKBaseState {
    
    // MARK: - Properties
    
    /// Optional target playback speed multiplier to apply once network connection recovers.
    private var rate: AKPlaybackRate?
    
    /// Indicates whether playback should resume automatically when network connectivity is re-established.
    public private(set) var autoPlay: Bool = false
    
    /// The player state to transition into after buffering resolves following network restoration.
    private var stateToNavigateAfterBuffering: AKPlayerState?
    
    /// Optional pending seek command to preserve across network waiting state.
    private var targetSeek: AKSeek?
    
    /// Container holding reactive Combine event subscriptions. Marked `nonisolated(unsafe)` for safe disposal in `deinit`.
    private nonisolated(unsafe) var subscriptions = Set<AnyCancellable>()
    
    // MARK: - Initialization & Deinitialization
    
    /// Initializes a waiting-for-network state instance.
    /// - Parameters:
    ///   - playerController: The underlying player controller driving execution.
    ///   - autoPlay: Whether playback should resume automatically when network recovers.
    ///   - rate: Optional target playback speed multiplier.
    ///   - stateToNavigateAfterBuffering: State to transition into after network buffering resolves.
    ///   - targetSeek: Optional pending seek command to preserve across network waiting.
    public init(
        playerController: any AKPlayerControllerProtocol,
        autoPlay: Bool = false,
        rate: AKPlaybackRate? = nil,
        stateToNavigateAfterBuffering: AKPlayerState? = nil,
        targetSeek: AKSeek? = nil
    ) {
        self.stateToNavigateAfterBuffering = stateToNavigateAfterBuffering
        self.autoPlay = autoPlay
        self.rate = rate
        self.targetSeek = targetSeek
        super.init(playerController: playerController, state: .waitingForNetwork)
    }
    
    deinit {
        subscriptions.removeAll()
    }
    
    // MARK: - Lifecycle Hooks
    
    /// Entry point for state setup. Ensures player is paused, starts observer pipelines, and monitors network changes.
    public override func processStateChange() {
        startObservingPlayerStatus()
        
        if !playerController.player.timeControlStatus.isPaused {
            playerController.performPause()
        }
        
        startObservingPlayerItemNotifications()
        observeNetworkChanges()
    }
    
    /// Cleans up Combine observation pipelines before transitioning to another state.
    public override func beforeStateChange() {
        subscriptions.removeAll()
    }
    
    // MARK: - Commands
    
    /// Commands the player to play, updating the autoplay flag or notifying delegate if already attempting to play.
    public override func play() {
        if autoPlay {
            playerController.delegate?.playerController(
                playerController,
                didEncounterUnavailableAction: .alreadyTryingToPlay
            )
        } else {
            self.autoPlay = true
        }
    }
    
    /// Commands the player to play at a target rate once network is established.
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
    }
    
    // MARK: - Seeking Through Media
    
    /// Stores target seek configuration to perform once network connectivity resumes.
    /// - Parameters:
    ///   - target: The destination target position.
    ///   - completionHandler: Callback closure invoked when seek executes post-reconnection.
    public override func seek(
        to target: AKSeekTarget,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        targetSeek = AKSeek(
            target: target,
            completionHandler: completionHandler
        )
    }
    
    /// Stores target seek configuration with custom bounds to perform once network connectivity resumes.
    /// - Parameters:
    ///   - target: The destination target position.
    ///   - toleranceBefore: The allowable tolerance before the target time.
    ///   - toleranceAfter: The allowable tolerance after the target time.
    ///   - completionHandler: Callback closure invoked when seek executes post-reconnection.
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
    }
    
    // MARK: - Private Helper Functions
    
    /// Observes status changes and missing current items on AVPlayer while waiting for network.
    private func startObservingPlayerStatus() {
        playerController.player.publisher(for: \.status)
            .prepend(playerController.player.status)
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
    
    /// Registers notification center listeners for player item playback failure notifications.
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
                    error: .itemFailedToPlayToEndTime
                )
                return self.change(controller)
            }
            
            /*
             If playback failed for internet issue will wait till internet gets activated
             */
        }
        .store(in: &subscriptions)
    }
    
    /// Monitors system network state changes and transitions to buffering state when connection is satisfied.
    private func observeNetworkChanges() {
        observeNetworkStatus(in: &subscriptions) { [weak self] status in
            guard let self, status == .satisfied else { return }
            
            // Context and targetSeek are restored cleanly into buffering state
            let controller = AKBufferingState(
                playerController: self.playerController,
                autoPlay: self.autoPlay,
                rate: self.rate,
                stateToNavigateAfterBuffering: self.stateToNavigateAfterBuffering ?? .paused,
                targetSeek: self.targetSeek
            )
            self.change(controller)
        }
    }
    
    // MARK: - Availability Overrides
    
    /// Evaluates preflight permission and unavailable reasons for a given player action when waiting for network.
    /// - Parameter action: The candidate action to evaluate.
    /// - Returns: A tuple returning `false` and `.waitingForEstablishedNetwork` for step action; base availability otherwise.
    public override func availability(for action: AKPlayerAction) -> (allowed: Bool, reason: AKPlayerUnavailableCommandReason?) {
        switch action {
        case .step:
            return (false, .waitingForEstablishedNetwork)
        default:
            return super.availability(for: action)
        }
    }
}
