//
//  AKAudioSessionRouteChangesObserver.swift
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

// Ref: https://developer.apple.com/documentation/avfaudio/avaudiosession/responding_to_audio_session_route_changes

import AVFoundation
import Combine

// MARK: - AKAudioSessionRouteChangesObserverDelegate

/// A delegate protocol for receiving callbacks whenever an audio session route
/// change occurs.
@MainActor
public protocol AKAudioSessionRouteChangesObserverDelegate: AnyObject {
  /// Informs the delegate that the active audio route has changed.
  /// - Parameters:
  ///   - observer: The route changes observer reporting the event.
  ///   - currentRoute: The new `AVAudioSessionRouteDescription` after the
  /// route change.
  ///   - previousRoute: The previous `AVAudioSessionRouteDescription` before
  /// the change, if available.
  ///   - reason: The `AVAudioSession.RouteChangeReason` describing why the
  /// route changed.
  func audioSessionRouteChangesObserver(
    _ observer: AKAudioSessionRouteChangesObserverProtocol,
    didChangeRouteTo currentRoute: AVAudioSessionRouteDescription,
    from previousRoute: AVAudioSessionRouteDescription?,
    with reason: AVAudioSession.RouteChangeReason
  )
}

// MARK: - AKAudioSessionRouteChangesObserverProtocol

/// A protocol defining requirements for observing audio route changes and
/// inspecting connected audio output devices.
@MainActor
public protocol AKAudioSessionRouteChangesObserverProtocol: AnyObject {
  /// The target `AVAudioSession` instance being monitored.
  var audioSession: AVAudioSession { get }

  /// The delegate object notified of audio route changes.
  var delegate: AKAudioSessionRouteChangesObserverDelegate? { get set }

  /// Checks if an external audio device (other than the built-in speaker) is
  /// currently connected.
  /// - Returns: A Boolean value indicating whether an external device is
  /// active.
  func isExternalDeviceConnected() -> Bool

  /// Checks if headphones are currently connected as an audio output route.
  /// - Returns: A Boolean value indicating whether headphones are connected.
  func hasHeadphonesConnected() -> Bool

  /// Begins observing system-level audio route change notifications.
  func startObserving()

  /// Stops monitoring audio route change notifications and clears active
  /// subscriptions.
  func stopObserving()
}

// MARK: - AKAudioSessionRouteChangesObserver

/// A concrete implementation of `AKAudioSessionRouteChangesObserverProtocol`
/// utilizing Combine to monitor `AVAudioSession.routeChangeNotification`.
@MainActor
public class AKAudioSessionRouteChangesObserver: AKAudioSessionRouteChangesObserverProtocol {
  // MARK: - Properties

  /// The `AVAudioSession` instance managed by this observer.
  public let audioSession: AVAudioSession

  /// The delegate object notified of audio route change callbacks.
  public weak var delegate: AKAudioSessionRouteChangesObserverDelegate?

  /// A Boolean flag tracking whether notification subscriptions are currently
  /// active.
  private var isObserving = false

  /// Container holding reactive Combine event subscriptions.
  private var subscriptions = Set<AnyCancellable>()

  // MARK: - Init & Deinit

  /// Initializes a new route changes observer with a target audio session.
  /// - Parameter audioSession: The `AVAudioSession` instance to observe.
  public init(audioSession: AVAudioSession) {
    self.audioSession = audioSession
  }

  deinit {}

  // MARK: - Observation Lifecycle

  /// Starts observing audio route change notifications on the main queue.
  public func startObserving() {
    guard !isObserving else { return }

    NotificationCenter.default.publisher(
      for: AVAudioSession.routeChangeNotification, object: audioSession
    )
    .receive(on: DispatchQueue.main)
    .sink { [weak self] notification in
      guard let self else { return }
      handleRouteChange(notification)
    }
    .store(in: &subscriptions)

    isObserving = true
  }

  /// Stops observing audio route change notifications and clears active
  /// subscriptions.
  public func stopObserving() {
    guard isObserving else { return }
    subscriptions.removeAll()
    isObserving = false
  }

  // MARK: - Handlers

  /// Processes incoming route change notifications, extracting metadata and
  /// notifying the delegate.
  /// - Parameter notification: The `Notification` object posted by the
  /// system.
  public func handleRouteChange(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
      let reasonValue =
        userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
      let reason =
        AVAudioSession
        .RouteChangeReason(rawValue: reasonValue)
    else {
      return
    }
    let previousRoute =
      userInfo[
        AVAudioSessionRouteChangePreviousRouteKey
      ] as? AVAudioSessionRouteDescription

    delegate?.audioSessionRouteChangesObserver(
      self,
      didChangeRouteTo: audioSession.currentRoute,
      from: previousRoute,
      with: reason
    )
  }

  // MARK: - Helper Functions

  /// Determines whether an external output device is currently active
  /// (excluding the built-in speaker).
  /// - Returns: `true` if any output port other than the built-in speaker is
  /// in use; otherwise, `false`.
  public func isExternalDeviceConnected() -> Bool {
    !audioSession.currentRoute.outputs
      .contains(where: { $0.portType == .builtInSpeaker })
  }

  /// Determines whether headphones are currently connected as an audio output
  /// route.
  /// - Returns: `true` if a headphone port is present in the current outputs;
  /// otherwise, `false`.
  public func hasHeadphonesConnected() -> Bool {
    audioSession.currentRoute.outputs
      .contains(where: { $0.portType == .headphones })
  }
}
