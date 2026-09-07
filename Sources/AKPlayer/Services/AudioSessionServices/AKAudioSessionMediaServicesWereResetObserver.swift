//
//   AKAudioSessionMediaServicesWereResetObserver.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

// Ref: https://developer.apple.com/documentation/avfaudio/avaudiosession/1616540-mediaserviceswereresetnotificati

import AVFoundation
import Combine

// MARK: - AKAudioSessionMediaServicesResetObserverDelegate

/// A delegate protocol for receiving callbacks when system media services have
/// been reset.
@MainActor
public protocol AKAudioSessionMediaServicesResetObserverDelegate: AnyObject {
    /// Informs the delegate that audio media services were reset for the
    /// specified audio session.
    /// - Parameters:
    ///   - observer: The media services reset observer reporting the event.
    ///   - audioSession: The active `AVAudioSession` instance affected by the
    /// media services reset.
    func audioSessionMediaServicesResetObserver(
        _ observer: AKAudioSessionMediaServicesWereResetObserverProtocol,
        mediaServicesWereResetFor audioSession: AVAudioSession
    )
}

// MARK: - AKAudioSessionMediaServicesWereResetObserverProtocol

/// A protocol defining requirements for observing audio media services reset
/// events using Combine.
@MainActor
public protocol AKAudioSessionMediaServicesWereResetObserverProtocol: AnyObject {
    /// The target `AVAudioSession` instance being monitored.
    var audioSession: AVAudioSession { get }

    /// The delegate object notified when media services are reset.
    var delegate: AKAudioSessionMediaServicesResetObserverDelegate? { get set }

    /// Begins observing system-level media services reset notifications.
    func startObserving()

    /// Stops monitoring media services reset notifications and clears active
    /// Combine subscriptions.
    func stopObserving()
}

// MARK: - AKAudioSessionMediaServicesWereResetObserver

/// A concrete implementation of
/// `AKAudioSessionMediaServicesWereResetObserverProtocol` utilizing Combine to
/// monitor `AVAudioSession.mediaServicesWereResetNotification`.
@MainActor
public class AKAudioSessionMediaServicesWereResetObserver:
    AKAudioSessionMediaServicesWereResetObserverProtocol
{
    // MARK: - Properties

    /// The `AVAudioSession` instance managed by this observer.
    public let audioSession: AVAudioSession

    /// The delegate object notified of media services reset callbacks.
    public weak var delegate: AKAudioSessionMediaServicesResetObserverDelegate?

    /// A Boolean flag tracking whether notification subscriptions are currently
    /// active.
    private var isObserving = false

    /// Container holding reactive Combine event subscriptions.
    private var subscriptions = Set<AnyCancellable>()

    // MARK: - Init & Deinit

    /// Initializes a new reset observer with a target audio session.
    /// - Parameter audioSession: The `AVAudioSession` instance to observe.
    public init(audioSession: AVAudioSession) {
        self.audioSession = audioSession
    }

    deinit {}

    // MARK: - Observation Lifecycle

    /// Starts observing audio media services reset notifications on the main
    /// queue.
    public func startObserving() {
        guard !isObserving else { return }

        NotificationCenter.default.publisher(
            for: AVAudioSession.mediaServicesWereResetNotification, object: nil
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            guard let self else { return }
            handleMediaServicesWereReset(notification)
        }
        .store(in: &subscriptions)

        isObserving = true
    }

    /// Stops observing media services reset notifications and clears active
    /// subscriptions.
    public func stopObserving() {
        guard isObserving else { return }
        subscriptions.removeAll()
        isObserving = false
    }

    // MARK: - Handlers

    /// Processes incoming media services were reset notifications and notifies
    /// the delegate.
    /// - Parameter notification: The `Notification` object posted by the
    /// system.
    public func handleMediaServicesWereReset(_: Notification) {
        delegate?.audioSessionMediaServicesResetObserver(
            self,
            mediaServicesWereResetFor: audioSession
        )
    }
}
