//
//  AKAudioSessionMediaServicesLostObserver.swift
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

// MARK: - AKAudioSessionMediaServicesLostObserverDelegate

/// A delegate protocol for receiving callbacks when the system audio media
/// services are lost.
public protocol AKAudioSessionMediaServicesLostObserverDelegate: AnyObject {
  /// Informs the delegate that the audio media services were lost for the
  /// specified audio session.
  /// - Parameters:
  ///   - observer: The media services lost observer reporting the event.
  ///   - audioSession: The active `AVAudioSession` instance that experienced
  /// the media services loss.
  func audioSessionMediaServicesLostObserver(
    _ observer: AKAudioSessionMediaServicesLostObserverProtocol,
    for audioSession: AVAudioSession
  )
}

// MARK: - AKAudioSessionMediaServicesLostObserverProtocol

/// A protocol defining requirements for observing audio media services loss
/// events.
public protocol AKAudioSessionMediaServicesLostObserverProtocol: AnyObject {
  /// The target `AVAudioSession` instance being monitored.
  var audioSession: AVAudioSession { get }

  /// The delegate object notified when media services are lost.
  var delegate: AKAudioSessionMediaServicesLostObserverDelegate? { get set }

  /// Begins observing system-level media services lost notifications.
  func startObserving()

  /// Stops monitoring media services lost notifications and removes active
  /// observers.
  func stopObserving()
}

// MARK: - AKAudioSessionMediaServicesLostObserver

/// A concrete implementation of
/// `AKAudioSessionMediaServicesLostObserverProtocol` that monitors
/// `AVAudioSession.mediaServicesWereLostNotification`.
public class AKAudioSessionMediaServicesLostObserver:
  AKAudioSessionMediaServicesLostObserverProtocol
{
  // MARK: - Properties

  /// The `AVAudioSession` instance managed by this observer.
  public let audioSession: AVAudioSession

  /// The delegate object notified of media services loss callbacks.
  public weak var delegate: AKAudioSessionMediaServicesLostObserverDelegate?

  /// A Boolean flag tracking whether notification observation is currently
  /// active.
  private var isObserving = false

  // MARK: - Init & Deinit

  /// Initializes a new observer with a target audio session.
  /// - Parameter audioSession: The `AVAudioSession` instance to observe.
  public init(audioSession: AVAudioSession) {
    self.audioSession = audioSession
  }

  deinit {
    stopObserving()
  }

  // MARK: - Observation Lifecycle

  /// Starts observing system audio media services lost notifications.
  public func startObserving() {
    guard !isObserving else { return }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleMediaServicesWereLostNotification(_:)),
      name: AVAudioSession.mediaServicesWereLostNotification,
      object: audioSession
    )

    isObserving = true
  }

  /// Stops observing media services lost notifications and removes the
  /// notification observer.
  public func stopObserving() {
    guard isObserving else { return }

    NotificationCenter.default.removeObserver(
      self,
      name: AVAudioSession.mediaServicesWereLostNotification,
      object: audioSession
    )

    isObserving = false
  }

  // MARK: - Handlers

  /// Processes incoming media services were lost notifications and notifies
  /// the delegate.
  /// - Parameter notification: The `Notification` object posted by the
  /// system.
  @objc public func handleMediaServicesWereLostNotification(
    _ notification: Notification
  ) {
    guard notification.object as? AVAudioSession != nil,
      let delegate
    else { return }
    delegate.audioSessionMediaServicesLostObserver(
      self,
      for: audioSession
    )
  }
}
