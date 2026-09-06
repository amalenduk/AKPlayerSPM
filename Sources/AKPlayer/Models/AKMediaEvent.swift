//
//  AKMediaEvent.swift
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
import CoreGraphics

// MARK: - AKMediaCapability

/// Capabilities that express what playback actions an AVPlayerItem currently supports.
public enum AKMediaCapability: String, Sendable, Hashable, Equatable, CaseIterable {
    case playReverse
    case playFastForward
    case playFastReverse
    case playSlowForward
    case playSlowReverse
    case stepForward
    case stepBackward
}


// MARK: - AKMediaEvent

/// Events emitted by an active media item (`AKPlayable`) as its state, tracks, or AVPlayerItem observations update.
public enum AKMediaEvent: Sendable {
    
    // MARK: - State & Duration
    
    /// The media's internal lifecycle state updated (e.g., loading, readyToPlay, failed).
    case stateDidChange(AKPlayableState)
    
    /// The media duration updated or became known.
    case durationDidChange(CMTime)
    
    /// The underlying CMTimebase updated or was invalidated.
    case timebaseDidChange(CMTimebase?)
    
    // MARK: - Capabilities
    
    /// A specific playback capability status changed (e.g., fast-forward becoming available or restricted).
    case capabilityDidChange(AKMediaCapability, isSupported: Bool)
    
    // MARK: - Range Updates
    
    /// The buffered time ranges loaded by AVPlayerItem updated.
    case loadedTimeRangesDidChange([CMTimeRange])
    
    /// The seekable time ranges of the AVPlayerItem updated.
    case seekableTimeRangesDidChange([CMTimeRange])
    
    // MARK: - Asset Attributes
    
    /// The available AVPlayerItemTrack list updated (e.g., audio, video, subtitle tracks loaded).
    case tracksDidChange([AVPlayerItemTrack])
    
    /// The native video pixel/presentation resolution updated.
    case presentationSizeDidChange(CGSize)
}
