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

public enum AKPlayerState: String, CustomStringConvertible {
    case idle
    case loading
    case loaded
    case buffering
    case paused
    case playing
    case stopped
    case waitingForNetwork
    case failed
    
    public var description: String {
        switch self {
        case .waitingForNetwork:
            return "Waiting For Network"
        default:
            return rawValue.capitalized
        }
    }
    
    var isIdle: Bool {
        return self == .idle
    }
    
    var isLoading: Bool {
        return self == .loading
    }
    
    var isLoaded: Bool {
        return self == .loaded
    }
    
    var isBuffering: Bool {
        return self == .buffering
    }
    
    var isPlaying: Bool {
        return self == .playing
    }
    
    var isPaused: Bool {
        return self == .paused
    }
    
    var isStopped: Bool {
        return self == .stopped
    }
    
    var isWaitingForNetwork: Bool {
        return self == .waitingForNetwork
    }
    
    var isFailed: Bool {
        return self == .failed
    }
    
    func isAny(of states: [AKPlayerState]) -> Bool {
        return states.contains(where: {$0 == self})
    }
    
    func isNotAny(of states: [AKPlayerState]) -> Bool {
        return !states.contains(where: {$0 == self})
    }
}

extension AKPlayerState: Equatable {}

public func == (lhs: AKPlayerState, rhs: AKPlayerState) -> Bool {
    switch (lhs, rhs) {
    case (.idle, .idle),
        (.loading, .loading),
        (.loaded, .loaded),
        (.buffering, .buffering),
        (.playing, .playing),
        (.paused, .paused),
        (.stopped, .stopped),
        (.waitingForNetwork, .waitingForNetwork),
        (.failed, .failed) :
        return true
    default:
        return false
    }
}
