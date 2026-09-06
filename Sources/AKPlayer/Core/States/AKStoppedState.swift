//
//  AKStoppedState.swift
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

// MARK: - AKStoppedState

/// Concrete state representing a state where media playback is stopped and item resources are torn down.
@MainActor
public class AKStoppedState: AKBaseState {
    
    // MARK: - Properties
    
    /// Container holding reactive Combine event subscriptions. Marked `nonisolated(unsafe)` for safe disposal in `deinit`.
    private nonisolated(unsafe) var subscriptions = Set<AnyCancellable>()
    
    // MARK: - Initialization & Deinitialization
    
    /// Initializes a stopped state instance associated with the specified player controller.
    /// - Parameter playerController: The underlying player controller driving execution.
    public init(playerController: any AKPlayerControllerProtocol) {
        super.init(playerController: playerController, state: .stopped)
    }
    
    deinit {
        subscriptions.removeAll()
    }
    
    // MARK: - Lifecycle Hooks
    
    /// Entry point for stopped state processing. Halts playback, cancels pending seeks, and replaces current item with nil.
    public override func processStateChange() {
        startObservingPlayerStatus()
        
        if !playerController.player.timeControlStatus.isPaused {
            playerController.performStop()
        }
        
        playerController.currentMedia?.playerItem?.cancelPendingSeeks()
        playerController.player.replaceCurrentItem(with: nil)
    }
    
    /// Cleans up Combine observation pipelines before transitioning to another state.
    public override func beforeStateChange() {
        subscriptions.removeAll()
    }
    
    // MARK: - Private Helper Functions
    
    /// Observes status changes on AVPlayer while in stopped state.
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
    }
    
    // MARK: - Availability Overrides
    
    /// Evaluates preflight permission and unavailable reasons for a given player action when in stopped state.
    /// - Parameter action: The candidate action to evaluate.
    /// - Returns: A tuple returning `false` and `.loadMediaFirst` for playback/seeking actions; base availability otherwise.
    public override func availability(for action: AKPlayerAction) -> (allowed: Bool, reason: AKPlayerUnavailableCommandReason?) {
        switch action {
        case .play, .pause, .stop, .seek, .fastForward, .rewind, .step:
            return (false, .loadMediaFirst)
        default:
            return super.availability(for: action)
        }
    }
}
