//
//  AKPlayerManager.swift
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
import MediaPlayer

// MARK: - AKPlayerManager

/// Main orchestrator managing audio session lifecycles, player controls, lifecycle observer updates, and `MPNowPlayingInfoCenter` integrations.
@MainActor
public class AKPlayerManager: NSObject, AKPlayerManagerProtocol {
    // MARK: - Properties

    /// The underlying `AVPlayer` instance controlling media playback.
    public var player: AVPlayer {
        return playerController.player
    }

    /// Current state of the player (e.g., playing, paused, stopped, failed).
    public var state: AKPlayerState {
        return playerController.state
    }

    /// Default rate used when initiating media playback.
    public var defaultRate: AKPlaybackRate {
        get { return playerController.defaultRate }
        set { playerController.defaultRate = newValue }
    }

    /// Current rate of audio playback (1.0 = normal, 0.0 = paused).
    public var rate: AKPlaybackRate {
        get { return playerController.rate }
        set { playerController.rate = newValue }
    }

    /// The current active playable media metadata item.
    public var currentMedia: (any AKPlayable)? {
        return playerController.currentMedia
    }

    /// The current `AVPlayerItem` loaded in the player.
    public var currentItem: AVPlayerItem? {
        return playerController.currentItem
    }

    /// The total duration of the currently playing item as `CMTime`.
    public var currentItemDuration: CMTime {
        return playerController.currentItemDuration
    }

    /// The current playback position in time as `CMTime`.
    public var currentTime: CMTime {
        return playerController.currentTime
    }

    /// The remaining playback time of the active item, if available.
    public var remainingTime: CMTime? {
        return playerController.remainingTime
    }

    /// Flag indicating whether playback starts automatically upon loading media.
    public var autoPlay: Bool {
        return playerController.autoPlay
    }

    /// Flag indicating if a seek action is currently in progress.
    public var isSeeking: Bool {
        return playerController.isSeeking
    }

    /// The target time or position requested during the latest seek command.
    public var lastRequestedSeekPosition: AKSeekTarget? {
        return playerController.lastRequestedSeekPosition
    }

    /// The current output volume level (0.0 to 1.0).
    public var volume: Float {
        get { return playerController.volume }
        set { playerController.volume = newValue }
    }

    /// Flag indicating whether the player volume is muted.
    public var isMuted: Bool {
        get { return playerController.isMuted }
        set { playerController.isMuted = newValue }
    }

    /// Contains player errors if any occur during initialization or playback.
    public var error: AKPlayerError? {
        return playerController.error
    }

    /// Asynchronous stream of player events for Swift Concurrency.
    public var events: AsyncStream<AKPlayerEvent> {
        return playerController.events
    }

    /// Controller managing underlying AVPlayer actions and state machine transitions.
    public let playerController: AKPlayerControllerProtocol

    /// Configuration options governing player behavior, audio session settings, and remote controls.
    public var configuration: AKPlayerConfigurationProtocol {
        return playerController.configuration
    }

    /// Snapshot storing playback and app states during interruptions for resumption logic.
    public private(set) var playerStateSnapshot: AKPlayerStateSnapshot?

    private let eventBroadcaster = AKEventBroadcaster<AKPlayerEvent>()

    /// Task managing the asynchronous event stream from the player controller.
    private var controllerEventsTask: Task<Void, Never>?

    /// Tracks connection status of external audio devices (e.g., Bluetooth, headphones).
    private var isExternalAudioPlaybackDeviceConnected: Bool = false

    /// Audio session service managing system category, modes, and activation state.
    public let audioSessionService: AKAudioSessionServiceProtocol

    /// Session handling integration with system Now Playing info and lock screen controls.
    public var nowPlayingSession: AKNowPlayingSession?

    /// Observer responsible for audio interruption notifications (e.g., incoming phone calls).
    private var audioSessionInterruptionObserver: AKAudioSessionInterruptionObserverProtocol!

    /// Observer handling route changes (e.g., unplugging headphones or disconnecting Bluetooth).
    private var audioSessionRouteChangesObserver: AKAudioSessionRouteChangesObserverProtocol!

    /// Observer handling `mediaServicesWereReset` system restore notifications.
    private var audioSessionMediaServicesWereResetObserver:
        AKAudioSessionMediaServicesWereResetObserverProtocol!

