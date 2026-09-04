//
//  AKPausedState.swift
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

// MARK: - AKPausedState

/// Concrete state representing a state where media playback is actively paused.
@MainActor
public class AKPausedState: AKBaseState {
    
    // MARK: - Properties
    
    /// Flag indicating whether playback paused naturally because the media reached its end time.
    private let playerItemDidPlayToEndTime: Bool
    
    /// Container holding reactive Combine event subscriptions. Marked `nonisolated(unsafe)` for safe disposal in `deinit`.
    private nonisolated(unsafe) var subscriptions = Set<AnyCancellable>()
    
    // MARK: - Init
    
    /// Initializes a paused state instance.
    /// - Parameters:
    ///   - playerController: The underlying player controller driving execution.
    ///   - playerItemDidPlayToEndTime: True if the item was paused because it played through to the end.
    public init(
        playerController: any AKPlayerControllerProtocol,
        playerItemDidPlayToEndTime: Bool = false
    ) {
        self.playerItemDidPlayToEndTime = playerItemDidPlayToEndTime
        super.init(playerController: playerController, state: .paused)
    }
    
    deinit {
        subscriptions.removeAll()
    }
    
    // MARK: - Lifecycle Hooks
    
    /// Entry point for paused state processing. Ensures playback pauses and fires delegate notifications if end-of-media was reached.
    public override func processStateChange() {
        startObservingPlayerStatus()
        startObservingPlayerItemNotifications()
        
        if !playerController.player.timeControlStatus.isPaused {
            playerController.performPause()
        }
        
        if playerItemDidPlayToEndTime, let currentMedia = playerController.currentMedia {
            playerController.delegate?.playerController(
                playerController,
                didReachEndAt: playerController.currentTime,
                for: currentMedia
            )
        }
    }
    
    // MARK: - Commands
    
    /// Resumes playback. Transitions to loading state if media is not ready, or buffering state if ready.
    public override func play() {
        guard let currentMedia = playerController.currentMedia,
              currentMedia.state.isReadyToPlay else {
            if let media = playerController.currentMedia {
                load(media: media, autoPlay: true)
            }
            return
        }
        
        let initialSeek: AKSeek? = playerItemDidPlayToEndTime ? AKSeek(
            target: .time(.zero),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) : nil
        
        let controller = AKBufferingState(
            playerController: playerController,
            autoPlay: true,
            targetSeek: initialSeek
        )
        change(controller)
    }
    
    /// Resumes playback at a target rate. Validates capability or requests loading if unready.
    /// - Parameter rate: The target playback speed.
    public override func play(at rate: AKPlaybackRate) {
        guard let currentMedia = playerController.currentMedia,
              currentMedia.state.isReadyToPlay else {
            if let media = playerController.currentMedia {
                let controller = AKLoadingState(
                    playerController: playerController,
                    media: media,
                    autoPlay: true,
                    rate: rate
                )
                change(controller)
            }
            return
        }
        
        guard currentMedia.canPlay(at: rate) else {
            playerController.delegate?.playerController(
                playerController,
                didEncounterUnavailableAction: .canNotPlayAtSpecifiedRate
            )
            return
        }
        
        let initialSeek: AKSeek? = playerItemDidPlayToEndTime ? AKSeek(
            target: .time(.zero),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) : nil
        
        let controller = AKBufferingState(
            playerController: playerController,
            autoPlay: true,
            rate: rate,
            targetSeek: initialSeek
        )
        change(controller)
    }
    
    // MARK: - Additional Helper Functions
    
    /// Observes status changes and empty item scenarios on AVPlayer while in paused state.
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
            
            let controller = AKWaitingForNetworkState(
                playerController: self.playerController,
                autoPlay: true
            )
            self.change(controller)
        }
        .store(in: &subscriptions)
    }
    
    // MARK: - Availability Overrides
    
    /// Checks action availability in paused state.
    public override func availability(for action: AKPlayerAction)
    -> (allowed: Bool, reason: AKPlayerUnavailableCommandReason?) {
        switch action {
        case .pause:
            return (false, .alreadyPaused)
        default:
            return super.availability(for: action)
        }
    }
    
    /// Cleans active Combine observers prior to state transition.
    public override func beforeStateChange() {
        subscriptions.removeAll()
    }
}
