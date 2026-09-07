//
//  AKPlayerUnavailableCommandReason.swift
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

import Foundation

// MARK: - AKPlayerUnavailableCommandReason

/// Defines reasons why a specific player command or action cannot be executed.
public enum AKPlayerUnavailableCommandReason: Equatable, Sendable {
    // MARK: - Cases

    /// Command ignored because playback is already paused.
    case alreadyPaused
    /// Command ignored because media is already playing.
    case alreadyPlaying
    /// Command ignored because the player is already stopped.
    case alreadyStopped
    /// Command ignored because a playback initiation request is already in progress.
    case alreadyTryingToPlay
    /// The requested seek position is invalid or outside valid bounds.
    case seekPositionNotAvailable
    /// The requested seek target exceeds the current media duration.
    case seekOverstepPosition
    /// Action failed because no media item is currently loaded.
    case loadMediaFirst
    /// Action postponed until network connection is re-established.
    case waitingForEstablishedNetwork
    /// Action postponed until media item completes initial asset loading.
    case waitTillMediaLoaded
    /// The current media asset does not support stepping forward.
    case canNotStepForward
    /// The current media asset does not support stepping backward.
    case canNotStepBackward
    /// The requested playback rate is unsupported by the current media asset.
    case canNotPlayAtSpecifiedRate
    /// Action forbidden by the current player state or security policy.
    case actionNotPermitted
    /// Player encountered an unrecoverable failure and can no longer process commands.
    case playerCanNoLongerPlay
}

// MARK: - CustomStringConvertible

extension AKPlayerUnavailableCommandReason: CustomStringConvertible {
    /// A human-readable textual representation describing the reason command was unavailable.
    public var description: String {
        switch self {
        case .alreadyPaused:
            return "Already Paused"
        case .alreadyPlaying:
            return "Already Playing"
        case .alreadyStopped:
            return "Already Stopped"
        case .alreadyTryingToPlay:
            return "Wait a moment, already trying to play"
        case .seekPositionNotAvailable:
            return "Seek position not available"
        case .seekOverstepPosition:
            return "Seek position beyond duration"
        case .loadMediaFirst:
            return "Load media first"
        case .waitingForEstablishedNetwork:
            return "Waiting for network connection to be established"
        case .waitTillMediaLoaded:
            return "Waiting for media item to finish loading"
        case .canNotStepForward:
            return "Item doesn't support stepping forward"
        case .canNotStepBackward:
            return "Item doesn't support stepping backward"
        case .canNotPlayAtSpecifiedRate:
            return "Item can't be played at the specified rate"
        case .actionNotPermitted:
            return "Action is not permitted"
        case .playerCanNoLongerPlay:
            return "Player can no longer play"
        }
    }
}