    /// Observer monitoring app lifecycle changes (entering background/foreground, resigning active).
    private var applicationLifeCycleEventsObserver: AKApplicationLifeCycleEventsObserverProtocol!

    // MARK: - Init & Deinit

    /// Initializes a new instance of `AKPlayerManager`.
    /// - Parameters:
    ///   - player: The `AVPlayer` instance used for playback.
    ///   - configuration: Configuration settings for player audio and control parameters.
    ///   - audioSessionService: Service interface for managing `AVAudioSession`.
    public init(
        player: AVPlayer,
        configuration: AKPlayerConfigurationProtocol,
        audioSessionService: AKAudioSessionServiceProtocol
    ) {
        playerController = AKPlayerController(
            player: player,
            configuration: configuration
        )
        self.audioSessionService = audioSessionService
        super.init()

        audioSessionInterruptionObserver = AKAudioSessionInterruptionObserver(
            audioSession: audioSessionService.audioSession
        )
        audioSessionRouteChangesObserver = AKAudioSessionRouteChangesObserver(
            audioSession: audioSessionService.audioSession
        )
        audioSessionMediaServicesWereResetObserver = AKAudioSessionMediaServicesWereResetObserver(
            audioSession: audioSessionService.audioSession
        )
        applicationLifeCycleEventsObserver = AKApplicationLifeCycleEventsObserver()

        audioSessionInterruptionObserver.delegate = self
        audioSessionRouteChangesObserver.delegate = self
        audioSessionMediaServicesWereResetObserver.delegate = self
        applicationLifeCycleEventsObserver.delegate = self

        startObservingPlayerEvents()
        setupNowPlayingSession()
    }

    deinit {
        controllerEventsTask?.cancel()
        controllerEventsTask = nil
        eventBroadcaster.finish()
        print("AKPlayerManager: Deinit called from the AKPlayerManager ✌🏼")
    }

    // MARK: - Lifecycle Preparation

    /// Configures the audio session, prepares the player controller, activates Now Playing, and begins system observers.
    /// - Throws: `AKPlayerError` or `AVAudioSession` setup errors during initialization.
    public func prepare() throws {
        try setAudioSession(true)
        try playerController.prepare()
        try setNowPlayingSessionActive()

        startObservers()
        isExternalAudioPlaybackDeviceConnected =
            audioSessionRouteChangesObserver.isExternalDeviceConnected()
    }

    // MARK: - Now Playing Info Management

    /// Updates lock screen metadata (`MPNowPlayingInfoCenter`) with static and dynamic media info.
    public func setNowPlayingInfo() {
        guard configuration.isNowPlayingEnabled,
              let nowPlayingSession,
              let nowPlayableMetadata = currentNowPlayingMetadata()
        else { return }
        nowPlayingSession.setNowPlayingInfo(nowPlayableMetadata)
    }

    /// Fetches currently active metadata payload used by Now Playing command centers.
    /// - Returns: Built `AKNowPlayableMetadata` object containing static and dynamic properties, or `nil`.
    public func currentNowPlayingMetadata() -> AKNowPlayableMetadata? {
        guard let currentMedia = currentMedia else { return nil }

        return AKNowPlayableMetadata(
            staticMetadata: currentMedia.staticMetadata,
            dynamicMetadata: getNowPlayableDynamicMetadata()
        )
    }

    /// Computes dynamic state metadata such as playback position, duration, and progress ratio.
    /// - Returns: Protocol instance containing dynamic playback metadata, or `nil`.
    public func getNowPlayableDynamicMetadata() -> (any AKNowPlayableDynamicMetadataProtocol)? {
        guard let currentMedia = currentMedia else { return nil }

        let position =
            currentMedia.isLive()
                ? nil
                : (currentItem?.currentTime().isValid ?? false
                    ? Double(currentItem!.currentTime().seconds) : nil)
        let duration =
            currentMedia.isLive()
                ? nil : (currentItem?.duration.isValid ?? false ? Float(currentItem!.duration.seconds) : nil)

        let playbackProgress: Float? = {
            guard let pos = position, let dur = duration, dur > 0 else { return nil }
            return min(max(Float(pos / Double(dur)), 0.0), 1.0)
        }()

        return AKNowPlayableDynamicMetadata(
            rate: Double(rate.rate),
            defaultRate: Double(defaultRate.rate),
            position: position,
            duration: duration,
            currentLanguageOptions: nil,
            availableLanguageOptionGroups: nil,
            chapterCount: nil,
            chapterNumber: nil,
            creditsStartTime: nil,
            currentPlaybackDate: nil,
            playbackProgress: playbackProgress,
            playbackQueueCount: nil,
            playbackQueueIndex: nil,
            serviceIdentifier: nil
        )
    }

