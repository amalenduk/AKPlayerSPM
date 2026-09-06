//
//  AKPlayer.swift
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

// MARK: - AKPlayer

/// Primary high-level interface providing media playback control, state inspection, and delegate forwarding.
@MainActor
public class AKPlayer: NSObject, AKPlayerProtocol {
    
    // MARK: - Properties
    
    /// The currently active playable media item loaded into the player pipeline.
    public var currentMedia: (any AKPlayable)? {
        return manager.currentMedia
    }
    
    /// The underlying `AVPlayerItem` associated with the current media item.
    public var currentItem: AVPlayerItem? {
        return manager.currentItem
    }
    
    /// The current playback time position of the active media item.
    public var currentTime: CMTime {
        return manager.currentTime
    }
    
    /// The total duration of the currently active media item.
    public var currentItemDuration: CMTime {
        return manager.currentItemDuration
    }
    
    /// The remaining playback time duration for the active media item, if available.
    public var remainingTime: CMTime? {
        return manager.remainingTime
    }
    
    /// Indicates whether playback will automatically start upon completing media load and buffering operations.
    public var autoPlay: Bool {
        return manager.autoPlay
    }
    
    /// A boolean flag indicating whether a seek operation is currently in progress.
    public var isSeeking: Bool {
        return manager.isSeeking
    }
    
    /// The target position of the most recent seek request.
    public var lastRequestedSeekPosition: AKSeekTarget? {
        return manager.lastRequestedSeekPosition
    }
    
    /// The current concrete playback state of the player.
    public var state: AKPlayerState {
        return manager.state
    }
    
    /// The default speed multiplier used when initiating normal playback.
    public var defaultRate: AKPlaybackRate {
        get { return manager.defaultRate }
        set { manager.defaultRate = newValue }
    }
    
    /// The active playback rate speed multiplier.
    public var rate: AKPlaybackRate {
        get { return manager.rate }
        set { manager.rate = newValue }
    }
    
    /// The audio output playback volume level, ranging from 0.0 to 1.0.
    public var volume: Float {
        get { return manager.volume }
        set { manager.volume = newValue }
    }
    
    /// A boolean flag indicating whether player audio output is muted.
    public var isMuted: Bool {
        get { return manager.isMuted }
        set { manager.isMuted = newValue }
    }
    
    /// The most recent error encountered by the player state machine or underlying pipeline.
    public var error: AKPlayerError? {
        return manager.error
    }
    
    /// The underlying `AVPlayer` engine driving system media execution.
    public var player: AVPlayer {
        return manager.player
    }
    
    /// The player manager instance handling core state machine lifecycle and engine operations.
    public var manager: AKPlayerManagerProtocol
    
    /// The active Now Playing info and remote command center session.
    public var nowPlayingSession: AKNowPlayingSession? {
        return manager.nowPlayingSession
    }
    
    /// The delegate object receiving high-level player state transitions, playback events, and error notifications.
    public weak var delegate: AKPlayerDelegate?
    
    // MARK: - Initialization & Teardown
    
    /// Initializes a new `AKPlayer` instance configured with player dependencies.
    /// - Parameters:
    ///   - player: The underlying `AVPlayer` instance. Defaults to a new instance.
    ///   - configuration: Configuration options driving player behavior. Defaults to `AKPlayerConfiguration.default`.
    ///   - audioSessionService: The audio session management service instance. Defaults to `AKAudioSessionService()`.
    public init(
        player: AVPlayer = AVPlayer(),
        configuration: AKPlayerConfigurationProtocol = AKPlayerConfiguration.default,
        audioSessionService: AKAudioSessionServiceProtocol = AKAudioSessionService()
    ) {
        self.manager = AKPlayerManager(
            player: player,
            configuration: configuration,
            audioSessionService: audioSessionService
        )
        super.init()
        self.manager.delegate = self
    }
    
    deinit { }
    
    // MARK: - Setup
    
    /// Prepares the player pipeline and configures initial system audio session settings.
    /// - Throws: An error if setting up the underlying audio session fails.
    public func prepare() throws {
        try manager.prepare()
    }
    
    /// Configures boundary observers to trigger notifications when specific media playback times are reached.
    /// - Parameter times: An array of target boundary time points represented as `CMTime`.
    public func addBoundaryTimeObserver(for times: [CMTime]) {
        manager.addBoundaryTimeObserver(for: times)
    }
    
