//
//  AKPlayerSeekingThroughMediaService.swift
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

// MARK: - AKPlayerSeekingThroughMediaServiceProtocol

/// A protocol defining the service interface for managing sequential media
/// seeking operations.
@MainActor
public protocol AKPlayerSeekingThroughMediaServiceProtocol: AnyObject {
  /// The underlying `AVPlayer` executing media playback and underlying seek
  /// operations.
  var player: AVPlayer { get }

  /// An ordered collection of pending seek requests queued for execution.
  var pendingSeeks: [AKSeek] { get }

  /// The target position of the most recent seek request, if one is pending
  /// or active.
  var lastRequestedSeekTarget: AKSeekTarget? { get }

  /// Indicates whether a seek operation is currently active or queued.
  var isSeeking: Bool { get }

  /// Queues or executes a seek operation for the given request target.
  func seek(to seek: AKSeek)

  /// Cancels all pending and currently active seek operations, notifying
  /// callbacks of cancellation.
  func cancelAll()
}

// MARK: - AKPlayerSeekingThroughMediaService

/// A service class managing queued media seek operations for an `AVPlayer`.
@MainActor
public class AKPlayerSeekingThroughMediaService: AKPlayerSeekingThroughMediaServiceProtocol {
  // MARK: - Properties

  public let player: AVPlayer
  public private(set) var pendingSeeks = [AKSeek]()

  private var activeSeek: AKSeek?
  private var requestedSeekTarget: AKSeekTarget?

  public var lastRequestedSeekTarget: AKSeekTarget? {
    requestedSeekTarget
  }

  public var isSeeking: Bool {
    activeSeek != nil || !pendingSeeks.isEmpty
  }

  // MARK: - Initialization

  public init(with player: AVPlayer) {
    self.player = player
  }

  // MARK: - Public API

  public func seek(to seek: AKSeek) {
    guard player.currentItem != nil else {
      requestedSeekTarget = nil
      seek.completionHandler?(false)
      return
    }

    requestedSeekTarget = seek.target

    if !pendingSeeks.contains(seek) {
      pendingSeeks.append(seek)
    }

    if activeSeek == nil {
      performNextSeek()
    }
  }

  public func cancelAll() {
    activeSeek?.completionHandler?(false)
    activeSeek = nil

    while let seek = pendingSeeks.first {
      pendingSeeks.removeFirst()
      seek.completionHandler?(false)
    }

    requestedSeekTarget = nil
  }

  // MARK: - Private Pipeline

  private func performNextSeek() {
    guard let latestSeek = pendingSeeks.last else {
      activeSeek = nil
      requestedSeekTarget = nil
      return
    }

    // Cancel intermediate skipped seeks
    while let seekToCancel = pendingSeeks.first,
      seekToCancel != latestSeek
    {
      pendingSeeks.removeFirst()
      seekToCancel.completionHandler?(false)
    }

    activeSeek = latestSeek
    if let index = pendingSeeks.firstIndex(of: latestSeek) {
      pendingSeeks.remove(at: index)
    }

    enqueue(seek: latestSeek)
  }

  private func enqueue(seek: AKSeek) {
    let completion: @Sendable (Bool) -> Void = { [weak self] finished in
      Task { @MainActor in
        self?.handleSeekCompletion(for: seek, finished: finished)
      }
    }

    // Handle wall-clock date targets (HLS Live streams)
    if case let .date(targetDate) = seek.target {
      player.seek(to: targetDate, completionHandler: completion)
      return
    }

    guard let currentItem = player.currentItem else {
      completion(false)
      return
    }

    let timescale =
      currentItem.duration.timescale > 0
      ? currentItem
        .duration.timescale : 600

    // Resolve target to CMTime using AKSeekTarget resolve
    guard
      let targetCMTime = seek.target.resolve(
        currentTime: player.currentTime(),
        duration: currentItem.duration,
        preferredTimescale: timescale,
        clampToDuration: true
      )
    else {
      completion(false)
      return
    }

    player.seek(
      to: targetCMTime,
      toleranceBefore: seek.toleranceBefore,
      toleranceAfter: seek.toleranceAfter,
      completionHandler: completion
    )
  }

  private func handleSeekCompletion(
    for completedSeek: AKSeek,
    finished: Bool
  ) {
    guard activeSeek == completedSeek else { return }

    completedSeek.completionHandler?(finished)
    activeSeek = nil

    if !pendingSeeks.isEmpty {
      performNextSeek()
    } else {
      requestedSeekTarget = nil
    }
  }
}
