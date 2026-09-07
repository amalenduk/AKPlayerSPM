//
//  AKFailedState.swift
//  AKPlayer
//
//  Copyright (c) 2020 Amalendu Kar
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE
//  SOFTWARE.
//

import AVFoundation

// MARK: - AKFailedState

/// Concrete state representing a terminal or recoverable error condition within
/// the player pipeline.
@MainActor
public class AKFailedState: AKBaseState {
  // MARK: - Properties

  /// The specific player error that triggered this failure state.
  public let error: AKPlayerError

  // MARK: - Initialization & Deinitialization

  /// Initializes a failed state instance associated with a specified player
  /// controller and error.
  /// - Parameters:
  ///   - playerController: The target player controller executing playback
  /// commands.
  ///   - error: The player error describing the underlying failure.
  public init(
    playerController: any AKPlayerControllerProtocol,
    error: AKPlayerError
  ) {
    self.error = error
    super.init(playerController: playerController, state: .failed)
  }

  deinit {
    // Cleanup routine if needed when state memory is released
  }

  // MARK: - Lifecycle Hooks

  /// Notifies the delegate that the player has encountered an error and
  /// transitioned into the failed state.
  override public func processStateChange() {
    playerController.emit(.didFail(with: error))
  }

  // MARK: - Preflight Checks

  /// Evaluates preflight permission and unavailable reasons for a given
  /// player action when in the failed state.
  /// - Parameter action: The candidate action to evaluate.
  /// - Returns: A tuple containing a boolean flag indicating if allowed, and
  /// an optional unavailability reason.
  override public func availability(for action: AKPlayerAction) -> (
    allowed: Bool, reason: AKPlayerUnavailableCommandReason?
  ) {
    switch action {
    case .load:
      let hasPlayerError = playerController.player.error != nil
      return hasPlayerError
        ? (allowed: false, reason: .playerCanNoLongerPlay)
        : (
          allowed: true,
          reason: nil
        )

    default:
      let hasPlayerError = playerController.player.error != nil
      return (
        allowed: false,
        reason: hasPlayerError ? .playerCanNoLongerPlay : .loadMediaFirst
      )
    }
  }
}