    /// Removes active boundary time observers from the media pipeline.
    public func removeBoundaryTimeObserver() {
        manager.removeBoundaryTimeObserver()
    }
    
    // MARK: - Loading Media
    
    /// Loads a new playable media item into the player pipeline.
    /// - Parameters:
    ///   - media: The target media item conforming to `AKPlayable`.
    ///   - autoPlay: Controls whether playback automatically begins when media loading and buffering complete.
    ///   - position: An optional initial seek target position to apply upon load completion.
    public func load(media: any AKPlayable, autoPlay: Bool, at position: AKSeekTarget?) {
        manager.load(
            media: media,
            autoPlay: autoPlay,
            at: position
        )
    }
    
    // MARK: - Controlling Playback
    
    /// Commands the player to begin media playback at the current default rate.
    public func play() {
        manager.play()
    }
    
    /// Commands the player to begin media playback at a specified speed multiplier.
    /// - Parameter rate: The target playback rate multiplier.
    public func play(at rate: AKPlaybackRate) {
        manager.play(at: rate)
    }
    
    /// Commands the player to pause active media playback.
    public func pause() {
        manager.pause()
    }
    
    /// Toggles between play and pause states based on current active playback status.
    public func togglePlayPause() {
        manager.togglePlayPause()
    }
    
    /// Stops playback and tears down active player pipeline operations.
    public func stop() {
        manager.stop()
    }
    
    // MARK: - Seeking Through Media
    
    /// Asynchronously seeks to a designated target position within the current media.
    /// - Parameter target: The target position (`.time`, `.seconds`, `.offset`, `.percentage`, or `.date`).
    /// - Returns: `true` if the seek command was accepted and successfully executed; `false` otherwise.
    @discardableResult
    public func seek(to target: AKSeekTarget) async -> Bool {
        await manager.seek(to: target)
    }
    
    /// Asynchronously seeks to a designated target position with explicit tolerance parameters.
    /// - Parameters:
    ///   - target: The target position (`.time`, `.seconds`, `.offset`, `.percentage`, or `.date`).
    ///   - toleranceBefore: Acceptable time offset tolerance before the target position.
    ///   - toleranceAfter: Acceptable time offset tolerance after the target position.
    /// - Returns: `true` if the seek command was accepted and successfully executed; `false` otherwise.
    @discardableResult
    public func seek(to target: AKSeekTarget, toleranceBefore: CMTime, toleranceAfter: CMTime) async -> Bool {
        await manager.seek(to: target, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter)
    }
    
    /// Seeks to a designated target position with a completion callback.
    /// - Parameters:
    ///   - target: The target position (`.time`, `.seconds`, `.offset`, `.percentage`, or `.date`).
    ///   - completionHandler: A callback invoked when the seek operation completes or is canceled, receiving a boolean indicating success.
    public func seek(to target: AKSeekTarget, completionHandler: @escaping @Sendable (Bool) -> Void) {
        manager.seek(to: target, completionHandler: completionHandler)
    }
    
    /// Seeks to a designated target position with custom tolerance bounds and a completion callback.
    /// - Parameters:
    ///   - target: The target position (`.time`, `.seconds`, `.offset`, `.percentage`, or `.date`).
    ///   - toleranceBefore: Acceptable time offset tolerance before the target position.
    ///   - toleranceAfter: Acceptable time offset tolerance after the target position.
    ///   - completionHandler: A callback invoked when the seek operation completes or is canceled, receiving a boolean indicating success.
    public func seek(to target: AKSeekTarget, toleranceBefore: CMTime, toleranceAfter: CMTime, completionHandler: @escaping @Sendable (Bool) -> Void) {
        manager.seek(to: target, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter, completionHandler: completionHandler)
    }
    
    // MARK: - Media Navigation
    
    /// Steps frame-by-frame through video media by a specified frame count offset.
    /// - Parameter count: The frame offset count (positive for forward, negative for reverse).
    public func step(by count: Int) {
        manager.step(by: count)
    }
    
    /// Fast-forwards playback using the default fast-forward speed defined in player configuration.
    public func fastForward() {
        manager.fastForward()
    }
    
    /// Fast-forwards playback at a custom speed multiplier.
    /// - Parameter rate: The target fast-forward playback rate multiplier.
    public func fastForward(at rate: AKPlaybackRate) {
        manager.fastForward(at: rate)
    }
    
