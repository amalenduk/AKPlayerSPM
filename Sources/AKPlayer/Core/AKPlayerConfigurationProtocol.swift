//
//  AKPlayerConfiguration.swift
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

// MARK: - AKAudioSessionConfiguration

public struct AKAudioSessionConfiguration: Sendable {
    
    // MARK: - Properties
    
    public var category: AVAudioSession.Category = .playback
    public var activeOptions: AVAudioSession.SetActiveOptions = []
    public var mode: AVAudioSession.Mode = .default
    public var categoryOptions: AVAudioSession.CategoryOptions = []
    
    // MARK: - Init
    
    public init() {}
}

// MARK: - AKPlayerConfigurationProtocol

public protocol AKPlayerConfigurationProtocol: Sendable {
    var periodicTimeInterval: AKTimeEventFrequency { get set }
    var boundaryTimeObserverMultiplier: Double { get set }
    var preferredTimeScale: CMTimeScale { get set }
    var bufferObservingTimeout: TimeInterval { get set }
    var bufferObservingTimeInterval: TimeInterval { get set }
    
    var audioSession: AKAudioSessionConfiguration { get set }
    
    /// Pauses playback automatically when resigning active.
    var playbackPausesWhenResigningActive: Bool { get set }
    
    /// Pauses playback automatically when backgrounded.
    var playbackPausesWhenBackgrounded: Bool { get set }
    
    /// Resumes playback when became active.
    var playbackResumesWhenBecameActive: Bool { get set }
    
    /// Resumes playback when entering foreground.
    var playbackResumesWhenEnteringForeground: Bool { get set }
    
    var playbackResumesWhenAudioSessionInterruptionEnded: Bool { get set }
    
    /// Playback freezes on last frame frame when true and does not reset seek position timestamp..
    var playbackFreezesAtEnd: Bool { get set }
    
    var isNowPlayingEnabled: Bool { get set }
    var idleTimerDisabledForStates: [AKPlayerState] { get set }
    
    var fastForwardRate: AKPlaybackRate { get set }
    var rewindRate: AKPlaybackRate { get set }
}

public extension AKPlayerConfigurationProtocol {
    func getPeriodicTimeInterval() -> CMTime {
        return CMTimeMakeWithSeconds(
            periodicTimeInterval.value,
            preferredTimescale: preferredTimeScale
        )
    }
}

// MARK: - AKTimeEventFrequency

public enum AKTimeEventFrequency: Sendable {
    case everySecond
    case everyHalfSecond
    case everyQuarterSecond
    
    public var value: Double {
        switch self {
        case .everySecond:
            return 1.0
        case .everyHalfSecond:
            return 0.5
        case .everyQuarterSecond:
            return 0.25
        }
    }
}
