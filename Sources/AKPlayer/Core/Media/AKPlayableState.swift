//
//  AKPlayableState.swift
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

// MARK: - AKPlayableState

/// Represents the lifecycle loading state of a playable media item.
@objc public enum AKPlayableState: Int, CustomStringConvertible, Sendable {
    /// Initial uninitialized state before asset loading begins.
    case idle = 0

    /// The underlying `AVURLAsset` has been successfully created and validated.
    case assetLoaded

    /// The `AVPlayerItem` has been instantiated from the media asset.
    case playerItemLoaded

    /// The player item status has transitioned to ready for playback.
    case readyToPlay

    /// Media initialization or asset loading encountered a fatal error.
    case failed

    /// A textual description of the state.
    public var description: String {
        switch self {
        case .idle:
            return "Idle"
        case .assetLoaded:
            return "Asset Loaded"
        case .playerItemLoaded:
            return "Player Item Loaded"
        case .readyToPlay:
            return "Ready To Play"
        case .failed:
            return "Failed"
        }
    }

    /// Returns `true` if the state is ``idle``.
    var isIdle: Bool {
        return self == .idle
    }

    /// Returns `true` if the state is ``assetLoaded``.
    var isAssetLoaded: Bool {
        return self == .assetLoaded
    }

    /// Returns `true` if the state is ``playerItemLoaded``.
    var isPlayerItemLoaded: Bool {
        return self == .playerItemLoaded
    }

    /// Returns `true` if the state is ``readyToPlay``.
    var isReadyToPlay: Bool {
        return self == .readyToPlay
    }

    /// Returns `true` if the state is ``failed``.
    var isFailed: Bool {
        return self == .failed
    }
}

// MARK: - Equatable Implementation

extension AKPlayableState: Equatable {}

/// Compares two `AKPlayableState` instances for equality.
/// - Parameters:
///   - lhs: The left-hand side state.
///   - rhs: The right-hand side state.
/// - Returns: A Boolean value indicating whether the states are equal.
public func == (lhs: AKPlayableState, rhs: AKPlayableState) -> Bool {
    switch (lhs, rhs) {
    case (.idle, .idle),
         (.assetLoaded, .assetLoaded),
         (.playerItemLoaded, .playerItemLoaded),
         (.readyToPlay, .readyToPlay),
         (.failed, .failed):
        return true
    default:
        return false
    }
}
