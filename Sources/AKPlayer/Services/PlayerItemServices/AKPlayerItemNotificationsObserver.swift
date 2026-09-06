//
//  AKPlayerItemNotificationsObserver.swift
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

import AVFoundation
import Foundation

// MARK: - AKPlayerItemNotificationsObserverProtocol

/// Protocol defining notification streams for AVPlayerItem playback events.
///
/// The protocol is MainActor-isolated because the observer owns
/// MainActor-isolated state and interacts with AVPlayerItem.
///
/// `Sendable` is intentionally NOT used here.
///
/// The observer is not designed to be transferred between actors.
/// Instead, callers interact with it through the MainActor.
@MainActor
public protocol AKPlayerItemNotificationsObserverProtocol {
    
    var didPlayToEndTimeStream: AsyncStream<CMTime> { get }
    
    var failedToPlayToEndTimeStream: AsyncStream<AKPlayerError> { get }
    
    var playbackStalledStream: AsyncStream<Void> { get }
    
    var timeJumpedStream: AsyncStream<Void> { get }
    
    var mediaSelectionDidChangeStream: AsyncStream<Void> { get }
    
    var recommendedTimeOffsetFromLiveDidChangeStream: AsyncStream<CMTime> {
        get
    }
    
    func startObserving()
    
    func stopObserving()
}

// MARK: - AKPlayerItemNotificationsObserver

