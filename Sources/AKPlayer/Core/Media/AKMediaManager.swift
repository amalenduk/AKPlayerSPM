//
//  AKMediaManager.swift
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
import Combine
import Foundation

// MARK: - AKMediaManager

/// Concrete implementation responsible for managing media item asset creation, status observation, and preflight capability checks.
@MainActor
public class AKMediaManager: NSObject, AKMediaManagerProtocol {
    
    // MARK: - Properties
    
    /// The weak reference to the backing playable media item.
    public private(set) weak var media: (any AKPlayable)?
    
    /// The loaded URL asset generated from the media item.
    public var asset: AVURLAsset? {
        return playerItemInitService.asset
    }
    
    /// The instantiated player item constructed from the asset.
    public var playerItem: AVPlayerItem? {
        return playerItemInitService.playerItem
    }
    
    /// The current player error, if media loading or playback failed.
    public var error: AKPlayerError?
    
    /// The current state of the playable media item.
    public private(set) var state: AKPlayableState {
        get { stateSubject.value }
        set {
            stateSubject.send(newValue)
            emit(.stateDidChange(state))
        }
    }
    
    /// Publisher emitting state updates starting with the current state upon subscription.
    public var statePublisher: AnyPublisher<AKPlayableState, Never> {
        stateSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Asynchronous stream of media events for Swift Concurrency.
    public var events: AsyncStream<AKMediaEvent> {
        eventBroadcaster.makeStream()
    }
    
    public weak var delegate: AKMediaDelegate?
    
    private let eventBroadcaster = AKEventBroadcaster<AKMediaEvent>()
    
    private let stateSubject = CurrentValueSubject<AKPlayableState, Never>(.idle)
    
    private var playerItemInitService: any AKPlayerItemInitServiceProtocol
    
    // Private backing storage initialized post-super.init
    private var _seekingThroughMediaService: (any AKSeekingThroughMediaServiceProtocol)!
    private var _trackSelectionService: (any AKTrackSelectionServiceProtocol)!
    
    /// Service responsible for managing seek feasibility checks and execution.
    public var seekingThroughMediaService: any AKSeekingThroughMediaServiceProtocol {
        _seekingThroughMediaService
    }
    
    /// Service responsible for subtitle and audio track selection management.
    public var trackSelectionService: any AKTrackSelectionServiceProtocol {
        _trackSelectionService
    }
    
    /// Notification observer for player item playback lifecycle events.
    ///
    /// Available once `createPlayerItemFromAsset()` initializes the `playerItem`.
    public private(set) var playerItemNotificationsObserver: AKPlayerItemNotificationsObserver?
    
    // Distinct subscription sets so lifecycle calls don't clear each other
    private nonisolated(unsafe) var readinessSubscriptions = Set<AnyCancellable>()
    private nonisolated(unsafe) var assetKeySubscriptions = Set<AnyCancellable>()
    
    // MARK: - Init & Deinit
    
    /// Initializes a new media manager instance for the specified media item.
    /// - Parameter media: The target playable media item.
    public init(media: any AKPlayable) {
        self.media = media
        self.playerItemInitService = AKPlayerItemInitService(with: media)
        
        super.init()
        
        // Direct initialization of child services
        self._seekingThroughMediaService = AKSeekingThroughMediaService(mediaManager: self)
        self._trackSelectionService = AKTrackSelectionService(mediaManager: self)
        
        self.playerItemNotificationsObserver = nil
    }
    
    deinit {
        stopPlayerItemReadinessObserver()
        stopPlayerItemAssetKeysObserver()
    }
    
    // MARK: - Asset Lifecycle Operations
    
    /// Instantiates the underlying `AVURLAsset` for the assigned media.
    public func createAsset() {
        assert(state.isIdle || state.isFailed,
               "This function can only be called if the media is idle or has encountered an error.")
        self.error = nil
        playerItemInitService.createAsset()
        state = .assetLoaded
    }
    
    /// Asynchronously validates key asset properties (e.g., playability and DRM restrictions).
    public func validateAssetPlayability() async throws {
        assert(state.isAssetLoaded,
               "This function requires the asset to be loaded first.")
        try await playerItemInitService.validateAssetPlayability()
    }
    
    /// Constructs an `AVPlayerItem` from the initialized `AVURLAsset` and instantiates the notification observer.
    public func createPlayerItemFromAsset() {
        assert(state.isAssetLoaded,
               "This function requires the asset to be loaded first.")
        self.error = nil
        playerItemInitService.createPlayerItemFromAsset()
        
        // Stop any existing notifications observer instance
        playerItemNotificationsObserver?.stopObserving()
        playerItemNotificationsObserver = nil
        
        // Instantiate notification observer targeting the newly created player item
        if let newItem = playerItem {
            playerItemNotificationsObserver = AKPlayerItemNotificationsObserver(playerItem: newItem)
        }
        
        Task {
            await trackSelectionService.resetSession()
        }
        state = .playerItemLoaded
    }
    
    /// Aborts active asset property loading and cancels pending asynchronous tasks.
    public func abortAssetInitialization() {
        playerItemInitService.abortAssetInitialization()
    }
    
    // MARK: - Observation Controls
    
    /// Starts observing the player item's `status` key path for readiness or failure.
    public func startPlayerItemReadinessObserver() {
        assert(state.isPlayerItemLoaded || state.isReadyToPlay,
               "Cannot start readiness observer before player item is loaded.")
        
        guard let playerItem else { return }
        stopPlayerItemReadinessObserver()
        
        playerItem.publisher(for: \.status, options: [.initial, .new])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                switch status {
                case .readyToPlay:
                    self.state = .readyToPlay
                case .failed:
                    let underlyingError = playerItem.error ?? NSError(domain: "AKPlayer", code: -1, userInfo: nil)
                    self.error = .playerItemLoadingFailed(reason: .statusLoadingFailed(error: underlyingError))
                    self.state = .failed
                default: break
                }
            }
            .store(in: &readinessSubscriptions)
    }
    