    // MARK: - Boundary Observers

    /// Adds boundary time tracking points to notify when playback reaches explicit timestamps.
    /// - Parameter times: Array of `CMTime` markers to observe.
    public func addBoundaryTimeObserver(for times: [CMTime]) {
        playerController.addBoundaryTimeObserver(for: times)
    }

    /// Removes active boundary time observers from the underlying player.
    public func removeBoundaryTimeObserver() {
        playerController.removeBoundaryTimeObserver()
    }

    // MARK: - Playback Commands

    /// Loads a media item into the player controller with optional auto-playback and initial seek target.
    /// - Parameters:
    ///   - media: Any playable item conforming to `AKPlayable`.
    ///   - autoPlay: Whether playback should start automatically after loading.
    ///   - position: Optional seek target location to initialize playback at.
    public func load(media: any AKPlayable, autoPlay: Bool, at position: AKSeekTarget?) {
        guard canPlayInCurrentLifecycleState() else { return actionNotPermitted() }
        if autoPlay {
            return performPlaybackAction { [weak self] in
                self?.playerController.load(
                    media: media,
                    autoPlay: autoPlay,
                    at: position
                )
            }
        }
        playerController.load(
            media: media,
            autoPlay: autoPlay,
            at: position
        )
    }

    /// Initiates media playback at normal default speed.
    public func play() {
        guard canPlayInCurrentLifecycleState() else { return actionNotPermitted() }
        performPlaybackAction { [weak self] in self?.playerController.play() }
    }

    /// Initiates media playback at a specified custom rate.
    /// - Parameter rate: Speed target encapsulated by `AKPlaybackRate`.
    public func play(at rate: AKPlaybackRate) {
        guard canPlayInCurrentLifecycleState() else { return actionNotPermitted() }
        performPlaybackAction { [weak self] in self?.playerController.play(at: rate) }
    }

    /// Pauses active playback.
    public func pause() {
        playerController.pause()
    }

    /// Toggles between play and pause states based on current state.
    public func togglePlayPause() {
        switch state {
        case .loaded where !autoPlay, .paused, .stopped, .failed:
            guard canPlayInCurrentLifecycleState() else { return actionNotPermitted() }
            performPlaybackAction { [weak self] in self?.playerController.togglePlayPause() }
        default:
            playerController.togglePlayPause()
        }
    }

    /// Stops playback and invalidates active state resumption flags.
    public func stop() {
        playerStateSnapshot?.shouldResume = false
        playerController.stop()
    }

    /// Asynchronously seeks to a specific time target.
    /// - Parameter target: The position target defined as an `AKSeekTarget`.
    /// - Returns: `true` if the seek completed successfully; otherwise `false`.
    @discardableResult
    public func seek(to target: AKSeekTarget) async -> Bool {
        await playerController.seek(to: target)
    }

    /// Asynchronously seeks to a specific target within specified exact tolerance windows.
    /// - Parameters:
    ///   - target: The position target defined as an `AKSeekTarget`.
    ///   - toleranceBefore: Maximum allowed time delta before the target position.
    ///   - toleranceAfter: Maximum allowed time delta after the target position.
    /// - Returns: `true` if the seek completed successfully; otherwise `false`.
    @discardableResult
    public func seek(to target: AKSeekTarget, toleranceBefore: CMTime, toleranceAfter: CMTime) async
        -> Bool
    {
        await playerController.seek(
            to: target,
            toleranceBefore: toleranceBefore,
            toleranceAfter: toleranceAfter
        )
    }

    public func seek(to target: AKSeekTarget, completionHandler: @escaping @Sendable (Bool) -> Void) {
        playerController.seek(to: target, completionHandler: completionHandler)
    }

    public func seek(
        to target: AKSeekTarget, toleranceBefore: CMTime, toleranceAfter: CMTime,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        playerController.seek(
            to: target, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter,
            completionHandler: completionHandler
        )
    }

    /// Steps forward or backward by a specific number of frames.
    /// - Parameter count: Positive integer for forward frame steps, negative for backward steps.
    public func step(by count: Int) {
        playerController.step(by: count)
    }