/// Observes AVPlayerItem system notifications and exposes them
/// through Swift AsyncStreams.
///
/// The entire observer is isolated to MainActor because:
///
/// 1. AVPlayerItem interaction is performed on MainActor.
/// 2. Observer state is MainActor-isolated.
/// 3. AsyncStream continuations are owned by this object.
/// 4. Notification events are delivered onto MainActor before
///    accessing the observer's state.
@MainActor
public final class AKPlayerItemNotificationsObserver:
    AKPlayerItemNotificationsObserverProtocol {
    
    // MARK: - Properties
    
    /// The AVPlayerItem being observed.
    private let playerItem: AVPlayerItem
    
    /// Indicates whether notification observers are currently registered.
    public private(set) var isObserving = false
    
    /// NotificationCenter observer tokens.
    ///
    /// `deinit` is nonisolated, so this property must be explicitly
    /// marked `nonisolated(unsafe)` to allow cleanup from deinit.
    ///
    /// The property is only mutated while the object is alive and
    /// operating on MainActor.
    private nonisolated(unsafe) var observerTokens: [NSObjectProtocol] = []
    
    // MARK: - AsyncStream Continuations
    
    private var didPlayToEndContinuation:
        AsyncStream<CMTime>.Continuation?
    
    private var failedToPlayToEndContinuation:
        AsyncStream<AKPlayerError>.Continuation?
    
    private var playbackStalledContinuation:
        AsyncStream<Void>.Continuation?
    
    private var timeJumpedContinuation:
        AsyncStream<Void>.Continuation?
    
    private var mediaSelectionDidChangeContinuation:
        AsyncStream<Void>.Continuation?
    
    private var recommendedTimeOffsetContinuation:
        AsyncStream<CMTime>.Continuation?
    
    // MARK: - Async Streams
    
    /// Emits the current playback time when the item reaches its end.
    public lazy var didPlayToEndTimeStream: AsyncStream<CMTime> = {
        AsyncStream { continuation in
            self.didPlayToEndContinuation = continuation
        }
    }()
    
    /// Emits an AKPlayerError when playback fails to reach the end.
    public lazy var failedToPlayToEndTimeStream: AsyncStream<AKPlayerError> = {
        AsyncStream { continuation in
            self.failedToPlayToEndContinuation = continuation
        }
    }()
    
    /// Emits when AVPlayerItem playback stalls.
    public lazy var playbackStalledStream: AsyncStream<Void> = {
        AsyncStream { continuation in
            self.playbackStalledContinuation = continuation
        }
    }()
    
    /// Emits when AVPlayerItem performs a time jump.
    public lazy var timeJumpedStream: AsyncStream<Void> = {
        AsyncStream { continuation in
            self.timeJumpedContinuation = continuation
        }
    }()
    
    /// Emits when the media selection changes.
    public lazy var mediaSelectionDidChangeStream: AsyncStream<Void> = {
        AsyncStream { continuation in
            self.mediaSelectionDidChangeContinuation = continuation
        }
    }()
    
    /// Emits when the recommended live offset changes.
    public lazy var recommendedTimeOffsetFromLiveDidChangeStream:
        AsyncStream<CMTime> = {
            
            AsyncStream { continuation in
                self.recommendedTimeOffsetContinuation = continuation
            }
        }()
    
    // MARK: - Init
    
    /// Initializes an observer for an AVPlayerItem.
    ///
    /// - Parameter playerItem: The AVPlayerItem to observe.
    public init(playerItem: AVPlayerItem) {
        self.playerItem = playerItem
    }
    
    // MARK: - Deinit
    
    deinit {
        // deinit is nonisolated.
        //
        // observerTokens is therefore marked `nonisolated(unsafe)`
        // so that NotificationCenter observers can be removed here.
        
        observerTokens.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        
        observerTokens.removeAll()
    }
    
    // MARK: - Observation Controls
    
    /// Starts observing AVPlayerItem notifications.
    public func startObserving() {
        guard !isObserving else {
            return
        }
        
        // Remove any previous observers before registering new ones.
        stopObservingObservers()
        
        isObserving = true
        
        // ---------------------------------------------------------
        // 1. Did Play To End Time
        // ---------------------------------------------------------
        
        observeNotification(
            .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        ) { [weak self] in
            
            guard let self else {
                return
            }
            
            self.didPlayToEndContinuation?.yield(
                self.playerItem.currentTime()
            )
        }
        
        // ---------------------------------------------------------
        // 2. Failed To Play To End Time
        // ---------------------------------------------------------
        
        observeFailedToPlayToEndNotification(
            object: playerItem
        )
        
        // ---------------------------------------------------------
        // 3. Playback Stalled
        // ---------------------------------------------------------
        
        observeNotification(
            .AVPlayerItemPlaybackStalled,
            object: playerItem
        ) { [weak self] in
            
            self?.playbackStalledContinuation?.yield()
        }
        
        // ---------------------------------------------------------
        // 4. Time Jumped
        // ---------------------------------------------------------
        
        observeNotification(
            AVPlayerItem.timeJumpedNotification,
            object: playerItem
        ) { [weak self] in
            
            self?.timeJumpedContinuation?.yield()
        }
        
        // ---------------------------------------------------------
        // 5. Media Selection Changed
        // ---------------------------------------------------------
        
        observeNotification(
            AVPlayerItem.mediaSelectionDidChangeNotification,
            object: playerItem
        ) { [weak self] in
            
            self?.mediaSelectionDidChangeContinuation?.yield()
        }
        
        // ---------------------------------------------------------
        // 6. Recommended Time Offset From Live Changed
        // ---------------------------------------------------------
        
        observeNotification(
            AVPlayerItem.recommendedTimeOffsetFromLiveDidChangeNotification,
            object: playerItem
        ) { [weak self] in
            
            guard let self else {
                return
            }
            
            self.recommendedTimeOffsetContinuation?.yield(
                self.playerItem.recommendedTimeOffsetFromLive
            )
        }
    }
    
    /// Stops observing all AVPlayerItem notifications.
    public func stopObserving() {
        guard isObserving else {
            return
        }
        
        stopObservingObservers()
        
        isObserving = false
    }
    
    // MARK: - Private Notification Helpers
    
    /// Registers a notification that does not require the Notification
    /// object itself.
    ///
    /// NotificationCenter's callback is a Sendable closure.
    ///
    /// IMPORTANT:
    ///
    /// `queue: .main` tells Foundation to execute the callback on the
    /// main operation queue, but Swift's concurrency checker does not
    /// automatically treat that callback as `@MainActor`.
    ///
    /// Therefore we explicitly create a MainActor Task before accessing
    /// MainActor-isolated state.
    ///
    /// We intentionally do NOT pass Notification into the handler.
    /// Foundation.Notification is not Sendable.
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
            
            // Do not pass Notification across the concurrency boundary.
            //
            // The notification is ignored because these events don't
            // require any information from it.
            //
            // The Task explicitly transfers execution to MainActor.
            Task { @MainActor in
                handler()
            }
        }
        
        observerTokens.append(token)
    }
    
    /// Registers the AVPlayerItem failure notification.
    ///
    /// This notification is different because we need the NSError
    /// contained in `Notification.userInfo`.
    ///
    /// The Notification object itself must NOT cross the concurrency
    /// boundary because Notification is not Sendable.
    ///
    /// Therefore:
    ///
    /// Notification
    ///    ↓
    /// Extract NSError
    ///    ↓
    /// Discard Notification
    ///    ↓
    /// Transfer extracted value to MainActor
    private func observeFailedToPlayToEndNotification(
        object: AVPlayerItem
    ) {
        let token = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: object,
            queue: .main
        ) { [weak self] notification in
            
            // Extract everything we need while we still have the
            // Notification object.
            let error = notification.userInfo?[
                AVPlayerItemFailedToPlayToEndTimeErrorKey
            ] as? NSError
            
            // Notification itself is NOT captured here.
            //
            // Only the extracted error is captured by the MainActor task.
            Task { @MainActor [weak self, error] in
                
                guard
                    let self,
                    let error
                else {
                    return
                }
                
                self.failedToPlayToEndContinuation?.yield(
                    .playerItemFailedToPlay(
                        reason: .failedToPlayToEndTime(
                            error: error
                        )
                    )
                )
            }
        }
        
        observerTokens.append(token)
    }
    
    // MARK: - Observer Cleanup
    
    /// Removes all NotificationCenter observers.
    ///
    /// This method is MainActor-isolated because observerTokens is
    /// normally managed from MainActor.
    private func stopObservingObservers() {
        observerTokens.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        
        observerTokens.removeAll()
    }
}
