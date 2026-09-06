//
//  AKPlayerController.swift
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

import Foundation
import AVFoundation
import Combine

// MARK: - AKPlayerController

/// Core state machine controller managing playback states, `AVPlayer` interactions, observers, and state transitions.
@MainActor
public class AKPlayerController: AKPlayerControllerProtocol {
    
    // MARK: - Properties
    
    /// The underlying `AVPlayer` engine executing system media playback.
    public private(set) var player: AVPlayer
    
    /// The current concrete playback state exposed by the state controller.
    public var state: AKPlayerState {
        return controller.state
    }
    
    /// The default playback speed multiplier configured on the underlying player engine.
    public var defaultRate: AKPlaybackRate {
        get { return AKPlaybackRate(rate: player.defaultRate) }
        set { player.defaultRate = newValue.rate }
    }
    
    /// The current playback speed multiplier. Modifying this triggers play or pause actions accordingly.
    public var rate: AKPlaybackRate {
        get { return AKPlaybackRate(rate: player.rate) }
        set {
            if newValue.rate == 0 {
                pause()
            } else {
                play(at: newValue)
            }
        }
    }
    
    /// The active playable media item loaded into the controller.
    public private(set) var currentMedia: (any AKPlayable)?
    
    /// The active `AVPlayerItem` associated with current media execution.
    public var currentItem: AVPlayerItem? {
        return player.currentItem
    }
    
    /// The duration of the currently active player item.
    public var currentItemDuration: CMTime {
        return currentItem?.duration ?? .indefinite
    }
    
    /// The current playback position time of the player.
    public var currentTime: CMTime {
        player.currentTime()
    }
    
    /// The remaining playback time duration for the active media item, if available.
    public var remainingTime: CMTime? {
        guard currentItemDuration.isValid else { return nil }
        return CMTimeSubtract(currentItemDuration, currentTime)
    }
    
    /// A boolean flag indicating whether playback will automatically start upon completing loading/buffering.
    public var autoPlay: Bool {
        return controller.autoPlay
    }
    
    /// Indicates whether a seek operation is currently being performed by the seeking service.
    public var isSeeking: Bool {
        return playerSeekingThroughMediaService.isSeeking
    }
    
    /// The target position of the last requested seek operation.
    public var lastRequestedSeekPosition: AKSeekTarget? {
        return playerSeekingThroughMediaService.lastRequestedSeekTarget
    }
    
    /// The audio output playback volume level, ranging from 0.0 to 1.0.
    public var volume: Float {
        get { return player.volume }
        set { player.volume = newValue }
    }
    
    /// A boolean flag indicating whether player audio output is muted.
    public var isMuted: Bool {
        get { return player.isMuted }
        set { player.isMuted = newValue }
    }
    
    /// The current error object if the controller is in a failed state.
    public var error: AKPlayerError? {
        return (controller as? AKFailedState)?.error
    }
    
    /// Configuration options driving player behavior and timing defaults.
    public private(set) var configuration: AKPlayerConfigurationProtocol
    
    /// The active state controller instance representing current player state logic.
    public private(set) var controller: AKPlayerStateControllerProtocol {
        get { return _controller ?? AKIdleState(playerController: self) }
        set {
            _controller = newValue
            newValue.processStateChange()
            processStateChange()
            delegate?.playerController(self, didChangeStateTo: newValue.state)
        }
    }
    
    private var _controller: AKPlayerStateControllerProtocol?
    
    /// Delegate object receiving state transition notifications, time updates, and error events.
    public weak var delegate: AKPlayerControllerDelegate?
    
    /// Service managing seek operation queuing and execution against `AVPlayer`.
    public var playerSeekingThroughMediaService: AKPlayerSeekingThroughMediaServiceProtocol
    
    /// Service monitoring network availability and reachability changes.
    public var networkStatusMonitor: AKNetworkStatusMonitorProtocol
    
    /// Observer service tracking periodic and boundary time playback events.
    private var playerPlaybackTimeObserver: AKPlayerPlaybackTimeObserverProtocol
    
    /// Observer service tracking player rate change updates.
    private var playerRateObserver: AKPlayerRateObserverProtocol
    
    /// Combine cancellable storage for active KVO and notification subscriptions.
    private var subscriptions = Set<AnyCancellable>()
    
    /// Task responsible for asynchronously consuming and processing rate change events from the player stream.
    private nonisolated(unsafe) var rateObservationTask: Task<Void, Never>?
    
    // MARK: - Initialization & Teardown
    
    /// Initializes a new `AKPlayerController` instance with a target player engine and configuration options.
    /// - Parameters:
    ///   - player: The `AVPlayer` engine driving media playback.
    ///   - configuration: Configuration settings driving timing, buffering, and lifecycle behavior.
    public init(player: AVPlayer, configuration: AKPlayerConfigurationProtocol) {
        self.player = player
        self.configuration = configuration
        
        self.playerRateObserver = AKPlayerRateObserver(with: player)
        self.playerPlaybackTimeObserver = AKPlayerPlaybackTimeObserver(with: player)
        self.playerSeekingThroughMediaService = AKPlayerSeekingThroughMediaService(with: player)
        self.networkStatusMonitor = AKNetworkStatusMonitor()
    }
    
