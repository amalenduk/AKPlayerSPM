//
//   AKAudioSessionSpatialPlaybackCapabilitiesObserver.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Combine

// MARK: - AKAudioSessionSpatialPlaybackCapabilitiesObserverDelegate

/// A delegate protocol for receiving updates when spatial playback capabilities
/// change.
@MainActor
public protocol AKAudioSessionSpatialPlaybackCapabilitiesObserverDelegate: AnyObject {
    /// Informs the delegate that spatial playback capabilities have changed.
    /// - Parameters:
    ///   - observer: The spatial playback capabilities observer reporting the
    /// event.
    ///   - isSpatialAudioEnabled: A Boolean value indicating whether spatial
    /// audio is enabled.
    func audioSessionSpatialPlaybackCapabilitiesObserver(
        _ observer: AKAudioSessionSpatialPlaybackCapabilitiesObserverProtocol,
        didChangeSpatialPlaybackCapabilitiesTo isSpatialAudioEnabled: Bool
    )
}

// MARK: - AKAudioSessionSpatialPlaybackCapabilitiesObserverProtocol

/// A protocol defining requirements for observing spatial playback capabilities
/// changes using Combine.
@MainActor
public protocol AKAudioSessionSpatialPlaybackCapabilitiesObserverProtocol: AnyObject {
    /// The target `AVAudioSession` instance being monitored.
    var audioSession: AVAudioSession { get }

    /// The delegate object notified of spatial playback capability changes.
    var delegate: AKAudioSessionSpatialPlaybackCapabilitiesObserverDelegate? {
        get set
    }

    /// Begins observing system-level spatial playback capabilities
    /// notifications.
    func startObserving()

    /// Stops monitoring spatial playback capabilities notifications and clears
    /// active subscriptions.
    func stopObserving()
}

// MARK: - AKAudioSessionSpatialPlaybackCapabilitiesObserver

/// A concrete implementation of
/// `AKAudioSessionSpatialPlaybackCapabilitiesObserverProtocol` utilizing
/// Combine to monitor
/// `AVAudioSession.spatialPlaybackCapabilitiesChangedNotification`.
@MainActor
public class AKAudioSessionSpatialPlaybackCapabilitiesObserver:
    AKAudioSessionSpatialPlaybackCapabilitiesObserverProtocol
{
    // MARK: - Properties

    /// The `AVAudioSession` instance managed by this observer.
    public let audioSession: AVAudioSession

    /// The delegate object notified of spatial playback capability callbacks.
    public weak var delegate: AKAudioSessionSpatialPlaybackCapabilitiesObserverDelegate?

    /// A Boolean flag tracking whether notification subscriptions are currently
    /// active.
    private var isObserving = false

    /// Container holding reactive Combine event subscriptions.
    private var subscriptions = Set<AnyCancellable>()

    // MARK: - Init & Deinit

    /// Initializes a new spatial playback capabilities observer with a target
    /// audio session.
    /// - Parameter audioSession: The `AVAudioSession` instance to observe.
    public init(audioSession: AVAudioSession) {
        self.audioSession = audioSession
    }

    deinit {}

    // MARK: - Observation Lifecycle

    /// Starts observing spatial playback capabilities notifications on the main
    /// queue.
    public func startObserving() {
        guard !isObserving else { return }

        NotificationCenter.default.publisher(
            for: AVAudioSession.spatialPlaybackCapabilitiesChangedNotification,
            object: audioSession
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            guard let self else { return }
            handleSpatialPlaybackCapabilitiesChangedNotification(notification)
        }
        .store(in: &subscriptions)

        isObserving = true
    }

    /// Stops observing spatial playback capabilities notifications and clears
    /// active subscriptions.
    public func stopObserving() {
        guard isObserving else { return }
        subscriptions.removeAll()
        isObserving = false
    }

    // MARK: - Handlers

    /// Processes incoming spatial playback capabilities changed notifications
    /// and notifies the delegate.
    /// - Parameter notification: The `Notification` object containing
    /// capability metadata.
    public func handleSpatialPlaybackCapabilitiesChangedNotification(
        _ notification: Notification
    ) {
        guard let userInfo = notification.userInfo,
              let isSpatialAudioEnabled =
              userInfo[AVAudioSessionSpatialAudioEnabledKey] as? NSNumber
        else {
            return
        }

        delegate?.audioSessionSpatialPlaybackCapabilitiesObserver(
            self,
            didChangeSpatialPlaybackCapabilitiesTo: isSpatialAudioEnabled
                .boolValue
        )
    }
}