    /// Stops active observation of the player item's `status` key path.
    public nonisolated func stopPlayerItemReadinessObserver() {
        readinessSubscriptions.removeAll()
    }
    
    public func startPlayerItemAssetKeysObserver() {
        assert(state.isPlayerItemLoaded || state.isReadyToPlay,
               "Cannot start readiness observer before player item is loaded.")
        
        startObservingPlayerItemProperties()
    }
    
    /// Stops active observation of asset keys.
    public nonisolated func stopPlayerItemAssetKeysObserver() {
        assetKeySubscriptions.removeAll()
    }
    
    // MARK: - Preflight Capability Checks
    
    /// Evaluates if the player item can step forward or backward by a given frame count.
    /// - Parameter count: The frame offset count.
    /// - Returns: `true` if stepping by the specified count is supported.
    public func canStep(by count: Int) -> Bool {
        guard state.isPlayerItemLoaded || state.isReadyToPlay, let playerItem else { return false }
        let isForward = count.signum() == 1
        return isForward ? playerItem.canStepForward : playerItem.canStepBackward
    }
    
    /// Evaluates whether the player item supports playback at a specified rate.
    /// - Parameter rate: The target playback rate multiplier.
    /// - Returns: `true` if playback at the specified rate is supported.
    public func canPlay(at rate: AKPlaybackRate) -> Bool {
        guard state.isPlayerItemLoaded || state.isReadyToPlay, let playerItem else { return false }
        
        switch rate.rate {
        case 0.0...:
            switch rate.rate {
            case 2.0...:
                return playerItem.canPlayFastForward
            case 1.0..<2.0:
                return true
            case 0.0..<1.0:
                return playerItem.canPlaySlowForward
            default:
                return false
            }
        case ..<0.0:
            switch rate.rate {
            case -1.0:
                return playerItem.canPlayReverse
            case -1.0..<0.0:
                return playerItem.canPlaySlowReverse
            case ..<(-1.0):
                return playerItem.canPlayFastReverse
            default:
                return false
            }
        default:
            return false
        }
    }
    
    /// Evaluates whether seeking to a target seek target position is permitted.
    /// - Parameter target: The target `AKSeekTarget` position.
    /// - Returns: `true` if the seek command is supported.
    public func canSeek(to target: AKSeekTarget) -> Bool {
        guard state.isPlayerItemLoaded || state.isReadyToPlay else { return false }
        return seekingThroughMediaService.canSeek(to: target)
    }
    
    /// Evaluates whether seeking to a target seek target is permitted and returns an unavailability reason if disallowed.
    /// - Parameter target: The target `AKSeekTarget` position.
    /// - Returns: A tuple containing a boolean flag indicating permission and an optional unavailability reason.
    public func canSeek(to target: AKSeekTarget) -> (flag: Bool, reason: AKPlayerUnavailableCommandReason?) {
        guard state.isPlayerItemLoaded || state.isReadyToPlay else {
            if state.isIdle || state.isFailed {
                return (false, .loadMediaFirst)
            } else {
                return (false, .waitTillMediaLoaded)
            }
        }
        return seekingThroughMediaService.canSeek(to: target)
    }
    
