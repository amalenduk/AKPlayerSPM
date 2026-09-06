//
//  AKPlayerState.swift
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

// MARK: - AKPlayerState

/// Represents the current operational state of the media player.
public enum AKPlayerState: String, CustomStringConvertible, Sendable, Equatable {
    
    // MARK: - Cases
    
    /// Initial state when no media is loaded.
    case idle
    /// Media asset is currently being loaded.
    case loading
    /// Media asset is loaded and ready for playback.
    case loaded
    /// Playback is temporarily stalled due to buffering.
    case buffering
    /// Playback is actively paused.
    case paused
    /// Media is actively playing.
    case playing
    /// Playback is stopped.
    case stopped
    /// Playback is paused waiting for network connectivity to restore.
    case waitingForNetwork
    /// Player encountered an unrecoverable error.
    case failed
    
    // MARK: - Computed Properties
    
    /// A human-readable description of the player state.
    public var description: String {
        switch self {
        case .waitingForNetwork:
            return "Waiting For Network"
        default:
            return rawValue.capitalized
        }
    }
    
    /// Indicates whether the player is currently idle.
    public var isIdle: Bool {
        return self == .idle
    }
    
    /// Indicates whether the player is currently loading media.
    public var isLoading: Bool {
        return self == .loading
    }
    
    /// Indicates whether the media asset is loaded and ready.
    public var isLoaded: Bool {
        return self == .loaded
    }
    
    /// Indicates whether the player is buffering content.
    public var isBuffering: Bool {
        return self == .buffering
    }
    
    /// Indicates whether media is currently playing.
    public var isPlaying: Bool {
        return self == .playing
    }
    
    /// Indicates whether playback is paused.
    public var isPaused: Bool {
        return self == .paused
    }
    
    /// Indicates whether playback has stopped.
    public var isStopped: Bool {
        return self == .stopped
    }
    
    /// Indicates whether the player is waiting for network connectivity.
    public var isWaitingForNetwork: Bool {
        return self == .waitingForNetwork
    }
    
    /// Indicates whether the player is in a failed state.
    public var isFailed: Bool {
        return self == .failed
    }
    
    // MARK: - Helper Methods
    
    /// Checks if the current state matches any of the provided states.
    /// - Parameter states: An array of target states.
    /// - Returns: `true` if the current state matches any state in the list.
    public func isAny(of states: [AKPlayerState]) -> Bool {
        return states.contains(self)
    }
    
    /// Checks if the current state does not match any of the provided states.
    /// - Parameter states: An array of target states.
    /// - Returns: `true` if the current state does not match any state in the list.
    public func isNotAny(of states: [AKPlayerState]) -> Bool {
        return !states.contains(self)
    }
}
