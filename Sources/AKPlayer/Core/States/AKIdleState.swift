//
//  AKIdleState.swift
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

// MARK: - AKIdleState

/// Concrete state representing an idle player machine before any media item has been initialized or loaded.
@MainActor
public class AKIdleState: AKBaseState {
    // MARK: - Initialization & Deinitialization

    /// Initializes an idle state instance associated with the specified player controller.
    /// - Parameter playerController: The target player controller executing playback commands.
    public init(playerController: any AKPlayerControllerProtocol) {
        super.init(playerController: playerController, state: .idle)
    }

    deinit {
        // Cleanup routine if needed when state memory is released
    }

    // MARK: - Preflight Checks

    /// Evaluates preflight permission and unavailable reasons for a given player action when in the idle state.
    /// - Parameter action: The candidate action to evaluate.
    /// - Returns: A tuple returning `false` and `.loadMediaFirst` for all actions in idle state.
    override public func availability(for _: AKPlayerAction) -> (
        allowed: Bool, reason: AKPlayerUnavailableCommandReason?
    ) {
        return (allowed: false, reason: .loadMediaFirst)
    }
}
