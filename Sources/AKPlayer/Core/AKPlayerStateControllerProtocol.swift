//
//  AKPlayerStateControllerProtocol.swift
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

import Foundation

// MARK: - AKPlayerStateControllerProtocol

/// A protocol defining the core interface for player state machine controllers.
///
/// Implementations of this protocol represent specific player states (e.g.,
/// buffering, playing, paused)
/// and handle state-specific behaviors, action validations, and state
/// transitions within the state pattern.
@MainActor
public protocol AKPlayerStateControllerProtocol: AKPlayerActionsProtocol {
    /// The underlying player controller driving playback, asset management, and
    /// audio state transitions.
    var playerController: any AKPlayerControllerProtocol { get }

    /// The current operational state classification represented by this state
    /// controller instance.
    var state: AKPlayerState { get }

    /// Indicates whether media playback should automatically begin upon asset
    /// load completion.
    var autoPlay: Bool { get }

    /// Evaluates current state conditions and performs necessary state
    /// transition or status evaluation logic.
    func processStateChange()
}

// MARK: - Default Implementations

public extension AKPlayerStateControllerProtocol {
    /// Default implementation returning `false` for automatic playback
    /// behavior.
    var autoPlay: Bool {
        false
    }
}
