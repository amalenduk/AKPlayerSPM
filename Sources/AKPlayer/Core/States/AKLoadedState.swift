//
//  AKLoadedState.swift
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

// MARK: - AKLoadedState

/// Concrete state representing a state where media has been loaded into the pipeline and is ready for playback or seeking.
@MainActor
public class AKLoadedState: AKBaseState {
    
    // MARK: - Properties
    
    /// Indicates whether autoplay should trigger automatically once preparation finishes.
    public private(set) var autoPlay: Bool
    
    /// Optional target position to navigate to upon loading.
    private let position: AKSeekTarget?
    
    /// Optional target playback speed multiplier to apply on play.
    private var rate: AKPlaybackRate?
    
    /// Storage set for managing reactive Combine event subscriptions.
    private nonisolated(unsafe) var subscriptions = Set<AnyCancellable>()
    
    // MARK: - Initialization & Deinitialization
    
    /// Initializes a loaded state instance associated with the specified player controller.
    /// - Parameters:
    ///   - playerController: The target player controller executing playback commands.
    ///   - autoPlay: Controls whether playback should automatically start upon entering this state.
    ///   - position: An optional initial position to apply on load.
    ///   - rate: An optional initial playback rate speed multiplier.
    public init(
        playerController: any AKPlayerControllerProtocol,
        autoPlay: Bool = false,
        position: AKSeekTarget? = nil,
        rate: AKPlaybackRate? = nil
    ) {
        self.autoPlay = autoPlay
        self.position = position
        self.rate = rate
        super.init(playerController: playerController, state: .loaded)
    }
    
    deinit {
        subscriptions.removeAll()
    }
    
    // MARK: - Lifecycle Hooks
    
    /// Processes state updates, sets up KVO observations, and handles automatic seek or playback triggers.
    public override func processStateChange() {
        startObservingPlayerProperties()
        
        if let currentMedia = playerController.currentMedia {
            playerController.delegate?.playerController(
                playerController,
                didChangeCurrentTimeTo: playerController.currentTime,
                for: currentMedia
            )
        }
        
        if autoPlay {
            play()
        } else if let position, let currentMedia = playerController.currentMedia {
            let (canSeek, reason) = currentMedia.seekingThroughMedia.canSeek(to: position)
            guard canSeek else {
                if let reason {
                    playerController.delegate?.playerController(
                        playerController,
                        didEncounterUnavailableAction: reason
                    )
                }
                return
            }
            
            Task {
                await seek(to: position)
            }
        }
    }
    
    /// Cleans up Combine observation pipelines before transitioning to another state.
    public override func beforeStateChange() {
        subscriptions.removeAll()
    }
    
    // MARK: - Commands
    
    /// Commands the player to unpause and enter the buffering state prior to active playback.
    public override func play() {
        let controller = AKBufferingState(
            playerController: playerController,
            autoPlay: true,
            rate: rate
        )
        if let position {
            Task {
                await controller.seek(to: position)
            }
        }
        change(controller)
    }
    
    /// Commands the player to unpause and play at a specific target rate multiplier.
    /// - Parameter rate: Target playback rate multiplier.
    public override func play(at rate: AKPlaybackRate) {
        guard let currentMedia = playerController.currentMedia,
              currentMedia.canPlay(at: rate) else {
            playerController.delegate?.playerController(
                playerController,
                didEncounterUnavailableAction: .canNotPlayAtSpecifiedRate
            )
            return
        }
        
        let controller = AKBufferingState(
            playerController: playerController,
            autoPlay: true,
            rate: rate
        )
        if let position {
            Task {
                await controller.seek(to: position)
            }
        }
        change(controller)
    }
    
    /// Commands the player to pause. Disables `autoPlay` if queued, or emits an `.alreadyPaused` unavailability warning.
    public override func pause() {
        if autoPlay {
            autoPlay = false
        } else {
            playerController.delegate?.playerController(
                playerController,
                didEncounterUnavailableAction: .alreadyPaused
            )
        }
    }
    
    // MARK: - Private Pipeline Helpers
    
    /// Binds KVO status publishers to monitor player status and missing current items.
    private func startObservingPlayerProperties() {
        playerController.player.publisher(for: \.status)
            .prepend(playerController.player.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self, status == .failed else { return }
                let controller = AKFailedState(
                    playerController: playerController,
                    error: .playerCanNoLongerPlay(error: playerController.player.error)
                )
                change(controller)
            }
            .store(in: &subscriptions)
        
        playerController.player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, playerController.player.currentItem == nil else { return }
                stop()
            }
            .store(in: &subscriptions)
    }
}
