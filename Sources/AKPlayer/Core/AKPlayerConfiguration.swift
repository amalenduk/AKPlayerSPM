//
//  AKPlayerConfiguration.swift
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

import AVFoundation

// MARK: - AKPlayerConfiguration

/// Default concrete implementation of `AKPlayerConfigurationProtocol` providing
/// customizable playback, buffering, and audio session options.
public struct AKPlayerConfiguration: AKPlayerConfigurationProtocol, Sendable {
    // MARK: - Playback Observer Configurations

    /// The frequency interval at which periodic time observers trigger updates.
    /// Defaults to `.everyQuarterSecond`.
    public var periodicTimeInterval: AKTimeEventFrequency = .everyQuarterSecond

    /// The preferred timescale used when calculating time observations.
    /// Defaults to nanosecond precision (`NSEC_PER_SEC`).
    public var preferredTimeScale: CMTimeScale = .init(NSEC_PER_SEC)

    /// The offset multiplier applied when calculating boundary time observer
    /// positions relative to media duration. Defaults to `0.10`.
    public var boundaryTimeObserverMultiplier: Double = 0.10

    // MARK: - Buffer Management Configurations

    /// The maximum duration in seconds the player waits for buffering before
    /// triggering a timeout error. Defaults to `20` seconds.
    public var bufferObservingTimeout: TimeInterval = 20

    /// The polling time interval in seconds used to check current buffer
    /// status. Defaults to `0.05` seconds.
    public var bufferObservingTimeInterval: TimeInterval = 0.05

    // MARK: - Audio Session Configurations

    /// The configuration parameters applied to the system audio session
    /// service.
    public var audioSession: AKAudioSessionConfiguration = .init()

    // MARK: - System Integration Configurations

    /// Indicates whether Now Playing metadata integration with
    /// `MPNowPlayingInfoCenter` and remote commands is enabled. Defaults to
    /// `true`.
    public var isNowPlayingEnabled: Bool = true

    /// The list of player states during which the system idle timer (screen
    /// sleep) is disabled. Defaults to `[.buffering, .playing]`.
    public var idleTimerDisabledForStates: [AKPlayerState] = [
        .buffering,
        .playing,
    ]

    // MARK: - Lifecycle Behavior Configurations

    /// Specifies whether playback automatically pauses when the application
    /// resigns active status. Defaults to `false`.
    public var playbackPausesWhenResigningActive: Bool = false

    /// Specifies whether playback automatically pauses when the application
    /// enters the background. Defaults to `false`.
    public var playbackPausesWhenBackgrounded: Bool = false

    /// Specifies whether playback automatically resumes when the application
    /// returns to active status. Defaults to `true`.
    public var playbackResumesWhenBecameActive: Bool = true

    /// Specifies whether playback automatically resumes when the application
    /// enters the foreground. Defaults to `true`.
    public var playbackResumesWhenEnteringForeground: Bool = true

    /// Specifies whether playback automatically resumes after an audio session
    /// interruption ends. Defaults to `true`.
    public var playbackResumesWhenAudioSessionInterruptionEnded: Bool = true

    /// Specifies whether playback freezes on the final video frame upon
    /// reaching media end instead of auto-resetting. Defaults to `true`.
    public var playbackFreezesAtEnd: Bool = true

    // MARK: - Speed Configurations

    /// The default speed multiplier used when fast-forwarding playback.
    /// Defaults to `.superfast`.
    public var fastForwardRate: AKPlaybackRate = .superfast

    /// The default speed multiplier used when rewinding playback. Defaults to
    /// `.slowest`.
    public var rewindRate: AKPlaybackRate = .slowest

    // MARK: - Static Default Instance

    /// A shared default configuration instance initialized with standard preset
    /// settings.
    public static let `default` = AKPlayerConfiguration()

    // MARK: - Initialization

    /// Creates a new player configuration instance initialized with default
    /// parameters.
    public init() {}
}