    deinit {
        print("AKPlayerController: Deinit called from the AKPlayerController ✌🏼")
        rateObservationTask?.cancel()
        rateObservationTask = nil
    }
    
    // MARK: - Time Observers
    
    /// Registers boundary time points to trigger observer delegate callbacks during playback.
    /// - Parameter times: An array of target boundary times represented as `CMTime`.
    public func addBoundaryTimeObserver(for times: [CMTime]) {
        playerPlaybackTimeObserver.startObservingBoundaryTime(for: times)
    }
    
    /// Removes active boundary time observers from the playback pipeline.
    public func removeBoundaryTimeObserver() {
        playerPlaybackTimeObserver.stopObservingBoundaryTime()
    }
    
    // MARK: - Playback Commands
    
    /// Loads a playable media item into the state pipeline.
    /// - Parameters:
    ///   - media: The target media item conforming to `AKPlayable`.
    ///   - autoPlay: Controls whether playback automatically begins after loading.
    ///   - position: An optional initial seek target position to apply upon load completion.
    public func load(media: any AKPlayable, autoPlay: Bool, at position: AKSeekTarget?) {
        if !state.isAny(of: [.idle, .paused, .stopped, .failed]) {
            pause()
        }
        currentMedia = media
        controller.load(media: media, autoPlay: autoPlay, at: position)
    }
    
    /// Commands the current state controller to initiate or resume playback.
    public func play() {
        controller.play()
    }
    
    /// Commands the current state controller to initiate playback at a specific speed multiplier.
    /// - Parameter rate: The target playback rate multiplier.
    public func play(at rate: AKPlaybackRate) {
        controller.play(at: rate)
    }
    
    /// Commands the current state controller to pause active media playback.
    public func pause() {
        controller.pause()
    }
    
    /// Commands the current state controller to toggle between play and pause states.
    public func togglePlayPause() {
        controller.togglePlayPause()
    }
    
    /// Commands the current state controller to stop media playback and reset position.
    public func stop() {
        controller.stop()
    }
    
    // MARK: - Seeking Commands
    
    /// Asynchronously seeks to a designated target position within current media.
    /// - Parameter target: The target position (`.time`, `.seconds`, `.offset`, `.percentage`, or `.date`).
    /// - Returns: `true` if the seek command was accepted and executed successfully; `false` otherwise.
    public func seek(to target: AKSeekTarget) async -> Bool {
        return await withCheckedContinuation { continuation in
            seek(to: target) { finished in
                continuation.resume(returning: finished)
            }
        }
    }
    
    /// Asynchronously seeks to a designated target position with explicit tolerance bounds.
    /// - Parameters:
    ///   - target: The target position (`.time`, `.seconds`, `.offset`, `.percentage`, or `.date`).
    ///   - toleranceBefore: Acceptable time offset tolerance before the target position.
    ///   - toleranceAfter: Acceptable time offset tolerance after the target position.
    /// - Returns: `true` if the seek command was accepted and executed successfully; `false` otherwise.
    public func seek(to target: AKSeekTarget, toleranceBefore: CMTime, toleranceAfter: CMTime) async -> Bool {
        return await withCheckedContinuation { continuation in
            seek(to: target, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter) { finished in
                continuation.resume(returning: finished)
            }
        }
    }
    
    /// Seeks to a designated target position with a completion callback.
    /// - Parameters:
    ///   - target: The target position (`.time`, `.seconds`, `.offset`, `.percentage`, or `.date`).
    ///   - completionHandler: A callback invoked when the seek operation finishes or is canceled, receiving a boolean indicating success.
    public func seek(to target: AKSeekTarget, completionHandler: @escaping @Sendable (Bool) -> Void) {
        controller.seek(to: target, completionHandler: completionHandler)
    }
    
    /// Seeks to a designated target position with custom tolerance bounds and a completion callback.
    /// - Parameters:
    ///   - target: The target position (`.time`, `.seconds`, `.offset`, `.percentage`, or `.date`).
    ///   - toleranceBefore: Acceptable time offset tolerance before the target position.
    ///   - toleranceAfter: Acceptable time offset tolerance after the target position.
    ///   - completionHandler: A callback invoked when the seek operation finishes or is canceled, receiving a boolean indicating success.
    public func seek(to target: AKSeekTarget, toleranceBefore: CMTime, toleranceAfter: CMTime, completionHandler: @escaping @Sendable (Bool) -> Void) {
        controller.seek(to: target, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter, completionHandler: completionHandler)
    }
    
    // MARK: - Media Navigation
    
    /// Steps frame-by-frame through video media by a specified frame offset.
    /// - Parameter count: The frame offset count (positive for forward, negative for reverse).
    public func step(by count: Int) {
        controller.step(by: count)
    }
    
