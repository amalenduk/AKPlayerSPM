//
//  AKPlayerConfigurationProtocol.swift
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

/// Represents audio session parameters used to configure `AVAudioSession` behavior.
public struct AKAudioSessionConfiguration: Sendable {
    // MARK: - Properties

    /// The audio session category defining the general audio behavior of the app. Defaults to `.playback`.
    public var category: AVAudioSession.Category = .playback

    /// The options applied when activating or deactivating the audio session. Defaults to empty set `[]`.
    public var activeOptions: AVAudioSession.SetActiveOptions = []

    /// The audio session mode clarifying the intended use of the category. Defaults to `.default`.
    public var mode: AVAudioSession.Mode = .default

    /// Additional options refining the audio session category behavior. Defaults to empty set `[]`.
    public var categoryOptions: AVAudioSession.CategoryOptions = []

    // MARK: - Initialization

    /// Initializes a new audio session configuration with default options.
    public init() {}
}

// MARK: - AKPlayerConfigurationProtocol

/// Protocol defining configuration properties driving player behavior, buffering, audio sessions, and lifecycle events.
public protocol AKPlayerConfigurationProtocol: Sendable {
    // MARK: - Playback Observer Configurations

    /// The frequency interval at which periodic time observers trigger updates.
    var periodicTimeInterval: AKTimeEventFrequency { get set }

    /// The offset multiplier applied when calculating boundary time observer positions relative to media duration.
    var boundaryTimeObserverMultiplier: Double { get set }

    /// The preferred timescale used when calculating time observations.
    var preferredTimeScale: CMTimeScale { get set }

    // MARK: - Buffer Management Configurations

    /// The maximum duration in seconds the player waits for buffering before triggering a timeout error.
    var bufferObservingTimeout: TimeInterval { get set }

    /// The polling time interval in seconds used to check current buffer status.
    var bufferObservingTimeInterval: TimeInterval { get set }

    // MARK: - Audio Session Configurations

    /// The configuration parameters applied to the system audio session service.
    var audioSession: AKAudioSessionConfiguration { get set }

    // MARK: - Lifecycle Behavior Configurations

    /// Pauses playback automatically when the application resigns active status.
    var playbackPausesWhenResigningActive: Bool { get set }

    /// Pauses playback automatically when the application enters the background.
    var playbackPausesWhenBackgrounded: Bool { get set }

    /// Resumes playback automatically when the application returns to active status.
    var playbackResumesWhenBecameActive: Bool { get set }

    /// Resumes playback automatically when the application enters the foreground.
    var playbackResumesWhenEnteringForeground: Bool { get set }

    /// Resumes playback automatically after an audio session interruption ends.
    var playbackResumesWhenAudioSessionInterruptionEnded: Bool { get set }

    /// Playback freezes on the last frame when true and does not reset seek position timestamp upon completion.
    var playbackFreezesAtEnd: Bool { get set }

    // MARK: - System Integration Configurations

    /// Indicates whether Now Playing metadata integration with `MPNowPlayingInfoCenter` and remote commands is enabled.
    var isNowPlayingEnabled: Bool { get set }

    /// The list of player states during which the system idle timer (screen sleep) is disabled.
    var idleTimerDisabledForStates: [AKPlayerState] { get set }

    // MARK: - Speed Configurations

    /// The default speed multiplier used when fast-forwarding playback.
    var fastForwardRate: AKPlaybackRate { get set }

    /// The default speed multiplier used when rewinding playback.
    var rewindRate: AKPlaybackRate { get set }
}

// MARK: - Protocol Extension

public extension AKPlayerConfigurationProtocol {
    /// Calculates and returns the periodic time observer interval represented as a `CMTime` struct.
    /// - Returns: A `CMTime` computed from the current `periodicTimeInterval` and `preferredTimeScale`.
    func getPeriodicTimeInterval() -> CMTime {
        return CMTimeMakeWithSeconds(
            periodicTimeInterval.value,
            preferredTimescale: preferredTimeScale
        )
    }
}

// MARK: - AKTimeEventFrequency

/// Defines predefined time event frequency options for periodic time observers.
public enum AKTimeEventFrequency: Sendable {
    /// Fires time events every second (1.0 second).
    case everySecond

    /// Fires time events every half second (0.5 seconds).
    case everyHalfSecond

    /// Fires time events every quarter second (0.25 seconds).
    case everyQuarterSecond

    /// The floating-point time interval value in seconds corresponding to the frequency choice.
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
