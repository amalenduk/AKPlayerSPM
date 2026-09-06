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
    
    private var rate: AKPlaybackRate?
    public private(set) var autoPlay: Bool = false
    private var stateToNavigateAfterBuffering: AKPlayerState?
    private var targetSeek: AKSeek?
    
    /// Container holding reactive Combine event subscriptions. Marked `nonisolated(unsafe)` for safe disposal in `deinit`.
    private nonisolated(unsafe) var subscriptions = Set<AnyCancellable>()
    
    // MARK: - Init & Deinit
    
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
    
    public override func processStateChange() {
        startObservingPlayerStatus()
        
        if !playerController.player.timeControlStatus.isPaused {
            playerController.performPause()
        }
        
        startObservingPlayerItemNotifications()
        observeNetworkChanges()
    }
    
    // MARK: - Commands
    
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
    
    // MARK: - Async Seek Handlers
    
    public override func seek(
        to target: AKSeekTarget,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        targetSeek = AKSeek(
            target: target,
            completionHandler: completionHandler
        )
    }
    
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
    
    // MARK: - Additional Helper Functions
    
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
    
    public override func availability(for action: AKPlayerAction)
    -> (allowed: Bool, reason: AKPlayerUnavailableCommandReason?) {
        switch action {
        case .step:
            return (false, .waitingForEstablishedNetwork)
        default:
            return super.availability(for: action)
        }
    }
    
    public override func beforeStateChange() {
        subscriptions.removeAll()
    }
}
