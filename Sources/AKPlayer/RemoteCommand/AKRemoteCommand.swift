//
//  AKRemoteCommand.swift
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
import MediaPlayer

// MARK: - Handlers & Types

/// A closure type responsible for handling incoming `MPRemoteCommandEvent` requests from system media controls.
/// Executes on the main actor and is thread-safe (`@Sendable`).
public typealias AKRemoteCommandHandler = @MainActor @Sendable (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus

/// Represents the exhaustive set of remote media commands exposed by `MPRemoteCommandCenter`.
/// Used to define, configure, and route system-level commands with parameter payload support.
public enum AKRemoteCommand: Hashable, Sendable {
    
    // MARK: - Playback Commands
    
    /// Command to resume or begin audio/video playback.
    case play
    /// Command to suspend active playback temporarily.
    case pause
    /// Command to completely terminate playback.
    case stop
    /// Command to toggle between playing and paused states.
    case togglePlayPause
    
    // MARK: - Navigation Commands
    
    /// Command to jump to the subsequent track or item in a queue.
    case nextTrack
    /// Command to return to the preceding track or restart the current track.
    case previousTrack
    /// Command to modify the playback loop repeat behavior.
    case changeRepeatMode
    /// Command to alter the playback order configuration.
    case changeShuffleMode
    
    // MARK: - Seeking Commands
    
    /// Command to modify playback speed, featuring supported playback rate configurations.
    case changePlaybackRate(supportedPlaybackRates: [Float])
    /// Command to continuously seek backward through media.
    case seekBackward
    /// Command to continuously seek forward through media.
    case seekForward
    /// Command to jump backward by specific time intervals.
    case skipBackward(preferredIntervals: [TimeInterval])
    /// Command to jump forward by specific time intervals.
    case skipForward(preferredIntervals: [TimeInterval])
    /// Command to move playback instantly to a specific elapsed time position.
    case changePlaybackPosition
    
    // MARK: - Rating/Feedback Commands
    
    /// Command to apply a rating score to the active media item.
    case rating
    /// Command to mark the current track as favorited or liked.
    case like
    /// Command to flag the current track as disliked.
    case dislike
    /// Command to save a bookmark marker within the media stream.
    case bookmark
    
    // MARK: - Language Commands
    
    /// Command to activate a specific audio language track or subtitle option.
    case enableLanguageOption
    /// Command to deactivate an active language or subtitle option.
    case disableLanguageOption
}

// MARK: - Command Metadata

extension AKRemoteCommand {
    
    /// A structured container defining strong type references and accessors for individual remote commands.
    public struct CommandMetadata: Sendable {
        /// Unique string representation identifier for the command.
        public let id: String
        /// Human-readable title string describing the command option.
        public let name: String
        /// Closure block resolving the corresponding `MPRemoteCommand` instance from a target `MPRemoteCommandCenter`.
        public let getCommand: @Sendable @MainActor (MPRemoteCommandCenter) -> MPRemoteCommand
    }
    
    /// Retrieves full structured metadata for the current command case.
    public var metadata: CommandMetadata {
        switch self {
        case .play:
            return CommandMetadata(id: "play", name: "Play", getCommand: { $0.playCommand })
        case .pause:
            return CommandMetadata(id: "pause", name: "Pause", getCommand: { $0.pauseCommand })
        case .stop:
            return CommandMetadata(id: "stop", name: "Stop", getCommand: { $0.stopCommand })
        case .togglePlayPause:
            return CommandMetadata(id: "togglePlayPause", name: "Toggle Play/Pause", getCommand: { $0.togglePlayPauseCommand })
        case .nextTrack:
            return CommandMetadata(id: "nextTrack", name: "Next Track", getCommand: { $0.nextTrackCommand })
        case .previousTrack:
            return CommandMetadata(id: "previousTrack", name: "Previous Track", getCommand: { $0.previousTrackCommand })
        case .changeRepeatMode:
            return CommandMetadata(id: "changeRepeatMode", name: "Change Repeat Mode", getCommand: { $0.changeRepeatModeCommand })
        case .changeShuffleMode:
            return CommandMetadata(id: "changeShuffleMode", name: "Change Shuffle Mode", getCommand: { $0.changeShuffleModeCommand })
        case .changePlaybackRate:
            return CommandMetadata(id: "changePlaybackRate", name: "Change Playback Rate", getCommand: { $0.changePlaybackRateCommand })
        case .seekBackward:
            return CommandMetadata(id: "seekBackward", name: "Seek Backward", getCommand: { $0.seekBackwardCommand })
        case .seekForward:
            return CommandMetadata(id: "seekForward", name: "Seek Forward", getCommand: { $0.seekForwardCommand })
        case .skipBackward:
            return CommandMetadata(id: "skipBackward", name: "Skip Backward", getCommand: { $0.skipBackwardCommand })
        case .skipForward:
            return CommandMetadata(id: "skipForward", name: "Skip Forward", getCommand: { $0.skipForwardCommand })
        case .changePlaybackPosition:
            return CommandMetadata(id: "changePlaybackPosition", name: "Change Playback Position", getCommand: { $0.changePlaybackPositionCommand })
        case .rating:
            return CommandMetadata(id: "rating", name: "Rating", getCommand: { $0.ratingCommand })
        case .like:
            return CommandMetadata(id: "like", name: "Like", getCommand: { $0.likeCommand })
        case .dislike:
            return CommandMetadata(id: "dislike", name: "Dislike", getCommand: { $0.dislikeCommand })
        case .bookmark:
            return CommandMetadata(id: "bookmark", name: "Bookmark", getCommand: { $0.bookmarkCommand })
        case .enableLanguageOption:
            return CommandMetadata(id: "enableLanguageOption", name: "Enable Language Option", getCommand: { $0.enableLanguageOptionCommand })
        case .disableLanguageOption:
            return CommandMetadata(id: "disableLanguageOption", name: "Disable Language Option", getCommand: { $0.disableLanguageOptionCommand })
        }
    }
    
    /// A unique string representation ID associated with the command type.
    public var id: String {
        return metadata.id
    }
    
    /// A localized, human-friendly string label for displaying the command.
    public var name: String {
        return metadata.name
    }
}

// MARK: - Command Presets

extension AKRemoteCommand {
    
    /// A standard array grouping core playback controls (`play`, `pause`, `stop`, `togglePlayPause`).
    public static var playbackCommands: [AKRemoteCommand] {
        [.play, .pause, .stop, .togglePlayPause]
    }
    
    /// A grouped preset configuration for track navigation (`nextTrack`, `previousTrack`, `changeRepeatMode`, `changeShuffleMode`).
    public static var trackNavigationCommands: [AKRemoteCommand] {
        [.nextTrack, .previousTrack, .changeRepeatMode, .changeShuffleMode]
    }
    
    /// Generates a set of seeking and jumping commands configured with custom jump intervals.
    /// - Parameter intervals: Array of skip intervals in seconds. Defaults to `[15.0]`.
    /// - Returns: An array containing configured seeking commands.
    public static func seekingCommands(intervals: [TimeInterval] = [15.0]) -> [AKRemoteCommand] {
        [
            .skipBackward(preferredIntervals: intervals),
            .skipForward(preferredIntervals: intervals),
            .changePlaybackPosition,
            .seekBackward,
            .seekForward
        ]
    }
    
    /// A preset collection containing feedback actions (`like`, `dislike`, `bookmark`, `rating`).
    public static var feedbackCommands: [AKRemoteCommand] {
        [.like, .dislike, .bookmark, .rating]
    }
    
    /// A preset collection managing language tracks and subtitle configurations.
    public static var languageCommands: [AKRemoteCommand] {
        [.enableLanguageOption, .disableLanguageOption]
    }
    
    /// A comprehensive standard command preset tailored for general audio streams, podcasts, and audiobooks.
    public static var standardAudioPreset: [AKRemoteCommand] {
        [
            .play, .pause, .togglePlayPause,
            .skipBackward(preferredIntervals: [15.0]),
            .skipForward(preferredIntervals: [15.0]),
            .changePlaybackPosition,
            .changePlaybackRate(supportedPlaybackRates: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
        ]
    }
    
    /// A standard preset option optimized for video streaming applications.
    public static var standardVideoPreset: [AKRemoteCommand] {
        [
            .play, .pause, .togglePlayPause,
            .seekBackward, .seekForward,
            .skipBackward(preferredIntervals: [10.0]),
            .skipForward(preferredIntervals: [10.0]),
            .changePlaybackPosition
        ]
    }
    
    /// Returns an exhaustive array representing every defined remote command variant.
    public static func all() -> [AKRemoteCommand] {
        [
            .play, .pause, .stop, .togglePlayPause,
            .nextTrack, .previousTrack,
            .changeRepeatMode, .changeShuffleMode,
            .changePlaybackRate(supportedPlaybackRates: []),
            .seekBackward, .seekForward,
            .skipBackward(preferredIntervals: []),
            .skipForward(preferredIntervals: []),
            .changePlaybackPosition,
            .rating, .like, .dislike, .bookmark,
            .enableLanguageOption, .disableLanguageOption
        ]
    }
}
