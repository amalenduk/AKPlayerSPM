//
//  AKMediaType.swift
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

// MARK: - AKMediaType

/// Defines the underlying structural type of a media asset.
public enum AKMediaType: Sendable, Equatable {
    /// Standard finite media clip (e.g., MP4, MP3, VOD asset).
    case clip
    
    /// Streaming media asset with an indicator for whether it is a live broadcast or a replay stream.
    case stream(isLive: Bool)
}

// MARK: - CustomStringConvertible

extension AKMediaType: CustomStringConvertible {
    /// A human-readable description of the media type.
    public var description: String {
        switch self {
        case .clip:
            return "Clip"
        case let .stream(isLive):
            return isLive ? "Live Stream" : "Replay Stream"
        }
    }
}
