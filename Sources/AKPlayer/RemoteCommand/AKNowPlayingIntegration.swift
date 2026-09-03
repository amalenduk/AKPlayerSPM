//
//  AKNowPlayingIntegration.swift
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
import MediaPlayer

// MARK: - Integration with AKPlayer

/// Extension to AKPlayer for convenient Now Playing session setup.
extension AKPlayer {
    
    /// Configures Now Playing with a preset configuration.
    public func configureNowPlaying(with configuration: AKNowPlayingCommandConfiguration) async {
        guard let session = nowPlayingSession else { return }
        await session.applyConfiguration(configuration)
    }
}

// MARK: - Protocol for Manager

/// Protocol to be added to AKPlayerManager for Now Playing session integration.
public protocol AKNowPlayingSessionProvider: AnyObject {
    var nowPlayingSession: AKNowPlayingSession? { get }
}

// MARK: - Command Preset Manager

/// Manages predefined command presets for different use cases.
public struct AKNowPlayingCommandPresets {
    
    /// Preset: Minimal playback controls only
    public static func minimal() -> AKNowPlayingCommandConfiguration {
        return AKNowPlayingCommandConfiguration.minimal()
    }
    
    /// Preset: Standard music streaming
    public static func music() -> AKNowPlayingCommandConfiguration {
        return AKNowPlayingCommandConfiguration.audio()
    }
    
    /// Preset: Podcast with 15-second skip back, 30-second skip forward
    public static func podcast() -> AKNowPlayingCommandConfiguration {
        return AKNowPlayingCommandConfiguration.audio()
            .add(.skipBackward(preferredIntervals: [15.0]))
            .add(.skipForward(preferredIntervals: [30.0]))
            .disable(.changeShuffleMode)
    }
    
    /// Preset: Audiobook with bookmarking
    public static func audiobook() -> AKNowPlayingCommandConfiguration {
        return AKNowPlayingCommandConfiguration.audio()
            .add(.bookmark)
            .disable(.changeShuffleMode)
    }
    
    /// Preset: Standard video playback
    public static func video() -> AKNowPlayingCommandConfiguration {
        return AKNowPlayingCommandConfiguration.video()
    }
    
    /// Preset: Live stream (no seeking)
    public static func livestream() -> AKNowPlayingCommandConfiguration {
        return AKNowPlayingCommandConfiguration.audio()
            .disable(.seekBackward)
            .disable(.seekForward)
            .disable(.changePlaybackPosition)
    }
}
