//
//  AKPlayingState.swift
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

// MARK: - AKPlayingState

/// Concrete state representing active media playback.
@MainActor
public class AKPlayingState: AKBaseState {
    
    // MARK: - Properties
    
    /// The target playback speed multiplier requested when entering the playing state.
    private var rate: AKPlaybackRate?
    
    /// Container holding reactive Combine event subscriptions.
    private var subscriptions = Set<AnyCancellable>()
    
    // MARK: - Initialization & Deinitialization
    
    /// Initializes a playing state instance associated with the specified player controller.
    /// - Parameters:
    ///   - playerController: The underlying player controller driving execution.
    ///   - rate: An optional initial playback speed multiplier.
    public init(
        playerController: any AKPlayerControllerProtocol,
        rate: AKPlaybackRate? = nil
    ) {
        self.rate = rate
        super.init(playerController: playerController, state: .playing)
    }
    
    deinit { }
    
    // MARK: - Lifecycle Hooks
    
    /// Entry point for playing state setup. Begins observing player status and item notifications, triggers playback, and applies targeted playback rate.
    public override func processStateChange() {
        startObservingPlayerStatus()
        startObservingPlayerItemNotifications()
        
        playerController.performPlay()
        
        guard let rate, playerController.player.rate != rate.rate else { return }
        play(at: rate)
    }
    
    /// Cleans up Combine observation pipelines before transitioning to another state.
    public override func beforeStateChange() {
        subscriptions.removeAll()
    }
    
    // MARK: - Commands
    
    /// Adjusts playback rate when supported by the current media item.
    /// - Parameter rate: The targeted playback speed multiplier.
    public override func play(at rate: AKPlaybackRate) {
        guard let currentMedia = playerController.currentMedia,
              currentMedia.canPlay(at: rate) else {
            playerController.emit(.commandUnavailable(reason: .canNotPlayAtSpecifiedRate))
            return
        }
        
        self.rate = rate
        playerController.performPlay(at: rate)
    }
    
    /// Toggles playback state by pausing the active media playback.
    public override func togglePlayPause() {
        pause()
    }
    
    // MARK: - Private Helper Functions
    
    /// Observes status updates and empty current item conditions on AVPlayer while actively playing.
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
    
    /// Registers notification listeners for player item playback completion, failure, and buffering stall conditions.
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
                autoPlay: true,
                rate: self.rate
            )
            self.change(controller)
        }
        .store(in: &subscriptions)
        
        NotificationCenter.default.publisher(
            for: AVPlayerItem.didPlayToEndTimeNotification,
            object: playerItem
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            guard let self else { return }
            let controller = AKPausedState(
                playerController: self.playerController,
                playerItemDidPlayToEndTime: true
            )
            self.change(controller)
        }
        .store(in: &subscriptions)
        
        NotificationCenter.default.publisher(
            for: AVPlayerItem.playbackStalledNotification,
            object: playerItem
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            guard let self else { return }
            let controller = AKBufferingState(
                playerController: self.playerController,
                autoPlay: true,
                rate: self.rate
            )
            self.change(controller)
        }
        .store(in: &subscriptions)
    }
    
    // MARK: - Availability Overrides
    
    /// Evaluates preflight permission and unavailable reasons for a given player action when actively playing.
    /// - Parameter action: The candidate action to evaluate.
    /// - Returns: A tuple returning `false` and `.alreadyPlaying` for `.play` action; base availability otherwise.
    public override func availability(for action: AKPlayerAction) -> (allowed: Bool, reason: AKPlayerUnavailableCommandReason?) {
        switch action {
        case .play:
            return (false, .alreadyPlaying)
        default:
            return super.availability(for: action)
        }
    }
}
