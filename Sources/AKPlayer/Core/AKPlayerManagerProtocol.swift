//
//  AKPlayerManagerProtocol.swift
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
import AVFoundation
import MediaPlayer

// MARK: - AKPlayerManagerDelegate

/// Delegate protocol to receive state, media, rate, time, and error events from an `AKPlayerManagerProtocol`.
@MainActor
public protocol AKPlayerManagerDelegate: AnyObject {
    func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangeStateTo state: AKPlayerState
    )
    func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangeMediaTo media: any AKPlayable
    )
    func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangePlaybackRateTo newRate: AKPlaybackRate,
        from oldRate: AKPlaybackRate
    )
    func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangeCurrentTimeTo currentTime: CMTime,
        for media: any AKPlayable
    )
    func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didInvokeBoundaryTimeObserverAt time: CMTime,
        for media: any AKPlayable
    )
    func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didReachEndAt time: CMTime,
        for media: any AKPlayable
    )
    func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangeVolumeTo volume: Float
    )
    func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangeMutedStatusTo isMuted: Bool
    )
    func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didEncounterUnavailableAction reason: AKPlayerUnavailableCommandReason
    )
    func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didFailWith error: AKPlayerError
    )
}

// MARK: - AKPlayerManagerProtocol

/// Primary management protocol exposing high-level player control and now-playing integration.
@MainActor
public protocol AKPlayerManagerProtocol: AKPlayerProtocol, AKPlayerActionsProtocol, AKNowPlayingSessionProvider {
    var playerController: AKPlayerControllerProtocol { get }
    var configuration: AKPlayerConfigurationProtocol { get }
    var delegate: AKPlayerManagerDelegate? { get set }
    var playerStateSnapshot: AKPlayerStateSnapshot? { get }
    var audioSessionService: AKAudioSessionServiceProtocol { get }
    
    func prepare() throws
    
    func setNowPlayingInfo()
    func currentNowPlayingMetadata() -> AKNowPlayableMetadata?
    func getNowPlayableDynamicMetadata() -> AKNowPlayableDynamicMetadataProtocol?
}

// MARK: - AKPlayerStateSnapshot

/// Thread-safe snapshot capturing player state before lifecycle interruptions or audio session events.
public struct AKPlayerStateSnapshot: Sendable {
    public var shouldResume: Bool
    public var applicationState: AKApplicationLifeCycleState
    public var playbackInterruptionReason: AKPlaybackInterruptionReason
    
    public init(
        shouldResume: Bool,
        applicationState: AKApplicationLifeCycleState,
        playbackInterruptionReason: AKPlaybackInterruptionReason
    ) {
        self.shouldResume = shouldResume
        self.applicationState = applicationState
        self.playbackInterruptionReason = playbackInterruptionReason
    }
}

// MARK: - AKPlaybackInterruptionReason

/// Enumeration representing reasons for playback interruption.
public enum AKPlaybackInterruptionReason: UInt, Sendable {
    case audioSessionInterruption
    case applicationResignActive
    case applicationEnteredBackground
    
    public var isLifeCycleEvent: Bool {
        return self == .applicationEnteredBackground || self == .applicationResignActive
    }
}