    /// Fast-forwards playback using default fast rate settings.
    public func fastForward() {
        guard canPlayInCurrentLifecycleState() else { return actionNotPermitted() }
        performPlaybackAction { [weak self] in
            self?.playerController.fastForward()
        }
    }

    /// Fast-forwards playback at a custom rate speed.
    /// - Parameter rate: Speed target encapsulated by `AKPlaybackRate`.
    public func fastForward(at rate: AKPlaybackRate) {
        guard canPlayInCurrentLifecycleState() else { return actionNotPermitted() }
        performPlaybackAction { [weak self] in
            self?.playerController.fastForward(at: rate)
        }
    }

    /// Rewinds playback using default rewind settings.
    public func rewind() {
        guard canPlayInCurrentLifecycleState() else { return actionNotPermitted() }
        performPlaybackAction { [weak self] in
            self?.playerController.rewind()
        }
    }

    /// Rewinds playback at a custom rate speed.
    /// - Parameter rate: Speed target encapsulated by `AKPlaybackRate`.
    public func rewind(at rate: AKPlaybackRate) {
        guard canPlayInCurrentLifecycleState() else { return actionNotPermitted() }
        performPlaybackAction { [weak self] in
            self?.playerController.rewind(at: rate)
        }
    }

    // MARK: - Internal Helper Functions

    /// Subscribes system observers to route changes, interruptions, media resets, and lifecycle events.
    private func startObservers() {
        audioSessionInterruptionObserver.startObserving()
        audioSessionRouteChangesObserver.startObserving()
        audioSessionMediaServicesWereResetObserver.startObserving()
        applicationLifeCycleEventsObserver.startObserving()
    }

    /// Unsubscribes active observers from system notifications.
    private func stopObservers() {
        audioSessionInterruptionObserver.stopObserving()
        audioSessionRouteChangesObserver.stopObserving()
        audioSessionMediaServicesWereResetObserver.stopObserving()
        applicationLifeCycleEventsObserver.stopObserving()
    }

    /// Configures system `AVAudioSession` categories, options, and active states.
    /// - Parameter active: `true` to activate the audio session; `false` to deactivate.
    /// - Throws: Session setup errors thrown by system calls.
    private func setAudioSession(_ active: Bool) throws {
        guard active else {
            return try audioSessionService.activate(
                false,
                options: configuration.audioSession.activeOptions
            )
        }

        try audioSessionService.setCategory(
            configuration.audioSession.category,
            mode: configuration.audioSession.mode,
            options: configuration.audioSession.categoryOptions
        )
        try audioSessionService.activate(
            true,
            options: configuration.audioSession.activeOptions
        )
    }

    /// Verifies if app configuration rules allow playback based on the current background/inactive application state.
    /// - Returns: `true` if current lifecycle conditions allow playback to begin or resume.
    private func canPlayInCurrentLifecycleState() -> Bool {
        switch applicationLifeCycleEventsObserver.state {
        case .resignActive where configuration.playbackPausesWhenResigningActive: return false
        case .background where configuration.playbackPausesWhenBackgrounded: return false
        default: return true
        }
    }

    /// Instantiates system MPNowPlayingSession and assigns command controls.
    private func setupNowPlayingSession() {
        guard configuration.isNowPlayingEnabled else { return }
        nowPlayingSession = AKNowPlayingSession(players: [player])

        var defaultConfig = AKNowPlayingCommandConfiguration()
            .add(.play).enable(.play)
            .add(.pause).enable(.pause)
            .add(.togglePlayPause).enable(.togglePlayPause)
            .add(.changePlaybackPosition).enable(.changePlaybackPosition)
            .add(.skipForward(preferredIntervals: [10])).enable(.skipForward(preferredIntervals: [10]))
            .add(.skipBackward(preferredIntervals: [15])).enable(.skipBackward(preferredIntervals: [15]))

        Task { [weak self] in await self?.setupNowPlayingCommandHandlers() }

        Task { [weak self] in
            await self?.nowPlayingSession?.applyConfiguration(defaultConfig)
        }
    }

