//
//  AKPlayerProtocol.swift
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

/// Protocol defining the main player instance properties and observation capabilities.
@MainActor
public protocol AKPlayerProtocol: AnyObject, AKPlayerActionsProtocol {
    
    // MARK: - Core Properties
    
    /// The underlying `AVPlayer` instance managing playback.
    var player: AVPlayer { get }
    
    /// The current state of the player.
    var state: AKPlayerState { get }
    
    /// The default playback rate when normal playback resumes.
    var defaultRate: AKPlaybackRate { get set }
    
    /// The active playback rate multiplier.
    var rate: AKPlaybackRate { get set }
    
    /// The currently active playable media item.
    var currentMedia: (any AKPlayable)? { get }
    
    /// The currently active player item in the player queue.
    var currentItem: AVPlayerItem? { get }
    
    /// The duration of the current player item.
    var currentItemDuration: CMTime { get }
    
    /// The current playback time offset.
    var currentTime: CMTime { get }
    
    /// The remaining duration available in the current player item.
    var remainingTime: CMTime? { get }
    
    /// Flag indicating whether playback should start automatically once media is ready.
    var autoPlay: Bool { get }
    
    /// Flag indicating whether a seek operation is currently in progress.
    var isSeeking: Bool { get }
    
    /// The most recent seek target requested by the caller.
    var lastRequestedSeekPosition: AKSeekTarget? { get }
    
    /// Output volume of the player (0.0 to 1.0).
    var volume: Float { get set }
    
    /// Flag indicating whether output audio is muted.
    var isMuted: Bool { get set }
    
    /// Current error status of the player, if any.
    var error: AKPlayerError? { get }
    
    // MARK: - Boundary Time Observers
    
    /// Adds a boundary time observer for specified playback time intervals.
    /// - Parameter times: An array of boundary `CMTime` values.
    func addBoundaryTimeObserver(for times: [CMTime])
    
    /// Removes the currently registered boundary time observer.
    func removeBoundaryTimeObserver()
}
