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

public typealias AKRemoteCommandHandler = (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus

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
    case changePlaybackRate(supportedPlaybackRates: [NSNumber])
    case seekBackward
    case seekForward
    case skipBackward(preferredIntervals: [NSNumber])
    case skipForward(preferredIntervals: [NSNumber])
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
    
    // MARK: - Types
    
    public struct CommandMetadata {
        let id: String
        let name: String
        let keyPath: AnyKeyPath // Type-erased keypath to MPRemoteCommand
    }
    
    /// Metadata for each command including MPRemoteCommandCenter keypath and config
    var metadata: CommandMetadata {
        switch self {
        case .play:
            return CommandMetadata(
                id: "play",
                name: "Play",
                keyPath: \MPRemoteCommandCenter.playCommand
            )
        case .pause:
            return CommandMetadata(
                id: "pause",
                name: "Pause",
                keyPath: \MPRemoteCommandCenter.pauseCommand
            )
        case .stop:
            return CommandMetadata(
                id: "stop",
                name: "Stop",
                keyPath: \MPRemoteCommandCenter.stopCommand
            )
        case .togglePlayPause:
            return CommandMetadata(
                id: "togglePlayPause",
                name: "Toggle Play/Pause",
                keyPath: \MPRemoteCommandCenter.togglePlayPauseCommand
            )
        case .nextTrack:
            return CommandMetadata(
                id: "nextTrack",
                name: "Next Track",
                keyPath: \MPRemoteCommandCenter.nextTrackCommand
            )
        case .previousTrack:
            return CommandMetadata(
                id: "previousTrack",
                name: "Previous Track",
                keyPath: \MPRemoteCommandCenter.previousTrackCommand
            )
        case .changeRepeatMode:
            return CommandMetadata(
                id: "changeRepeatMode",
                name: "Change Repeat Mode",
                keyPath: \MPRemoteCommandCenter.changeRepeatModeCommand
            )
        case .changeShuffleMode:
            return CommandMetadata(
                id: "changeShuffleMode",
                name: "Change Shuffle Mode",
                keyPath: \MPRemoteCommandCenter.changeShuffleModeCommand
            )
        case .changePlaybackRate:
            return CommandMetadata(
                id: "changePlaybackRate",
                name: "Change Playback Rate",
                keyPath: \MPRemoteCommandCenter.changePlaybackRateCommand
            )
        case .seekBackward:
            return CommandMetadata(
                id: "seekBackward",
                name: "Seek Backward",
                keyPath: \MPRemoteCommandCenter.seekBackwardCommand
            )
        case .seekForward:
            return CommandMetadata(
                id: "seekForward",
                name: "Seek Forward",
                keyPath: \MPRemoteCommandCenter.seekForwardCommand
            )
        case .skipBackward:
            return CommandMetadata(
                id: "skipBackward",
                name: "Skip Backward",
                keyPath: \MPRemoteCommandCenter.skipBackwardCommand
            )
        case .skipForward:
            return CommandMetadata(
                id: "skipForward",
                name: "Skip Forward",
                keyPath: \MPRemoteCommandCenter.skipForwardCommand
            )
        case .changePlaybackPosition:
            return CommandMetadata(
                id: "changePlaybackPosition",
                name: "Change Playback Position",
                keyPath: \MPRemoteCommandCenter.changePlaybackPositionCommand
            )
        case .rating:
            return CommandMetadata(
                id: "rating",
                name: "Rating",
                keyPath: \MPRemoteCommandCenter.ratingCommand
            )
        case .like:
            return CommandMetadata(
                id: "like",
                name: "Like",
                keyPath: \MPRemoteCommandCenter.likeCommand
            )
        case .dislike:
            return CommandMetadata(
                id: "dislike",
                name: "Dislike",
                keyPath: \MPRemoteCommandCenter.dislikeCommand
            )
        case .bookmark:
            return CommandMetadata(
                id: "bookmark",
                name: "Bookmark",
                keyPath: \MPRemoteCommandCenter.bookmarkCommand
            )
        case .enableLanguageOption:
            return CommandMetadata(
                id: "enableLanguageOption",
                name: "Enable Language Option",
                keyPath: \MPRemoteCommandCenter.enableLanguageOptionCommand
            )
        case .disableLanguageOption:
            return CommandMetadata(
                id: "disableLanguageOption",
                name: "Disable Language Option",
                keyPath: \MPRemoteCommandCenter.disableLanguageOptionCommand
            )
        }
    }
    
    /// Unique identifier for this command
    var id: String {
        return metadata.id
    }
    
    /// Human-readable name
    var name: String {
        return metadata.name
    }
}

// MARK: - Command Presets

extension AKRemoteCommand {
    
    /// Basic playback controls: Play, Pause, Stop, Toggle
    public static var playbackCommands: [AKRemoteCommand] {
        return [.play, .pause, .stop, .togglePlayPause]
    }
    
    /// Track navigation: Next, Previous, Repeat, Shuffle
    public static var trackNavigationCommands: [AKRemoteCommand] {
        return [.nextTrack, .previousTrack, .changeRepeatMode, .changeShuffleMode]
    }
    
    /// Seeking with custom intervals
    public static func seekingCommands(intervals: [Double] = [15.0]) -> [AKRemoteCommand] {
        let numberIntervals = intervals.map { NSNumber(value: $0) }
        return [
            .skipBackward(preferredIntervals: numberIntervals),
            .skipForward(preferredIntervals: numberIntervals),
            .changePlaybackPosition,
            .seekBackward,
            .seekForward
        ]
    }
    
    /// Feedback: Like, Dislike, Bookmark, Rating
    public static var feedbackCommands: [AKRemoteCommand] {
        return [.like, .dislike, .bookmark, .rating]
    }
    
    /// Language/Subtitle options
    public static var languageCommands: [AKRemoteCommand] {
        return [.enableLanguageOption, .disableLanguageOption]
    }
    
    /// Recommended audio preset (Music, Podcast, Audiobook)
    public static var standardAudioPreset: [AKRemoteCommand] {
        return [
            .play, .pause, .togglePlayPause,
            .skipBackward(preferredIntervals: [15.0]),
            .skipForward(preferredIntervals: [15.0]),
            .changePlaybackPosition,
            .changePlaybackRate(supportedPlaybackRates: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
        ]
    }
    
    /// Recommended video preset
    public static var standardVideoPreset: [AKRemoteCommand] {
        return [
            .play, .pause, .togglePlayPause,
            .seekBackward, .seekForward,
            .skipBackward(preferredIntervals: [10.0]),
            .skipForward(preferredIntervals: [10.0]),
            .changePlaybackPosition
        ]
    }
    
    /// All available commands
    public static func all() -> [AKRemoteCommand] {
        return [
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

// MARK: - Hashable Conformance

extension AKRemoteCommand {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: AKRemoteCommand, rhs: AKRemoteCommand) -> Bool {
        return lhs.id == rhs.id
    }
}
