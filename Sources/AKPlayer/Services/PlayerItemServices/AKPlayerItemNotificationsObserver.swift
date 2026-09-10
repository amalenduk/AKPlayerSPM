//
//   AKPlayerItemNotificationsObserver.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Foundation

// MARK: - Event Model

/// Events emitted by AVPlayerItem during playback.
public enum AKPlayerItemNotificationEvent: Sendable {
    case didPlayToEndTime(CMTime)
    case failedToPlayToEndTime(AKPlayerError)
    case playbackStalled
    case timeJumped
    case mediaSelectionDidChange
    case recommendedTimeOffsetFromLiveDidChange(CMTime)
}

// MARK: - Protocol

@MainActor
public protocol AKPlayerItemNotificationsObserverProtocol: AnyObject {
    /// A multi-subscriber stream emitting AVPlayerItem lifecycle events.
    var events: AsyncStream<AKPlayerItemNotificationEvent> { get }
    
    /// Indicates whether notification observers are currently active.
    var isObserving: Bool { get }
    
    /// Starts observing AVPlayerItem system notifications.
    func startObserving()
    
    /// Stops observing AVPlayerItem system notifications and removes tokens.
    func stopObserving()
}

// MARK: - Implementation

/// Observes AVPlayerItem system notifications and broadcasts them
/// through a thread-safe `AKEventBroadcaster`.
@MainActor
public final class AKPlayerItemNotificationsObserver: AKPlayerItemNotificationsObserverProtocol {
    
    // MARK: - Properties
    
    /// The AVPlayerItem being observed.
    private let playerItem: AVPlayerItem
    
    /// Indicates whether notification observers are currently registered.
    public private(set) var isObserving = false
    
    /// NotificationCenter observer tokens.
    /// Marked `nonisolated(unsafe)` so deinit can safely remove them off-actor.
    private nonisolated(unsafe) var observerTokens: [NSObjectProtocol] = []
    
    /// The event broadcaster managing multi-subscriber AsyncStreams.
    private let broadcaster = AKEventBroadcaster<AKPlayerItemNotificationEvent>()
    
    /// Public multi-subscriber stream for item events.
    public var events: AsyncStream<AKPlayerItemNotificationEvent> {
        broadcaster.makeStream()
    }
    
    // MARK: - Init & Deinit
    
    /// Initializes an observer for a specific AVPlayerItem.
    public init(playerItem: AVPlayerItem) {
        self.playerItem = playerItem
    }
    
    deinit {
        // Clean up NotificationCenter observer tokens
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
        }
        observerTokens.removeAll()
        broadcaster.finish()
    }
    
    // MARK: - Observation Controls
    
    public func startObserving() {
        guard !isObserving else { return }
        stopObservingObservers()
        isObserving = true
        
        // 1. Did Play To End Time
        observeNotification(.AVPlayerItemDidPlayToEndTime, object: playerItem) { [weak self] in
            guard let self else { return }
            broadcaster.send(.didPlayToEndTime(playerItem.currentTime()))
        }
        
        // 2. Failed To Play To End Time
        observeFailedToPlayToEndNotification(object: playerItem)
        
        // 3. Playback Stalled
        observeNotification(.AVPlayerItemPlaybackStalled, object: playerItem) { [weak self] in
            guard let self else { return }
            broadcaster.send(.playbackStalled)
        }
        
        // 4. Time Jumped
        observeNotification(AVPlayerItem.timeJumpedNotification, object: playerItem) { [weak self] in
            guard let self else { return }
            broadcaster.send(.timeJumped)
        }
        
        // 5. Media Selection Changed
        observeNotification(AVPlayerItem.mediaSelectionDidChangeNotification, object: playerItem) { [weak self] in
            guard let self else { return }
            broadcaster.send(.mediaSelectionDidChange)
        }
        
        // 6. Recommended Time Offset From Live Changed
        observeNotification(AVPlayerItem.recommendedTimeOffsetFromLiveDidChangeNotification, object: playerItem) { [weak self] in
            guard let self else { return }
            broadcaster.send(.recommendedTimeOffsetFromLiveDidChange(playerItem.recommendedTimeOffsetFromLive))
        }
    }
    
    public func stopObserving() {
        guard isObserving else { return }
        stopObservingObservers()
        broadcaster.finish()
        isObserving = false
    }
    
    // MARK: - Private Notification Helpers
    
    private func observeNotification(
        _ name: Notification.Name,
        object: AnyObject,
        handler: @escaping @MainActor @Sendable () -> Void
    ) {
        let token = NotificationCenter.default.addObserver(
            forName: name,
            object: object,
            queue: .main
        ) { _ in
            Task { @MainActor in
                handler()
            }
        }
        observerTokens.append(token)
    }
    
    private func observeFailedToPlayToEndNotification(object: AVPlayerItem) {
        let token = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: object,
            queue: .main
        ) { [weak self] notification in
            // Extract error safely before crossing concurrency boundary
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError
            
            Task { @MainActor [weak self, error] in
                guard let self, let error else { return }
                self.broadcaster.send(
                    .failedToPlayToEndTime(
                        .playerItemFailedToPlay(reason: .failedToPlayToEndTime(error: error))
                    )
                )
            }
        }
        observerTokens.append(token)
    }
    
    private func stopObservingObservers() {
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
        }
        observerTokens.removeAll()
    }
}
