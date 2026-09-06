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

import AVFoundation
import Foundation
import MediaPlayer

// MARK: - AKPlayerManagerDelegate

/// Delegate protocol to receive state, media, rate, time, and error events from an `AKPlayerManagerProtocol`.
@MainActor
public protocol AKPlayerManagerDelegate: AnyObject {
    
    /// Called when the player's playback state changes.
    /// - Parameters:
    ///   - playerManager: The manager instance reporting the state update.
    ///   - state: The new playback state (e.g., playing, paused, stopped, failed).
    func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangeStateTo state: AKPlayerState
    )
    
    /// Called when the currently active media item changes.
    /// - Parameters:
    ///   - playerManager: The manager instance updating its active media.
    ///   - media: The new playable media item.
    func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangeMediaTo media: any AKPlayable
    )
    
    /// Called when the playback rate changes.
    /// - Parameters:
    ///   - playerManager: The manager instance changing playback speed.
    ///   - newRate: The newly applied playback rate.
    ///   - oldRate: The previously active playback rate.
    func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangePlaybackRateTo newRate: AKPlaybackRate,
        from oldRate: AKPlaybackRate
    )
    
    /// Called periodically during playback as the current playback position advances.
    /// - Parameters:
    ///   - playerManager: The manager instance updating playback position.
    ///   - currentTime: The current playback timestamp as `CMTime`.
    ///   - media: The playable item currently being evaluated.
    func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangeCurrentTimeTo currentTime: CMTime,
        for media: any AKPlayable
    )
    
    /// Called when playback crosses a registered boundary time marker.
    /// - Parameters:
    ///   - playerManager: The manager instance crossing the boundary timestamp.
    ///   - time: The boundary time marker that was reached.
    ///   - media: The active media item associated with the boundary notification.
    func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didInvokeBoundaryTimeObserverAt time: CMTime,
        for media: any AKPlayable
    )
    
    /// Called when playback reaches the end of the current media duration.
    /// - Parameters:
    ///   - playerManager: The manager instance completing media playback.
    ///   - time: The final timestamp reached at completion.
    ///   - media: The media item that finished playing.
    func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didReachEndAt time: CMTime,
        for media: any AKPlayable
    )
    
    /// Called when the player output volume level changes.
    /// - Parameters:
    ///   - playerManager: The manager instance updating its volume level.
    ///   - volume: The updated output volume (0.0 to 1.0).
    func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangeVolumeTo volume: Float
    )
    
    /// Called when the player audio output is muted or unmuted.
    /// - Parameters:
    ///   - playerManager: The manager instance toggling mute status.
    ///   - isMuted: `true` if audio output is muted; `false` otherwise.
    func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangeMutedStatusTo isMuted: Bool
    )
    
    /// Called when a requested player command or user interaction cannot be executed.
    /// - Parameters:
    ///   - playerManager: The manager instance rejecting the command.
    ///   - reason: The specific reason explaining why the action was rejected.
    func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didEncounterUnavailableAction reason: AKPlayerUnavailableCommandReason
    )
    
    /// Called when an unrecoverable error occurs during media loading or playback.
    /// - Parameters:
    ///   - playerManager: The manager instance reporting the error.
    ///   - error: The player error describing the failure state.
    func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didFailWith error: AKPlayerError
    )
}

// MARK: - AKPlayerManagerProtocol

/// Primary management protocol exposing high-level player control and now-playing integration.
@MainActor
public protocol AKPlayerManagerProtocol: AKPlayerProtocol, AKPlayerActionsProtocol, AKNowPlayingSessionProvider {
    
    /// The underlying controller managing AVPlayer state machine operations and commands.
    var playerController: AKPlayerControllerProtocol { get }
    
    /// Configuration options specifying audio session, remote command, and playback behaviors.
    var configuration: AKPlayerConfigurationProtocol { get }
    
    /// Delegate receiver for observing player state updates, time updates, and error events.
    var delegate: AKPlayerManagerDelegate? { get set }
    
    /// Active state snapshot storing playback and app states during interruptions for auto-resumption.
    var playerStateSnapshot: AKPlayerStateSnapshot? { get }
    
    /// Service interface handling system `AVAudioSession` categories, modes, and activation logic.
    var audioSessionService: AKAudioSessionServiceProtocol { get }
    
    /// Configures the audio session, registers observers, and prepares the player for immediate use.
    /// - Throws: `AKPlayerError` or `AVAudioSession` initialization failures if preparation fails.
    func prepare() throws
    
    /// Updates lock screen and Control Center media metadata using `MPNowPlayingInfoCenter`.
    func setNowPlayingInfo()
    
    /// Retrieves current static and dynamic metadata payload used for system Now Playing integration.
    /// - Returns: Built `AKNowPlayableMetadata` container, or `nil` if no active item is loaded.
    func currentNowPlayingMetadata() -> AKNowPlayableMetadata?
    
    /// Generates current dynamic state metadata like playback position, duration, and rate.
    /// - Returns: Protocol implementation containing active dynamic values, or `nil`.
    func getNowPlayableDynamicMetadata() -> (any AKNowPlayableDynamicMetadataProtocol)?
}

// MARK: - AKPlayerStateSnapshot

/// Thread-safe snapshot capturing player state before lifecycle interruptions or audio session events.
public struct AKPlayerStateSnapshot: Sendable {
    
    /// Indicates whether playback should automatically resume when an interruption resolves.
    public var shouldResume: Bool
    
    /// The lifecycle state of the application at the precise moment the snapshot was saved.
    public var applicationState: AKApplicationLifeCycleState
    
    /// The underlying event or system notification that caused the interruption.
    public var playbackInterruptionReason: AKPlaybackInterruptionReason
    
    /// Initializes a new instance of `AKPlayerStateSnapshot`.
    /// - Parameters:
    ///   - shouldResume: Flag dictating if playback resumes after the interruption ends.
    ///   - applicationState: Current application state at snapshot creation time.
    ///   - playbackInterruptionReason: The reason triggering the state capture.
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
    
    /// Interruption caused by an external audio session event (e.g., incoming phone call, alarm).
    case audioSessionInterruption
    
    /// Interruption caused when the application resigns active status (e.g., opening Control Center).
    case applicationResignActive
    
    /// Interruption caused when the application transitions into the background.
    case applicationEnteredBackground
    
    /// Flag indicating whether the interruption was caused directly by an app lifecycle event.
    public var isLifeCycleEvent: Bool {
        return self == .applicationEnteredBackground || self == .applicationResignActive
    }
}
