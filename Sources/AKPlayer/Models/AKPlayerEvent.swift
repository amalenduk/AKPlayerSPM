//
//  AKPlayerEvent.swift
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

import CoreMedia

// MARK: - AKPlayerEvent

/// Playback events published by ``AKPlayer``.
///
/// Subscribe with `for await event in player.events`. The existing
/// ``AKPlayerDelegate`` remains supported as a compatibility adapter.
public enum AKPlayerEvent: Sendable {
    
    // MARK: - Cases
    
    case stateChanged(AKPlayerState)
    case mediaChanged(any AKPlayable)
    case timeChanged(CMTime)
    case playbackEnded(CMTime)
    case boundaryReached(CMTime)
    case rateChanged(new: AKPlaybackRate, previous: AKPlaybackRate)
    case volumeChanged(Float)
    case muteChanged(Bool)
    case unavailable(AKPlayerUnavailableCommandReason)
    case failed(AKPlayerError)
}

// MARK: - Equatable Conformance

extension AKPlayerEvent: Equatable {
    
    /// Compares two `AKPlayerEvent` instances for equality.
    public static func == (lhs: AKPlayerEvent, rhs: AKPlayerEvent) -> Bool {
        switch (lhs, rhs) {
        case (.mediaChanged(let l), .mediaChanged(let r)):
            return l.isEqual(to: r)
            
        case (.stateChanged(let l), .stateChanged(let r)):
            return l == r
        case (.timeChanged(let l), .timeChanged(let r)):
            return l == r
        case (.playbackEnded(let l), .playbackEnded(let r)):
            return l == r
        case (.boundaryReached(let l), .boundaryReached(let r)):
            return l == r
        case (.rateChanged(let lNew, let lOld), .rateChanged(let rNew, let rOld)):
            return lNew == rNew && lOld == rOld
        case (.volumeChanged(let l), .volumeChanged(let r)):
            return l == r
        case (.muteChanged(let l), .muteChanged(let r)):
            return l == r
        case (.unavailable(let l), .unavailable(let r)):
            return l == r
        case (.failed(let l), .failed(let r)):
            return l == r
        default:
            return false
        }
    }
}