    // MARK: - Player Item Property Observation
    
    private func startObservingPlayerItemProperties() {
        guard let playerItem else { return }
        
        // Clear any existing subscriptions before re-attaching
        assetKeySubscriptions.removeAll()
        
        // 1. Tracks
        playerItem.publisher(for: \.tracks, options: [.initial, .new])
            .sink { [weak self] tracks in
                guard let self else { return }
                delegate?.akMedia(media!, didChangeTracksTo: tracks)
                emit(.tracksDidChange(tracks))
            }
            .store(in: &assetKeySubscriptions)
        
        // 2. Presentation Dimensions (Resolution)
        playerItem.publisher(for: \.presentationSize, options: [.initial, .new])
            .removeDuplicates()
            .sink { [weak self] size in
                guard let self else { return }
                delegate?.akMedia(media!, didChangePresentationSizeTo: size)
                emit(.presentationSizeDidChange(size))
            }
            .store(in: &assetKeySubscriptions)
        
        // 3. Duration
        playerItem.publisher(for: \.duration, options: [.initial, .new])
            .removeDuplicates()
            .sink { [weak self] duration in
                guard let self else { return }
                delegate?.akMedia(media!, didChangeItemDurationTo: duration)
                emit(.durationDidChange(duration))
            }
            .store(in: &assetKeySubscriptions)
        
        // 4. Timebase
        playerItem.publisher(for: \.timebase, options: [.initial, .new])
            .sink { [weak self] timebase in
                guard let self else { return }
                delegate?.akMedia(media!, didChangeTimebaseTo: timebase)
                emit(.timebaseDidChange(timebase))
            }
            .store(in: &assetKeySubscriptions)
        
        // 5. Loaded (Buffered) Time Ranges
        playerItem.publisher(for: \.loadedTimeRanges, options: [.initial, .new])
            .sink { [weak self] nsValues in
                guard let self else { return }
                let ranges = nsValues.map { $0.timeRangeValue }
                delegate?.akMedia(media!, didChangeLoadedTimeRangesTo: ranges)
                emit(.loadedTimeRangesDidChange(ranges))
            }
            .store(in: &assetKeySubscriptions)
        
        // 6. Seekable Time Ranges
        playerItem.publisher(for: \.seekableTimeRanges, options: [.initial, .new])
            .sink { [weak self] nsValues in
                guard let self else { return }
                let ranges = nsValues.map { $0.timeRangeValue }
                delegate?.akMedia(media!, didChangeSeekableTimeRangesTo: ranges)
                emit(.seekableTimeRangesDidChange(ranges))
            }
            .store(in: &assetKeySubscriptions)
        
        // 7. Playback Capabilities
        observeCapability(\.canStepForward, capability: .stepForward, on: playerItem)
        observeCapability(\.canStepBackward, capability: .stepBackward, on: playerItem)
        observeCapability(\.canPlayReverse, capability: .playReverse, on: playerItem)
        observeCapability(\.canPlayFastForward, capability: .playFastForward, on: playerItem)
        observeCapability(\.canPlayFastReverse, capability: .playFastReverse, on: playerItem)
        observeCapability(\.canPlaySlowForward, capability: .playSlowForward, on: playerItem)
        observeCapability(\.canPlaySlowReverse, capability: .playSlowReverse, on: playerItem)
    }
    
    // Helper to keep capability observations DRY (Don't Repeat Yourself)
    private func observeCapability(
        _ keyPath: KeyPath<AVPlayerItem, Bool>,
        capability: AKMediaCapability,
        on item: AVPlayerItem
    ) {
        item.publisher(for: keyPath, options: [.initial, .new])
            .removeDuplicates()
            .sink { [weak self] isSupported in
                guard let self else { return }
                emit(.capabilityDidChange(capability,
                                          isSupported: isSupported))
                delegate?.akMedia(
                    media!,
                    didChangeCapability: capability,
                    to: isSupported
                )
            }
            .store(in: &assetKeySubscriptions)
    }
    
    
    // MARK: - Event Dispatch
    
    /// Emits a media event to active listeners.
    public func emit(_ event: AKMediaEvent) {
        eventBroadcaster.send(event)
    }
}
