//
//   AKStoppedState.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Combine

// MARK: - AKStoppedState

/// Concrete state representing a state where media playback is stopped and item
/// resources are torn down.
@MainActor
public class AKStoppedState: AKBaseState {
    // MARK: - Properties

    /// Container holding reactive Combine event subscriptions.
    private var subscriptions = Set<AnyCancellable>()

    // MARK: - Initialization & Deinitialization

    /// Initializes a stopped state instance associated with the specified
    /// player controller.
    /// - Parameter playerController: The underlying player controller driving
    /// execution.
    public init(playerController: any AKPlayerControllerProtocol) {
        super.init(playerController: playerController, state: .stopped)
    }

    deinit {}

    // MARK: - Lifecycle Hooks

    /// Entry point for stopped state processing. Halts playback, cancels
    /// pending seeks, and replaces current item with nil.
    override public func processStateChange() {
        startObservingPlayerStatus()

        if !playerController.player.timeControlStatus.isPaused {
            playerController.performStop()
        }

        playerController.currentMedia?.playerItem?.cancelPendingSeeks()
        playerController.player.replaceCurrentItem(with: nil)
    }

    /// Cleans up Combine observation pipelines before transitioning to another
    /// state.
    override public func beforeStateChange() {
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
                    playerController: playerController,
                    error: .playerCanNoLongerPlay(
                        error: playerController.player
                            .error
                    )
                )
                change(controller)
            }
            .store(in: &subscriptions)
    }

    // MARK: - Availability Overrides

    /// Evaluates preflight permission and unavailable reasons for a given
    /// player action when in stopped state.
    /// - Parameter action: The candidate action to evaluate.
    /// - Returns: A tuple returning `false` and `.loadMediaFirst` for
    /// playback/seeking actions; base availability otherwise.
    override public func availability(for action: AKPlayerAction) -> (
        allowed: Bool, reason: AKPlayerUnavailableCommandReason?
    ) {
        switch action {
        case .play, .pause, .stop, .seek, .fastForward, .rewind, .step:
            (false, .loadMediaFirst)
        default:
            super.availability(for: action)
        }
    }
}