    /// Attaches closure handlers to system media control center command events (e.g., play/pause buttons on Control Center/Lock Screen).
    private func setupNowPlayingCommandHandlers() async {
        guard let session = nowPlayingSession else { return }

        await session.setHandler(for: .play) { @MainActor [weak self] _ in
            guard let self else { return .commandFailed }
            self.play()
            return self.state.isPlaying || self.autoPlay ? .success : .commandFailed
        }

        await session.setHandler(for: .pause) { @MainActor [weak self] _ in
            guard let self else { return .commandFailed }
            self.pause()
            return self.state.isPaused ? .success : .commandFailed
        }

        await session.setHandler(for: .stop) { @MainActor [weak self] _ in
            guard let self else { return .commandFailed }
            self.stop()
            return self.state.isStopped ? .success : .commandFailed
        }

        await session.setHandler(for: .togglePlayPause) { @MainActor [weak self] _ in
            guard let self else { return .commandFailed }
            self.togglePlayPause()
            return (self.state.isPlaying || self.state.isPaused || self.autoPlay)
                ? .success : .commandFailed
        }

        await session.setHandler(
            for: .changePlaybackRate(supportedPlaybackRates: AKPlaybackRate.allCases.map { $0.rate })
        ) { @MainActor [weak self] event in
            guard let self,
                  let currentMedia = self.currentMedia,
                  let rateEvent = event as? MPChangePlaybackRateCommandEvent,
                  currentMedia.canPlay(at: AKPlaybackRate(rate: rateEvent.playbackRate))
            else {
                return .commandFailed
            }

            self.play(at: AKPlaybackRate(rate: rateEvent.playbackRate))
            return .success
        }

        await session.setHandler(for: .seekForward) { @MainActor [weak self] event in
            guard let self,
                  let currentMedia = self.currentMedia,
                  let seekEvent = event as? MPSeekCommandEvent,
                  currentMedia.canPlay(at: AKPlaybackRate.fastest)
            else {
                return .commandFailed
            }

            switch seekEvent.type {
            case .beginSeeking:
                self.fastForward(at: .fastest)
            case .endSeeking:
                self.play(at: .normal)
            @unknown default:
                return .commandFailed
            }
            return .success
        }

        await session.setHandler(for: .seekBackward) { @MainActor [weak self] event in
            guard let self,
                  let currentMedia = self.currentMedia,
                  let seekEvent = event as? MPSeekCommandEvent,
                  currentMedia.canPlay(at: AKPlaybackRate.slowest)
            else {
                return .commandFailed
            }

            switch seekEvent.type {
            case .beginSeeking:
                self.rewind(at: .slowest)
            case .endSeeking:
                self.play(at: .normal)
            @unknown default:
                return .commandFailed
            }
            return .success
        }

        await session.setHandler(for: .skipForward(preferredIntervals: [15])) { [weak self] event in
            guard let self,
                  let skipEvent = event as? MPSkipIntervalCommandEvent,
                  let skipCommand = skipEvent.command as? MPSkipIntervalCommand
            else {
                return .commandFailed
            }

            let skipInterval = skipCommand.preferredIntervals.first?.doubleValue ?? skipEvent.interval
            let skipTime = CMTime(seconds: skipInterval, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            let targetTime = CMTimeAdd(self.currentTime, skipTime)

            guard self.currentMedia?.canSeek(to: .time(targetTime)) ?? false else {
                return .commandFailed
            }

            Task { @MainActor in
                await self.seek(to: .time(targetTime))
            }
            return .success
        }

        await session.setHandler(for: .skipBackward(preferredIntervals: [15])) { [weak self] event in
            guard let self,
                  let skipEvent = event as? MPSkipIntervalCommandEvent,
                  let skipCommand = skipEvent.command as? MPSkipIntervalCommand
            else {
                return .commandFailed
            }

            let skipInterval = skipCommand.preferredIntervals.first?.doubleValue ?? skipEvent.interval
            let skipTime = CMTime(seconds: -skipInterval, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            let targetTime = CMTimeAdd(self.currentTime, skipTime)

            guard self.currentMedia?.canSeek(to: .time(targetTime)) ?? false else {
                return .commandFailed
            }

            let clampedTime = targetTime.seconds < 0 ? CMTime.zero : targetTime
            Task { @MainActor in
                await self.seek(to: .time(clampedTime))
            }
            return .success
        }

        await session.setHandler(for: .changePlaybackPosition) { [weak self] event in
            guard let self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent
            else {
                return .commandFailed
            }

            let targetTime = CMTime(
                seconds: positionEvent.positionTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC)
            )
            guard self.currentMedia?.canSeek(to: .time(targetTime)) ?? false else {
                return .commandFailed
            }

            Task { @MainActor in
                await self.seek(to: .time(targetTime))
            }
            return .success
        }
    }

    /// Requests activation of the system MPNowPlayingSession when enabled in settings.
    /// - Throws: `AKPlayerError.nowPlayingSessionFailure` if activation fails.
    private func setNowPlayingSessionActive() throws {
        guard configuration.isNowPlayingEnabled,
              let nowPlayingSession,
              !nowPlayingSession.isActive
        else { return }
        guard nowPlayingSession.canBecomeActive() else { throw AKPlayerError.nowPlayingSessionFailure }
        Task { [weak nowPlayingSession] in
            await nowPlayingSession?.becomeActiveIfPossible()
        }
    }

    /// Safely executes throwing blocks and forwards errors to the delegate interface.
    /// - Parameters:
    ///   - block: Closure containing throwing operations.
    ///   - completion: Callback indicating whether execution succeeded without throwing.
    private func execute(
        block: () throws -> Void,
        completion: (Bool) -> Void = { _ in }
    ) {
        do {
            try block()
            return completion(true)
        } catch {
            if let playerError = error as? AKPlayerError {
                emit(.didFail(with: playerError))
            }
        }
        return completion(false)
    }

    /// Captures the current application lifecycle and playback interruption state to handle automatic state recovery.
    /// - Parameters:
    ///   - playbackInterruptionReason: The underlying reason for the interruption.
    ///   - shouldResume: Whether playback should automatically resume when the interruption ends.
    private func savePlayerStateSnapshot(
        playbackInterruptionReason: AKPlaybackInterruptionReason,
        shouldResume: Bool
    ) {
        guard var snapshot = playerStateSnapshot else {
            playerStateSnapshot = AKPlayerStateSnapshot(
                shouldResume: shouldResume,
                applicationState: applicationLifeCycleEventsObserver.state,
                playbackInterruptionReason: playbackInterruptionReason
            )
            return
        }

        snapshot.applicationState = applicationLifeCycleEventsObserver.state
        playerStateSnapshot = snapshot
    }

    /// Clears any cached player state snapshot.
    private func clearPlayerStateSnapshot() {
        playerStateSnapshot = nil
    }

    /// Notifies the delegate when an action is unavailable due to lifecycle or state restrictions.
    private func actionNotPermitted() {
        emit(.commandUnavailable(reason: .actionNotPermitted))
    }

    /// Wraps playback operations to check audio session activation and snapshot clearance before execution.
    /// - Parameter action: Closure containing playback action commands.
    private func performPlaybackAction(action: () -> Void) {
        guard let snapshot = playerStateSnapshot else { return action() }
        if snapshot.playbackInterruptionReason.isLifeCycleEvent
            || snapshot.applicationState.isResignActiveOrBackground
        {
            execute {
                try setAudioSession(true)
            } completion: { finished in
                if finished {
                    action()
                }
            }
        } else {
            action()
        }
        clearPlayerStateSnapshot()
    }

    /// Single entry point for dispatching all player events across the framework.
    /// Broadcasts the event to the delegate and forwards it to event listeners (AsyncStream / Combine).
    /// - Parameter event: The player event that occurred.
    private func emit(_ event: AKPlayerEvent) {
        eventBroadcaster.send(event)
    }

    private func startObservingPlayerEvents() {
        controllerEventsTask?.cancel()

        controllerEventsTask = Task { @MainActor [weak self] in
            guard let self else { return }

            for await event in self.playerController.events {
                // Guard against processing events after cancellation
                guard !Task.isCancelled else { break }

                self.handleControllerEvent(event)
            }
        }
    }

    private func handleControllerEvent(_ event: AKPlayerEvent) {
        if case .timeDidChange = event {
        } else {
            setNowPlayingInfo()
        }

        eventBroadcaster.send(event)
    }
}

// MARK: - AKAudioSessionInterruptionObserverDelegate

extension AKPlayerManager: AKAudioSessionInterruptionObserverDelegate {
    @MainActor
    public func audioSessionInterruptionObserver(
        _: AKAudioSessionInterruptionObserverProtocol,
        didBeginInterruptionWith _: AVAudioSession.InterruptionReason?,
        for _: AVAudioSession
    ) {
        guard
            (state.isAny(of: [
                .loading,
                .loaded,
                .buffering,
                .waitingForNetwork,
            ]) && autoPlay)
            || state == .playing
        else { return }

        /* Audio session automatically pauses player, if not will be paused here.
         Update the UI to indicate that playback or recording has paused when it’s interrupted. Do not deactivate the audio session. */
        savePlayerStateSnapshot(
            playbackInterruptionReason: .audioSessionInterruption,
            shouldResume: true
        )
        pause()
    }