    /// Fast-forwards playback using the default fast-forward speed defined in configuration.
    public func fastForward() {
        controller.fastForward()
    }
    
    /// Fast-forwards playback at a specified custom speed multiplier rate.
    /// - Parameter rate: The target fast-forward playback speed multiplier.
    public func fastForward(at rate: AKPlaybackRate) {
        controller.fastForward(at: rate)
    }
    
    /// Rewinds playback using the default rewind speed defined in configuration.
    public func rewind() {
        controller.rewind()
    }
    
    /// Rewinds playback at a specified custom speed multiplier rate.
    /// - Parameter rate: The target rewind playback speed multiplier.
    public func rewind(at rate: AKPlaybackRate) {
        controller.rewind(at: rate)
    }
    
    // MARK: - Helper & Pipeline Management Functions
    
    /// Prepares the controller pipeline, initializes idle state, starts network monitoring, and attaches observers.
    /// - Throws: An error if setting up active pipeline components fails.
    public func prepare() throws {
        controller = AKIdleState(playerController: self)
        networkStatusMonitor.startObserving()
        startPlayerObservers()
    }
    
    /// Transitions the current state controller to a new state controller instance.
    /// - Parameter controller: The target state controller conforming to `AKPlayerStateControllerProtocol`.
    public func change(_ controller: AKPlayerStateControllerProtocol) {
        self.controller = controller
    }
    
    /// Hook called whenever state changes to execute custom side effects based on active state.
    public func processStateChange() {
        switch state {
        case .idle, .loading, .loaded, .buffering, .paused, .playing, .stopped, .waitingForNetwork, .failed:
            break
        }
    }
    
    /// Begins observing player rates, volume, mute state, and time changes via Combine publishers.
    private func startPlayerObservers() {
        playerRateObserver.startObserving()
        playerPlaybackTimeObserver.startObservingPeriodicTime(for: configuration.getPeriodicTimeInterval())
        
        rateObservationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await change in playerRateObserver.rateChanges {
                self.delegate?.playerController(self, didChangePlaybackRateTo: change.currentRate, from: change.previousRate)
            }
        }
        
        player.publisher(for: \.volume)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] volume in
                guard let self else { return }
                self.delegate?.playerController(self, didChangeVolumeTo: volume)
            }
            .store(in: &subscriptions)
        
        player.publisher(for: \.isMuted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isMuted in
                guard let self else { return }
                self.delegate?.playerController(self, didChangeMutedStatusTo: isMuted)
            }
            .store(in: &subscriptions)
        
        playerPlaybackTimeObserver.periodicTimePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                guard let self, let currentMedia = self.currentMedia else { return }
                self.delegate?.playerController(self, didChangeCurrentTimeTo: time, for: currentMedia)
            }
            .store(in: &subscriptions)
        
        playerPlaybackTimeObserver.boundaryTimePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                guard let self, let currentMedia = self.currentMedia else { return }
                self.delegate?.playerController(self, didInvokeBoundaryTimeObserverAt: time, for: currentMedia)
            }
            .store(in: &subscriptions)
    }
    
    /// Stops time and rate observers attached to the underlying player instance.
    private func stopPlayerObservers() {
        playerRateObserver.stopObserving()
        playerPlaybackTimeObserver.stopObservingPeriodicTime()
        playerPlaybackTimeObserver.stopObservingBoundaryTime()
    }
    
    /// Notifies the delegate when an attempted playback operation is unavailable in the current state.
    /// - Parameter reason: The unavailable command reason explaining why the action was rejected.
    private func unavailableCommand(reason: AKPlayerUnavailableCommandReason) {
        delegate?.playerController(self, didEncounterUnavailableAction: reason)
    }
}

// MARK: - Direct Action Implementations

extension AKPlayerController {
    
    /// Directly issues a `play()` command to the underlying `AVPlayer`.
    public func performPlay() {
        player.play()
    }
    
    /// Directly sets the playback rate on the underlying `AVPlayer`.
    /// - Parameter rate: The target playback speed rate multiplier.
    public func performPlay(at rate: AKPlaybackRate) {
        player.rate = rate.rate
    }
    
    /// Directly issues a `pause()` command to the underlying `AVPlayer`.
    public func performPause() {
        player.pause()
    }
    
    /// Directly pauses playback, resets position to time zero, and cancels pending seek requests.
    public func performStop() {
        player.pause()
        player.seek(to: .zero)
        playerSeekingThroughMediaService.cancelAll()
    }
    
    /// Submits a target seek token directly to the seek service for execution.
    /// - Parameter targetSeek: The seek payload object containing target parameters and completion callbacks.
    public func performSeek(to targetSeek: AKSeek) {
        playerSeekingThroughMediaService.seek(to: targetSeek)
    }
    
    /// Directly steps the current player item forward or backward by a specific frame count.
    /// - Parameter count: The frame offset count (positive for forward, negative for reverse).
    public func performStep(by count: Int) {
        player.currentItem?.step(byCount: count)
    }
}
