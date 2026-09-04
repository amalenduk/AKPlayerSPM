//
//  AKPlaybackRate.swift
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

/// Represents playback speed presets and custom multiplier rates for media playback.
public enum AKPlaybackRate: CaseIterable, Sendable {
    /// 0.25x speed.
    case slowest
    /// 0.50x speed.
    case slower
    /// 0.75x speed.
    case slow
    /// 1.00x normal speed.
    case normal
    /// 1.25x speed.
    case fast
    /// 1.50x speed.
    case faster
    /// 1.75x speed.
    case fastest
    /// 2.00x speed.
    case superfast
    /// 0.00x (paused) speed.
    case paused
    /// Custom playback rate multiplier.
    case custom(Float)
    
    /// A collection of standard predefined playback speed presets excluding `.paused` and `.custom`.
    public static let allCases: [AKPlaybackRate] = [
        .slowest, .slower, .slow, .normal, .fast, .faster, .fastest, .superfast
    ]
    
    /// Initializes a playback rate matching a floating-point multiplier value.
    /// - Parameter rate: The float value representing speed (e.g., `1.0` for normal).
    public init(rate: Float) {
        switch rate {
        case 0.25: self = .slowest
        case 0.50: self = .slower
        case 0.75: self = .slow
        case 1.00: self = .normal
        case 1.25: self = .fast
        case 1.50: self = .faster
        case 1.75: self = .fastest
        case 2.00: self = .superfast
        case 0: self = .paused
        default: self = .custom(rate)
        }
    }
    
    /// The numeric floating-point playback speed value.
    public var rate: Float {
        switch self {
        case .slowest: return 0.25
        case .slower: return 0.5
        case .slow: return 0.75
        case .normal: return 1.0
        case .fast: return 1.25
        case .faster: return 1.5
        case .fastest: return 1.75
        case .superfast: return 2.00
        case .paused: return 0
        case .custom(let value): return value
        }
    }
    
    /// A string representation of the numeric rate formatted with a 'x' multiplier suffix (e.g., "1.5x").
    public var rateTitle: String { "\(rate)x" }
    
    /// A human-readable title describing the current rate preset.
    public var title: String {
        switch self {
        case .slowest: return "Slowest"
        case .slower: return "Slower"
        case .slow: return "Slow"
        case .normal: return "Normal"
        case .fast: return "Fast"
        case .faster: return "Faster"
        case .fastest: return "Fastest"
        case .superfast: return "Super Fast"
        case .paused: return "Paused"
        case .custom(let value): return "\(value)x"
        }
    }
    
    /// Returns the next sequential playback rate in the rotation sequence, wrapping around at max speed.
    public var next: AKPlaybackRate {
        switch self {
        case .slowest: return .slower
        case .slower: return .slow
        case .slow: return .normal
        case .normal: return .fast
        case .fast: return .faster
        case .faster: return .fastest
        case .fastest: return .superfast
        case .superfast: return .slowest
        case .paused: return .normal
        case .custom: return .normal
        }
    }
}

// MARK: - Equatable Conformance

extension AKPlaybackRate: Equatable {
    /// Compares two `AKPlaybackRate` instances for equality.
    public static func == (lhs: AKPlaybackRate, rhs: AKPlaybackRate) -> Bool {
        switch (lhs, rhs) {
        case (.slowest, .slowest),
            (.slower, .slower),
            (.slow, .slow),
            (.normal, .normal),
            (.fast, .fast),
            (.faster, .faster),
            (.fastest, .fastest),
            (.superfast, .superfast),
            (.paused, .paused):
            return true
        case (.custom(let lhs), .custom(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}
