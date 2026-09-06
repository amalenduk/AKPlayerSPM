//
//  AKPlayerActionsProtocol.swift
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
import CoreMedia

/// Defines player control actions including loading media, playback control, and seeking.
@MainActor
public protocol AKPlayerActionsProtocol {
    
    // MARK: - Loading Media
    
    /// Loads a playable item with optional auto-play and starting position.
    ///
    /// - Parameters:
    ///   - media: The media item conforming to `AKPlayable`.
    ///   - autoPlay: If `true`, playback starts automatically once loaded. Defaults to `false`.
    ///   - position: An optional starting seek target position upon loading.
    func load(
        media: any AKPlayable,
        autoPlay: Bool,
        at position: AKSeekTarget?
    )
    
    // MARK: - Controlling Playback
    
    /// Starts or resumes media playback.
    func play()
    
    /// Plays media at a specified rate.
    /// - Parameter rate: The target playback rate.
    func play(at rate: AKPlaybackRate)
    
    /// Pauses media playback.
    func pause()
    
    /// Toggles between play and pause states based on current playback status.
    func togglePlayPause()
    
    /// Stops media playback and resets player state.
    func stop()
    
    // MARK: - Seeking Through Media
    
    /// Seeks to a designated target position asynchronously.
    ///
    /// - Parameter target: The destination target (`.time`, `.seconds`, `.offset`, or `.percentage`).
    /// - Returns: `true` if the seek operation completed successfully without being superseded.
    @discardableResult
    func seek(to target: AKSeekTarget) async -> Bool
    
    /// Seeks to a designated target position asynchronously with custom tolerance bounds.
    ///
    /// - Parameters:
    ///   - target: The destination target (`.time`, `.seconds`, `.offset`, or `.percentage`).
    ///   - toleranceBefore: The allowable tolerance before the target time.
    ///   - toleranceAfter: The allowable tolerance after the target time.
    /// - Returns: `true` if the seek operation completed successfully without being superseded.
    @discardableResult
    func seek(
        to target: AKSeekTarget,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime
    ) async -> Bool
    
    // MARK: - Seeking Through Media (Completion Handler Overloads)
    
    /// Seeks to a designated target position with a completion handler callback.
    ///
    /// - Parameters:
    ///   - target: The destination target (`.time`, `.seconds`, `.offset`, or `.percentage`).
    ///   - completionHandler: A callback invoked when the seek operation completes or is canceled, receiving a boolean indicating success.
    func seek(
        to target: AKSeekTarget,
        completionHandler: @escaping @Sendable (Bool) -> Void
    )
    
    /// Seeks to a designated target position with custom tolerance bounds and a completion handler callback.
    ///
    /// - Parameters:
    ///   - target: The destination target (`.time`, `.seconds`, `.offset`, or `.percentage`).
    ///   - toleranceBefore: The allowable tolerance before the target time.
    ///   - toleranceAfter: The allowable tolerance after the target time.
    ///   - completionHandler: A callback invoked when the seek operation completes or is canceled, receiving a boolean indicating success.
    func seek(
        to target: AKSeekTarget,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime,
        completionHandler: @escaping @Sendable (Bool) -> Void
    )
    
    // MARK: - Media Navigation
    
    /// Steps forward or backward by a specific frame count.
    /// - Parameter count: The number of frames to step (positive for forward, negative for backward).
    func step(by count: Int)
    
    /// Fast forwards playback at default rate.
    func fastForward()
    
    /// Fast forwards playback at a specified rate.
    /// - Parameter rate: The speed rate for fast forwarding.
    func fastForward(at rate: AKPlaybackRate)
    
    /// Rewinds playback at default rate.
    func rewind()
    
    /// Rewinds playback at a specified rate.
    /// - Parameter rate: The speed rate for rewinding.
    func rewind(at rate: AKPlaybackRate)
}

// MARK: - Default Parameters Extension

public extension AKPlayerActionsProtocol {
    /// Convenience default implementation for loading media without autoPlay or position parameters.
    func load(media: any AKPlayable) {
        load(media: media, autoPlay: false, at: nil)
    }
    
    /// Convenience default implementation for loading media without position parameters.
    func load(media: any AKPlayable, autoPlay: Bool) {
        load(media: media, autoPlay: autoPlay, at: nil)
    }
}