    /// Rewinds playback using the default rewind speed defined in player configuration.
    public func rewind() {
        manager.rewind()
    }
    
    /// Rewinds playback at a custom speed multiplier.
    /// - Parameter rate: The target rewind playback rate multiplier.
    public func rewind(at rate: AKPlaybackRate) {
        manager.rewind(at: rate)
    }
}

// MARK: - AKPlayerManagerDelegate

extension AKPlayer: AKPlayerManagerDelegate {
    
    /// Delegates state change events emitted from the player manager to the public player delegate.
    /// - Parameters:
    ///   - playerManager: The underlying player manager source.
    ///   - state: The new concrete player state.
    public func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangeStateTo state: AKPlayerState
    ) {
        delegate?.akPlayer(self, didChangeStateTo: state)
    }
    
    /// Delegates active media change events emitted from the player manager to the public player delegate.
    /// - Parameters:
    ///   - playerManager: The underlying player manager source.
    ///   - media: The new active playable media item.
    public func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangeMediaTo media: any AKPlayable
    ) {
        delegate?.akPlayer(self, didChangeMediaTo: media)
    }
    
    /// Delegates playback rate change events emitted from the player manager to the public player delegate.
    /// - Parameters:
    ///   - playerManager: The underlying player manager source.
    ///   - newRate: The updated playback speed multiplier.
    ///   - oldRate: The previous playback speed multiplier.
    public func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangePlaybackRateTo newRate: AKPlaybackRate,
        from oldRate: AKPlaybackRate
    ) {
        delegate?.akPlayer(self, didChangePlaybackRateTo: newRate, from: oldRate)
    }
    
    /// Delegates playback position time change events emitted from the player manager to the public player delegate.
    /// - Parameters:
    ///   - playerManager: The underlying player manager source.
    ///   - currentTime: The updated current time position.
    ///   - media: The active media item associated with the event.
    public func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangeCurrentTimeTo currentTime: CMTime,
        for media: any AKPlayable
    ) {
        delegate?.akPlayer(self, didChangeCurrentTimeTo: currentTime, for: media)
    }
    
    /// Delegates boundary time observer invocation events emitted from the player manager to the public player delegate.
    /// - Parameters:
    ///   - playerManager: The underlying player manager source.
    ///   - time: The boundary time position reached.
    ///   - media: The active media item associated with the event.
    public func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didInvokeBoundaryTimeObserverAt time: CMTime,
        for media: any AKPlayable
    ) {
        delegate?.akPlayer(self, didInvokeBoundaryTimeObserverAt: time, for: media)
    }
    
    /// Delegates media playback completion events emitted from the player manager to the public player delegate.
    /// - Parameters:
    ///   - playerManager: The underlying player manager source.
    ///   - time: The playback end time position.
    ///   - media: The media item that reached completion.
    public func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didReachEndAt time: CMTime,
        for media: any AKPlayable
    ) {
        delegate?.akPlayer(self, didReachEndAt: time, for: media)
    }
    
    /// Delegates volume level change events emitted from the player manager to the public player delegate.
    /// - Parameters:
    ///   - playerManager: The underlying player manager source.
    ///   - volume: The updated output volume level.
    public func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangeVolumeTo volume: Float
    ) {
        delegate?.akPlayer(self, didChangeVolumeTo: volume)
    }
    
    /// Delegates audio mute status change events emitted from the player manager to the public player delegate.
    /// - Parameters:
    ///   - playerManager: The underlying player manager source.
    ///   - isMuted: The updated audio mute state boolean flag.
    public func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangeMutedStatusTo isMuted: Bool
    ) {
        delegate?.akPlayer(self, didChangeMutedStatusTo: isMuted)
    }
    
    /// Delegates action unavailability notifications emitted from the player manager to the public player delegate.
    /// - Parameters:
    ///   - playerManager: The underlying player manager source.
    ///   - reason: The specific reason explaining why the requested action was unavailable.
    public func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didEncounterUnavailableAction reason: AKPlayerUnavailableCommandReason
    ) {
        delegate?.akPlayer(self, didEncounterUnavailableAction: reason)
    }
    
    /// Delegates player error notifications emitted from the player manager to the public player delegate.
    /// - Parameters:
    ///   - playerManager: The underlying player manager source.
    ///   - error: The player error encountered.
    public func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didFailWith error: AKPlayerError
    ) {
        delegate?.akPlayer(self, didFailWith: error)
    }
}
