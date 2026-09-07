//
//  AKAudioSessionSilenceSecondaryAudioHintObserver.swift
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

// Ref: https://developer.apple.com/documentation/avfaudio/avaudiosession/1616622-silencesecondaryaudiohintnotific

import AVFoundation
import Combine

// MARK: - AKAudioSessionSilenceSecondaryAudioHintObserverDelegate

/// A delegate protocol for receiving callbacks when secondary audio hints start
/// or end.
@MainActor
public protocol AKAudioSessionSilenceSecondaryAudioHintObserverDelegate: AnyObject {
  /// Informs the delegate that a secondary audio hint to silence audio has
  /// begun.
  /// - Parameters:
  ///   - observer: The secondary audio hint observer reporting the event.
  ///   - audioSession: The active `AVAudioSession` instance receiving the
  /// hint.
  func audioSessionSilenceSecondaryAudioHintObserver(
    _ observer: AKAudioSessionSilenceSecondaryAudioHintObserverProtocol,
    silenceSecondaryAudioHintDidStartFor audioSession: AVAudioSession
  )

  /// Informs the delegate that a secondary audio hint to silence audio has
  /// ended.
  /// - Parameters:
  ///   - observer: The secondary audio hint observer reporting the event.
  ///   - audioSession: The active `AVAudioSession` instance recovering from
  /// the hint.
  func audioSessionSilenceSecondaryAudioHintObserver(
    _ observer: AKAudioSessionSilenceSecondaryAudioHintObserverProtocol,
    silenceSecondaryAudioHintDidEndFor audioSession: AVAudioSession
  )
}

// MARK: - AKAudioSessionSilenceSecondaryAudioHintObserverProtocol

/// A protocol defining requirements for observing secondary audio hints using
/// Combine.
@MainActor
public protocol AKAudioSessionSilenceSecondaryAudioHintObserverProtocol: AnyObject {
  /// The target `AVAudioSession` instance being monitored.
  var audioSession: AVAudioSession { get }

  /// The delegate object notified of secondary audio hint events.
  var delegate: AKAudioSessionSilenceSecondaryAudioHintObserverDelegate? {
    get set
  }

  /// Begins observing system-level secondary audio hint notifications.
  func startObserving()

  /// Stops monitoring secondary audio hint notifications and clears active
  /// subscriptions.
  func stopObserving()
}

// MARK: - AKAudioSessionSilenceSecondaryAudioHintObserver

/// A concrete implementation of
/// `AKAudioSessionSilenceSecondaryAudioHintObserverProtocol` utilizing Combine
/// to monitor `AVAudioSession.silenceSecondaryAudioHintNotification`.
@MainActor
public class AKAudioSessionSilenceSecondaryAudioHintObserver:
  AKAudioSessionSilenceSecondaryAudioHintObserverProtocol
{
  // MARK: - Properties

  /// The `AVAudioSession` instance managed by this observer.
  public let audioSession: AVAudioSession

  /// The delegate object notified of secondary audio hint callbacks.
  public weak var delegate: AKAudioSessionSilenceSecondaryAudioHintObserverDelegate?

  /// A Boolean flag tracking whether notification subscriptions are currently
  /// active.
  private var isObserving = false

  /// Container holding reactive Combine event subscriptions.
  private var subscriptions = Set<AnyCancellable>()

  // MARK: - Init & Deinit

  /// Initializes a new secondary audio hint observer with a target audio
  /// session.
  /// - Parameter audioSession: The `AVAudioSession` instance to observe.
  public init(audioSession: AVAudioSession) {
    self.audioSession = audioSession
  }

  deinit {}

  // MARK: - Observation Lifecycle

  /// Starts observing secondary audio hint notifications on the main queue.
  public func startObserving() {
    guard !isObserving else { return }

    NotificationCenter.default.publisher(
      for: AVAudioSession.silenceSecondaryAudioHintNotification,
      object: audioSession
    )
    .receive(on: DispatchQueue.main)
    .sink { [weak self] notification in
      guard let self else { return }
      handleSilenceSecondaryAudioHintNotification(notification)
    }
    .store(in: &subscriptions)

    isObserving = true
  }

  /// Stops observing secondary audio hint notifications and clears active
  /// subscriptions.
  public func stopObserving() {
    guard isObserving else { return }
    subscriptions.removeAll()
    isObserving = false
  }

  // MARK: - Handlers

  /// Processes incoming secondary audio hint notifications and notifies the
  /// delegate.
  /// - Parameter notification: The `Notification` object containing hint
  /// metadata.
  public func handleSilenceSecondaryAudioHintNotification(
    _ notification: Notification
  ) {
    guard let userInfo = notification.userInfo,
      let typeValue =
        userInfo[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt,
      let type =
        AVAudioSession
        .SilenceSecondaryAudioHintType(rawValue: typeValue)
    else {
      return
    }

    switch type {
    case .begin:
      delegate?.audioSessionSilenceSecondaryAudioHintObserver(
        self,
        silenceSecondaryAudioHintDidStartFor: audioSession
      )
    case .end:
      delegate?.audioSessionSilenceSecondaryAudioHintObserver(
        self,
        silenceSecondaryAudioHintDidEndFor: audioSession
      )
    @unknown default:
      break
    }
  }
}
