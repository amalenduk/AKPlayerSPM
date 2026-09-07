//
//  AKPlayerProtocol.swift
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
import Foundation

// MARK: - AKPlayerProtocol

/// Protocol defining the main player instance properties, playback metrics, and
/// boundary observation capabilities.
@MainActor
public protocol AKPlayerProtocol: AnyObject, AKPlayerActionsProtocol {
  // MARK: - Core Properties

  /// The underlying `AVPlayer` instance managing media playback.
  var player: AVPlayer { get }

  /// The current playback state of the player (e.g., idle, playing, paused,
  /// stopped, failed).
  var state: AKPlayerState { get }

  /// The default playback rate used when initiating or resuming normal
  /// playback.
  var defaultRate: AKPlaybackRate { get set }

  /// The active playback rate speed multiplier (1.0 = normal, 0.0 = paused).
  var rate: AKPlaybackRate { get set }

  /// The currently active playable media item conforming to `AKPlayable`.
  var currentMedia: (any AKPlayable)? { get }

  /// The currently active `AVPlayerItem` loaded in the player queue.
  var currentItem: AVPlayerItem? { get }

  /// The total duration of the currently loaded media item as `CMTime`.
  var currentItemDuration: CMTime { get }

  /// The current playback position in time as `CMTime`.
  var currentTime: CMTime { get }

  /// The remaining playback time duration of the active item, if available.
  var remainingTime: CMTime? { get }

  /// Flag indicating whether media playback starts automatically upon
  /// loading.
  var autoPlay: Bool { get }

  /// Flag indicating whether a seek action is currently in progress.
  var isSeeking: Bool { get }

  /// The most recent seek target requested by the caller.
  var lastRequestedSeekPosition: AKSeekTarget? { get }

  /// The current audio output volume level, ranging from `0.0` (silent) to
  /// `1.0` (maximum).
  var volume: Float { get set }

  /// Flag indicating whether player audio output is muted.
  var isMuted: Bool { get set }

  /// Contains error details if a failure occurs during initialization or
  /// playback.
  var error: AKPlayerError? { get }

  /// An asynchronous sequence of player lifecycle and playback events.
  var events: AsyncStream<AKPlayerEvent> { get }

  // MARK: - Boundary Time Observers

  /// Registers a boundary time observer to trigger notifications when
  /// playback reaches explicit time markers.
  /// - Parameter times: An array of target `CMTime` markers to observe during
  /// playback.
  func addBoundaryTimeObserver(for times: [CMTime])

  /// Removes the currently registered boundary time observer from the
  /// underlying player instance.
  func removeBoundaryTimeObserver()
}
