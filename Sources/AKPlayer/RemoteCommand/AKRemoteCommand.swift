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

/// Closure type for handling MPRemoteCommandCenter events.
public typealias AKRemoteCommandHandler = @MainActor @Sendable (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus

/// Represents remote commands exposed by MPRemoteCommandCenter.
public enum AKRemoteCommand: Hashable, Sendable {
    
    // MARK: - Playback Commands
    case play
    case pause
    case stop
    case togglePlayPause
    
    // MARK: - Navigation Commands
    case nextTrack
    case previousTrack
    case changeRepeatMode
    case changeShuffleMode
    
    // MARK: - Seeking Commands
    case changePlaybackRate(supportedPlaybackRates: [Float])
    case seekBackward
    case seekForward
    case skipBackward(preferredIntervals: [TimeInterval])
    case skipForward(preferredIntervals: [TimeInterval])
    case changePlaybackPosition
    
    // MARK: - Rating/Feedback Commands
    case rating
    case like
    case dislike
    case bookmark
    
    // MARK: - Language Commands
    case enableLanguageOption
    case disableLanguageOption
}

// MARK: - Command Metadata

extension AKRemoteCommand {
    
    /// Strongly typed metadata for accessing MPRemoteCommand properties with compile-time safety.
    public struct CommandMetadata: Sendable {
        public let id: String
        public let name: String
        public let getCommand: @Sendable @MainActor (MPRemoteCommandCenter) -> MPRemoteCommand
    }
    
    /// Metadata mapping each enum case to its identifier, human-readable name, and accessor closure.
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
    
    /// Unique String identifier for command indexing.
    public var id: String {
        return metadata.id
    }
    
    /// Human-readable display name.
    public var name: String {
        return metadata.name
    }
}

// MARK: - Command Presets

extension AKRemoteCommand {
    
    /// Basic playback controls: Play, Pause, Stop, Toggle
    public static var playbackCommands: [AKRemoteCommand] {
        [.play, .pause, .stop, .togglePlayPause]
    }
    
    /// Track navigation: Next, Previous, Repeat, Shuffle
    public static var trackNavigationCommands: [AKRemoteCommand] {
        [.nextTrack, .previousTrack, .changeRepeatMode, .changeShuffleMode]
    }
    
    /// Seeking with custom interval settings
    public static func seekingCommands(intervals: [TimeInterval] = [15.0]) -> [AKRemoteCommand] {
        [
            .skipBackward(preferredIntervals: intervals),
            .skipForward(preferredIntervals: intervals),
            .changePlaybackPosition,
            .seekBackward,
            .seekForward
        ]
    }
    
    /// Feedback: Like, Dislike, Bookmark, Rating
    public static var feedbackCommands: [AKRemoteCommand] {
        [.like, .dislike, .bookmark, .rating]
    }
    
    /// Language & Subtitle selection options
    public static var languageCommands: [AKRemoteCommand] {
        [.enableLanguageOption, .disableLanguageOption]
    }
    
    /// Standard preset for Podcasts, Music, and Audiobooks
    public static var standardAudioPreset: [AKRemoteCommand] {
        [
            .play, .pause, .togglePlayPause,
            .skipBackward(preferredIntervals: [15.0]),
            .skipForward(preferredIntervals: [15.0]),
            .changePlaybackPosition,
            .changePlaybackRate(supportedPlaybackRates: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
        ]
    }
    
    /// Standard preset for Video playback
    public static var standardVideoPreset: [AKRemoteCommand] {
        [
            .play, .pause, .togglePlayPause,
            .seekBackward, .seekForward,
            .skipBackward(preferredIntervals: [10.0]),
            .skipForward(preferredIntervals: [10.0]),
            .changePlaybackPosition
        ]
    }
    
    /// Array containing default representation of all available commands
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