    @MainActor
    public func audioSessionInterruptionObserver(
        _: AKAudioSessionInterruptionObserverProtocol,
        didEndInterruptionWith shouldResume: Bool,
        for _: AVAudioSession
    ) {
        guard configuration.playbackResumesWhenAudioSessionInterruptionEnded,
              let snapshot = playerStateSnapshot,
              snapshot.playbackInterruptionReason == .audioSessionInterruption,
              snapshot.shouldResume, shouldResume
        else { return }

        play()
    }
}

// MARK: - AKAudioSessionRouteChangesObserverDelegate

extension AKPlayerManager: AKAudioSessionRouteChangesObserverDelegate {
    @MainActor
    public func audioSessionRouteChangesObserver(
        _ observer: AKAudioSessionRouteChangesObserverProtocol,
        didChangeRouteTo _: AVAudioSessionRouteDescription,
        from _: AVAudioSessionRouteDescription?,
        with _: AVAudioSession.RouteChangeReason
    ) {
        defer { isExternalAudioPlaybackDeviceConnected = observer.isExternalDeviceConnected() }

        guard
            isExternalAudioPlaybackDeviceConnected
            && !observer.isExternalDeviceConnected()
            && (state.isAny(of: [
                .loading,
                .loaded,
                .buffering,
                .waitingForNetwork,
            ]) && autoPlay)
            || state == .playing
        else { return }

        pause()
    }
}

// MARK: - AKAudioSessionMediaServicesResetObserverDelegate

extension AKPlayerManager: AKAudioSessionMediaServicesResetObserverDelegate {
    @MainActor
    public func audioSessionMediaServicesResetObserver(
        _: AKAudioSessionMediaServicesWereResetObserverProtocol,
        mediaServicesWereResetFor _: AVAudioSession
    ) {
        stop()
    }
}

// MARK: - AKApplicationLifeCycleEventsObserverDelegate

extension AKPlayerManager: AKApplicationLifeCycleEventsObserverDelegate {
    @MainActor
    public func applicationLifeCycleEventsObserver(
        _: AKApplicationLifeCycleEventsObserverProtocol,
        on event: AKApplicationLifeCycleEvent
    ) {
        switch event {
        case .willResignActive:
            if configuration.playbackPausesWhenResigningActive {
                if autoPlay
                    || state == .playing
                {
                    savePlayerStateSnapshot(
                        playbackInterruptionReason: .applicationResignActive,
                        shouldResume: true
                    )
                    pause()
                }
                execute { try self.setAudioSession(false) }

            } else {
                if !autoPlay,
                   !state.isPlaying
                {
                    savePlayerStateSnapshot(
                        playbackInterruptionReason: .applicationResignActive,
                        shouldResume: false
                    )
                    execute { try self.setAudioSession(false) }
                }
            }
        case .didBecomeActive:
            guard configuration.playbackResumesWhenBecameActive,
                  let snapshot = playerStateSnapshot,
                  snapshot.playbackInterruptionReason.isLifeCycleEvent,
                  snapshot.shouldResume
            else { return }

            play()
        case .didEnterBackground:
            if configuration.playbackPausesWhenBackgrounded {
                if autoPlay
                    || state == .playing
                {
                    savePlayerStateSnapshot(
                        playbackInterruptionReason: .applicationEnteredBackground,
                        shouldResume: true
                    )
                    pause()
                }
                execute { try self.setAudioSession(false) }

            } else {
                if !autoPlay,
                   !state.isPlaying
                {
                    savePlayerStateSnapshot(
                        playbackInterruptionReason: .applicationEnteredBackground,
                        shouldResume: false
                    )
                    execute { try self.setAudioSession(false) }
                }
            }
        case .willEnterForeground:
            guard configuration.playbackResumesWhenEnteringForeground,
                  let snapshot = playerStateSnapshot,
                  snapshot.playbackInterruptionReason.isLifeCycleEvent,
                  snapshot.shouldResume
            else { return }

            play()
        }
    }
}
