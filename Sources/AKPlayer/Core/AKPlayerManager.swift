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

public class AKPlayerManager: NSObject, AKPlayerManagerProtocol {
    
    // MARK: - Properties
    
    public var player: AVPlayer {
        return playerController.player
    }
    
    public var state: AKPlayerState {
        return playerController.state
    }
    
    public var defaultRate: AKPlaybackRate {
        get { return playerController.defaultRate }
        set { playerController.defaultRate = newValue }
    }
    
    public var rate: AKPlaybackRate {
        get { return playerController.rate }
        set { playerController.rate = newValue }
    }
    
    public var currentMedia: AKPlayable? {
        return playerController.currentMedia
    }
    
    public var currentItem: AVPlayerItem? {
        return playerController.currentItem
    }
    
    public var currentItemDuration: CMTime {
        return playerController.currentItemDuration
    }
    
    public var currentTime: CMTime {
        return playerController.currentTime
    }
    
    public var remainingTime: CMTime? {
        return playerController.remainingTime
    }
    
    public var autoPlay: Bool {
        return playerController.autoPlay
    }
    
    open var isSeeking: Bool {
        return playerController.isSeeking
    }
    
    open var lastRequestedSeekPosition: AKSeekPosition? {
        return playerController.lastRequestedSeekPosition
    }
    
    public var volume: Float {
        get { return playerController.volume }
        set { playerController.volume = newValue }
    }
    
    public var isMuted: Bool {
        get { return playerController.isMuted }
        set { playerController.isMuted = newValue }
    }
    
    public var error: AKPlayerError? {
        return playerController.error
    }
    
    public let playerController: AKPlayerControllerProtocol
    
    public var configuration: AKPlayerConfigurationProtocol {
        return playerController.configuration
    }
    
    public weak var delegate: AKPlayerManagerDelegate?
    
    public private(set) var playerStateSnapshot: AKPlayerStateSnapshot?
    
    private var isExternalAudioPlaybackDeviceConnected: Bool = false
    
    public let audioSessionService: AKAudioSessionServiceProtocol
    
    public var nowPlayingSession: AKNowPlayingSession?
    
    private var audioSessionInterruptionObserver: AKAudioSessionInterruptionObserverProtocol!
    
    private var audioSessionRouteChangesObserver: AKAudioSessionRouteChangesObserverProtocol!
    
    private var audioSessionMediaServicesWereResetObserver: AKAudioSessionMediaServicesWereResetObserverProtocol!
    
    private var applicationLifeCycleEventsObserver: AKApplicationLifeCycleEventsObserverProtocol!
    
    // MARK: - Init
    
    public init(player: AVPlayer,
                configuration: AKPlayerConfigurationProtocol,
                audioSessionService: AKAudioSessionServiceProtocol) {
        self.playerController = AKPlayerController(player: player,
                                                   configuration: configuration)
        self.audioSessionService = audioSessionService
        super.init()
        
        audioSessionInterruptionObserver = AKAudioSessionInterruptionObserver(audioSession: audioSessionService.audioSession)
        audioSessionRouteChangesObserver = AKAudioSessionRouteChangesObserver(audioSession: audioSessionService.audioSession)
        audioSessionMediaServicesWereResetObserver = AKAudioSessionMediaServicesWereResetObserver(audioSession: audioSessionService.audioSession)
        applicationLifeCycleEventsObserver = AKApplicationLifeCycleEventsObserver()
        
        playerController.delegate = self
        audioSessionInterruptionObserver.delegate = self
        audioSessionRouteChangesObserver.delegate = self
        audioSessionMediaServicesWereResetObserver.delegate = self
        applicationLifeCycleEventsObserver.delegate = self
        
        setupNowPlayingSession()
    }
    
    deinit {
        nowPlayingSession = nil
        stopObservers()
        print("AKPLayerManager: Deinit called from the AKPLayerManager ✌🏼")
    }
    
    open func prepare() throws {
        try setAudioSession(true)
        try playerController.prepare()
        try setNowPlayingSessionActive()
        
        startObservers()
        isExternalAudioPlaybackDeviceConnected = audioSessionRouteChangesObserver.isExternalDeviceConnected()
    }
    
    open func setNowPlayingInfo() {
        guard configuration.isNowPlayingEnabled,
              let nowPlayingSession,
              let nowPlayableMetadata = currentNowPlayingMetadata() else { return }
        nowPlayingSession.setNowPlayingInfo(nowPlayableMetadata)
    }
    
    open func currentNowPlayingMetadata() -> AKNowPlayableMetadata? {
        guard let currentMedia = currentMedia else { return nil }
        
        return AKNowPlayableMetadata(
            staticMetadata: currentMedia.staticMetadata,
            dynamicMetadata: getNowPlayableDynamicMetadata()
        )
    }
    
    open func getNowPlayableDynamicMetadata() -> AKNowPlayableDynamicMetadataProtocol? {
        guard let currentMedia = currentMedia else { return nil }
        
        // MARK: Position & Duration
        let position = currentMedia.isLive() ? nil : (currentItem?.currentTime().isValid ?? false ? Double(currentItem!.currentTime().seconds) : nil)
        
        let duration = currentMedia.isLive() ? nil : (currentItem?.duration.isValid ?? false ? Float(currentItem!.duration.seconds) : nil)
        
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
    
    open func addBoundaryTimeObserver(for times: [CMTime]) {
        playerController.addBoundaryTimeObserver(for: times)
    }
    
    open func removeBoundaryTimeObserver() {
        playerController.removeBoundaryTimeObserver()
    }
    
    // MARK: - Commands
    
    open func load(media: AKPlayable) {
        guard canPlayInCurrentLifecycleState() else { return actionNotPermitted() }
        playerController.load(media: media)
    }
    
    open func load(media: AKPlayable,
                   autoPlay: Bool) {
        guard canPlayInCurrentLifecycleState() else { return actionNotPermitted() }
        if autoPlay {
            return performPlaybackAction {
                playerController.load(media: media,
                                      autoPlay: autoPlay)
            }
        }
        playerController.load(media: media,
                              autoPlay: autoPlay)
    }
    
    open func load(media: AKPlayable,
                   autoPlay: Bool,
                   at position: CMTime) {
        guard canPlayInCurrentLifecycleState() else { return actionNotPermitted() }
        if autoPlay {
            return performPlaybackAction {
                playerController.load(media: media,
                                      autoPlay: autoPlay,
                                      at: position)
            }
        }
        playerController.load(media: media,
                              autoPlay: autoPlay,
                              at: position)
    }
    
    open func load(media: AKPlayable,
                   autoPlay: Bool,
                   at position: Double) {
        guard canPlayInCurrentLifecycleState() else { return actionNotPermitted() }
        if autoPlay {
            return performPlaybackAction {
                playerController.load(media: media,
                                      autoPlay: autoPlay,
                                      at: position)
            }
        }
        playerController.load(media: media,
                              autoPlay: autoPlay,
                              at: position)
    }
    
    open func play() {
        guard canPlayInCurrentLifecycleState() else { return actionNotPermitted() }
        performPlaybackAction { playerController.play() }
    }
    
    open func play(at rate: AKPlaybackRate) {
        guard canPlayInCurrentLifecycleState() else { return actionNotPermitted() }
        performPlaybackAction { playerController.play(at: rate) }
    }
    
    open func pause() {
        playerController.pause()
    }
    
    open func togglePlayPause() {
        switch state {
        case .loaded where !autoPlay, .paused, .stopped, .failed:
            guard canPlayInCurrentLifecycleState() else { return actionNotPermitted() }
            performPlaybackAction { playerController.togglePlayPause() }
        default:
            playerController.togglePlayPause()
        }
    }
    
    open func stop() {
        playerStateSnapshot?.shouldResume = false
        playerController.stop()
    }
    
    open func seek(to time: CMTime,
                   toleranceBefore: CMTime,
                   toleranceAfter: CMTime,
                   completionHandler: @escaping (Bool) -> Void) {
        playerController.seek(to: time,
                              toleranceBefore: toleranceBefore,
                              toleranceAfter: toleranceAfter,
                              completionHandler: completionHandler)
    }
    
    open func seek(to time: CMTime,
                   toleranceBefore: CMTime,
                   toleranceAfter: CMTime) {
        playerController.seek(to: time,
                              toleranceBefore: toleranceBefore,
                              toleranceAfter: toleranceAfter)
    }
    
    open func seek(to time: CMTime,
                   completionHandler: @escaping (Bool) -> Void) {
        playerController.seek(to: time,
                              completionHandler: completionHandler)
    }
    
    open func seek(to time: CMTime) {
        playerController.seek(to: time)
    }
    
    open func seek(to time: Double,
                   completionHandler: @escaping (Bool) -> Void) {
        playerController.seek(to: time,
                              completionHandler: completionHandler)
    }
    
    open func seek(to time: Double) {
        playerController.seek(to: time)
    }
    
    open func seek(toOffset offset: Double) {
        playerController.seek(toOffset: offset)
    }
    
    open func seek(toOffset offset: Double,
                   completionHandler: @escaping (Bool) -> Void) {
        playerController.seek(toOffset: offset,
                              completionHandler: completionHandler)
    }
    
    open func seek(toPercentage percentage: Double,
                   completionHandler: @escaping (Bool) -> Void) {
        playerController.seek(toPercentage: percentage,
                              completionHandler: completionHandler)
    }
    
    open func seek(toPercentage percentage: Double) {
        playerController.seek(toPercentage: percentage)
    }
    
    open func step(by count: Int) {
        playerController.step(by: count)
    }
    
    open func fastForward() {
        guard canPlayInCurrentLifecycleState() else { return actionNotPermitted() }
        performPlaybackAction { [unowned self] in
            playerController.fastForward()
        }
    }
    
    open func fastForward(at rate: AKPlaybackRate) {
        guard canPlayInCurrentLifecycleState() else { return actionNotPermitted() }
        performPlaybackAction { [unowned self] in
            playerController.fastForward(at: rate)
        }
    }
    
    open func rewind() {
        guard canPlayInCurrentLifecycleState() else { return actionNotPermitted() }
        performPlaybackAction { [unowned self] in
            playerController.rewind()
        }
    }
    
    open func rewind(at rate: AKPlaybackRate) {
        guard canPlayInCurrentLifecycleState() else { return actionNotPermitted() }
        performPlaybackAction { [unowned self] in
            playerController.rewind(at: rate)
        }
    }
    
    // MARK: - Additional Helper Functions
    
    private func startObservers() {
        audioSessionInterruptionObserver.startObserving()
        audioSessionRouteChangesObserver.startObserving()
        audioSessionMediaServicesWereResetObserver.startObserving()
        applicationLifeCycleEventsObserver.startObserving()
    }
    
    private func stopObservers() {
        audioSessionInterruptionObserver.stopObserving()
        audioSessionRouteChangesObserver.stopObserving()
        audioSessionMediaServicesWereResetObserver.stopObserving()
        applicationLifeCycleEventsObserver.stopObserving()
    }
    
    private func setAudioSession(_ active: Bool) throws {
        guard active else {
            return try audioSessionService.activate(false,
                                                    options: configuration.audioSession.activeOptions)
        }
        
        try audioSessionService.setCategory(configuration.audioSession.category,
                                            mode: configuration.audioSession.mode,
                                            options: configuration.audioSession.categoryOptions)
        try audioSessionService.activate(true,
                                         options: configuration.audioSession.activeOptions)
    }
    
    private func canPlayInCurrentLifecycleState() -> Bool {
        switch applicationLifeCycleEventsObserver.state {
        case .resignActive where configuration.playbackPausesWhenResigningActive: return false
        case .background where configuration.playbackPausesWhenBackgrounded: return false
        default: return true
        }
    }
    
    private func setupNowPlayingSession() {
        guard configuration.isNowPlayingEnabled else { return }
        nowPlayingSession = AKNowPlayingSession(players: [player])
        
        let defaultConfig = AKNowPlayingCommandConfiguration()
            .add(.play).enable(.play)
            .add(.pause).enable(.pause)
            .add(.togglePlayPause).enable(.togglePlayPause)
            .add(.changePlaybackPosition).enable(.changePlaybackPosition)
            .add(.skipForward(preferredIntervals: [10])).enable(.skipForward(preferredIntervals: [10]))
            .add(.skipBackward(preferredIntervals: [15])).enable(.skipBackward(preferredIntervals: [15]))
        
        Task { @MainActor in
            self.setupNowPlayingCommandHandlers()
            await nowPlayingSession?.applyConfiguration(defaultConfig)
        }
    }
    
    private func setupNowPlayingCommandHandlers() {
        guard let session = nowPlayingSession else { return }
        
        session.setHandler(for: .play) { [weak self] _ in
            guard let self else { return .commandFailed }
            play()
            return state.isPlaying || autoPlay ? .success : .commandFailed
        }
        
        session.setHandler(for: .pause) { [weak self] _ in
            guard let self else { return .commandFailed }
            pause()
            return state.isPaused ? .success : .commandFailed
        }
        
        session.setHandler(for: .stop) { [weak self] _ in
            guard let self else { return .commandFailed }
            stop()
            return state.isStopped ? .success : .commandFailed
        }
        
        session.setHandler(for: .togglePlayPause) { [weak self] _ in
            guard let self else { return .commandFailed }
            togglePlayPause()
            return (state.isPlaying || state.isPaused || autoPlay) ? .success : .commandFailed
        }
        
        session.setHandler(for: .changePlaybackRate(supportedPlaybackRates: AKPlaybackRate.allCases.map({$0.rate as NSNumber}))) { [weak self] event in
            guard let self,
                  let currentMedia,
                  let rateEvent = event as? MPChangePlaybackRateCommandEvent,
            currentMedia.canPlay(at: AKPlaybackRate(rate: rateEvent.playbackRate)) else {
                return .commandFailed
            }
            
            play(at: AKPlaybackRate(rate: rateEvent.playbackRate))
            return .success
        }
        
        session.setHandler(for: .seekForward) { [weak self] event in
            guard let self,
                  let currentMedia,
                  let seekEvent = event as? MPSeekCommandEvent,
                  currentMedia.canPlay(at: AKPlaybackRate.fastest) else {
                return .commandFailed
            }
            
            switch seekEvent.type {
            case .beginSeeking:
                fastForward(at: AKPlaybackRate.fastest)
            case .endSeeking:
                play(at: AKPlaybackRate.normal)
            @unknown default:
                return .commandFailed
            }
            return .success
        }
        
        session.setHandler(for: .seekBackward) { [weak self] event in
            guard let self,
                  let currentMedia,
                  let seekEvent = event as? MPSeekCommandEvent,
                  currentMedia.canPlay(at: AKPlaybackRate.slowest) else {
                return .commandFailed
            }
            
            switch seekEvent.type {
            case .beginSeeking:
                rewind(at: AKPlaybackRate.slowest)
            case .endSeeking:
                play(at: AKPlaybackRate.normal)
            @unknown default:
                return .commandFailed
            }
            return .success
        }
        
        session.setHandler(for: .skipForward(preferredIntervals: [15])) { [weak self] event in
            guard let self = self,
                  let skipEvent = event as? MPSkipIntervalCommandEvent,
                  let skipCommand = skipEvent.command as? MPSkipIntervalCommand else {
                return .commandFailed
            }
            
            let skipInterval = skipCommand.preferredIntervals.first?.doubleValue ?? skipEvent.interval
            let skipTime = CMTime(seconds: skipInterval, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            let targetTime = CMTimeAdd(self.currentTime, skipTime)
            
            guard currentMedia?.canSeek(to: targetTime) ?? false else { return .commandFailed }
            
            self.seek(to: targetTime)
            return .success
        }
        
        session.setHandler(for: .skipBackward(preferredIntervals: [15])) { [weak self] event in
            guard let self = self,
                  let skipEvent = event as? MPSkipIntervalCommandEvent,
                  let skipCommand = skipEvent.command as? MPSkipIntervalCommand else {
                return .commandFailed
            }
            
            let skipInterval = skipCommand.preferredIntervals.first?.doubleValue ?? skipEvent.interval
            let skipTime = CMTime(seconds: -skipInterval, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            let targetTime = CMTimeAdd(self.currentTime, skipTime)
            
            guard currentMedia?.canSeek(to: targetTime) ?? false else { return .commandFailed }
            
            let clampedTime = targetTime.seconds < 0 ? CMTime.zero : targetTime
            self.seek(to: clampedTime)
            return .success
        }
        
        session.setHandler(for: .changePlaybackPosition) { [weak self] event in
            guard let self = self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            
            let targetTime = CMTime(seconds: positionEvent.positionTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            guard self.currentMedia?.canSeek(to: targetTime) ?? false else { return .commandFailed }
            
            self.seek(to: targetTime)
            return .success
        }
    }
    
    private func setNowPlayingSessionActive() throws {
        guard configuration.isNowPlayingEnabled,
              let nowPlayingSession,
              !nowPlayingSession.isActive else { return }
        guard nowPlayingSession.canBecomeActive() else { throw AKPlayerError.nowPlayingSessionFailure }
        Task.init { await nowPlayingSession.becomeActiveIfPossible() }
    }
    
    private func execute(block: () throws -> Void,
                         completion: (Bool) -> Void = { _ in }) {
        do {
            try block()
            return completion(true)
        } catch let error {
            delegate?.playerManager(self, didFailWith: error as! AKPlayerError)
        }
        return completion(false)
    }
    
    private func savePlayerStateSnapshot(playbackInterruptionReason: AKPlaybackInterruptionReason,
                                         shouldResume: Bool) {
        guard var snapshot = playerStateSnapshot else {
            playerStateSnapshot = AKPlayerStateSnapshot(shouldResume: shouldResume,
                                                        applicationState: applicationLifeCycleEventsObserver.state,
                                                        playbackInterruptionReason: playbackInterruptionReason)
            return
        }
        
        snapshot.applicationState = applicationLifeCycleEventsObserver.state
        
        self.playerStateSnapshot = snapshot
    }
    
    private func clearPlayerStateSnapshot() {
        playerStateSnapshot = nil
    }
    
    private func actionNotPermitted() {
        delegate?.playerManager(self,
                                didEncounterUnavailableAction: .actionNotPermitted)
    }
    
    private func performPlaybackAction(action: () -> Void) {
        guard let snapshot = playerStateSnapshot else { return action() }
        if snapshot.playbackInterruptionReason.isLifeCycleEvent
            || snapshot.applicationState.isResignActiveOrBackground {
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
}

// MARK: - AKAudioSessionInterruptionObserverDelegate

extension AKPlayerManager: AKAudioSessionInterruptionObserverDelegate {
    
    public func audioSessionInterruptionObserver(_ observer: AKAudioSessionInterruptionObserverProtocol,
                                                 didBeginInterruptionWith reason: AVAudioSession.InterruptionReason?,
                                                 for audioSession: AVAudioSession) {
        
        guard (state.isAny(of: [.loading,
                                .loaded,
                                .buffering,
                                .waitingForNetwork]) && autoPlay)
                || state == .playing else { return }
        /* Audio session automatically pauses player, if not will be paused here.
         Update the UI to indicate that playback or recording has paused when it’s interrupted. Do not deactivate the audio session. */
        savePlayerStateSnapshot(playbackInterruptionReason: .audioSessionInterruption,
                                shouldResume: true)
        pause()
    }
    
    public func audioSessionInterruptionObserver(_ observer: AKAudioSessionInterruptionObserverProtocol,
                                                 didEndInterruptionWith shouldResume: Bool,
                                                 for audioSession: AVAudioSession) {
        
        guard configuration.playbackResumesWhenAudioSessionInterruptionEnded,
              let snapshot = playerStateSnapshot,
              snapshot.playbackInterruptionReason == .audioSessionInterruption,
              snapshot.shouldResume && shouldResume else { return }
        play()
    }
}

// MARK: - AKAudioSessionInterruptionObserverDelegate

extension AKPlayerManager: AKAudioSessionRouteChangesObserverDelegate {
    
    public func audioSessionRouteChangesObserver(_ observer: AKAudioSessionRouteChangesObserverProtocol,
                                                 didChangeRouteTo currentRoute: AVAudioSessionRouteDescription,
                                                 from previousRoute: AVAudioSessionRouteDescription?,
                                                 with reason: AVAudioSession.RouteChangeReason) {
        
        defer { isExternalAudioPlaybackDeviceConnected = observer.isExternalDeviceConnected() }
        
        guard isExternalAudioPlaybackDeviceConnected
                && !observer.isExternalDeviceConnected()
                && (state.isAny(of: [.loading,
                                     .loaded,
                                     .buffering,
                                     .waitingForNetwork]) && autoPlay)
                || state == .playing else { return }
        
        pause()
    }
}

// MARK: - AKAudioSessionMediaServicesResetObserverDelegate

extension AKPlayerManager: AKAudioSessionMediaServicesResetObserverDelegate {
    
    public func audioSessionMediaServicesResetObserver(_ observer: AKAudioSessionMediaServicesWereResetObserverProtocol,
                                                       mediaServicesWereResetFor audioSession: AVAudioSession) {
        stop()
    }
}

// MARK: - AKApplicationLifeCycleEventsObserverDelegate

extension AKPlayerManager: AKApplicationLifeCycleEventsObserverDelegate {
    
    public func applicationLifeCycleEventsObserver(_ observer: AKApplicationLifeCycleEventsObserverProtocol,
                                                   on event: AKApplicationLifeCycleEvent) {
        switch event {
        case .willResignActive:
            
            if configuration.playbackPausesWhenResigningActive {
                
                if autoPlay
                    || state == .playing {
                    
                    savePlayerStateSnapshot(playbackInterruptionReason: .applicationResignActive,
                                            shouldResume: true)
                    pause()
                }
                execute { try self.setAudioSession(false) }
                
            } else {
                
                if !autoPlay
                    && !state.isPlaying {
                    
                    savePlayerStateSnapshot(playbackInterruptionReason: .applicationResignActive,
                                            shouldResume: false)
                    execute { try self.setAudioSession(false) }
                }
            }
        case .didBecomeActive:
            
            guard configuration.playbackResumesWhenBecameActive,
                  let snapshot = playerStateSnapshot,
                  snapshot.playbackInterruptionReason.isLifeCycleEvent,
                  snapshot.shouldResume else { return }
            
            play()
            
        case .didEnterBackground:
            
            if configuration.playbackPausesWhenBackgrounded {
                
                if autoPlay
                    || state == .playing {
                    
                    savePlayerStateSnapshot(playbackInterruptionReason: .applicationEnteredBackground,
                                            shouldResume: true)
                    pause()
                }
                execute { try self.setAudioSession(false) }
                
            } else {
                
                if !autoPlay
                    && !state.isPlaying {
                    
                    savePlayerStateSnapshot(playbackInterruptionReason: .applicationEnteredBackground,
                                            shouldResume: false)
                    execute { try self.setAudioSession(false) }
                }
            }
        case .willEnterForeground:
            
            guard configuration.playbackResumesWhenEnteringForeground,
                  let snapshot = playerStateSnapshot,
                  snapshot.playbackInterruptionReason.isLifeCycleEvent,
                  snapshot.shouldResume else { return }
            
            play()
        }
    }
}

// MARK: - AKPlayerControllerDelegate

extension AKPlayerManager: AKPlayerControllerDelegate {
    
    public func playerController(_ playerController: AKPlayerControllerProtocol,
                                 didChangeStateTo state: AKPlayerState) {
        setNowPlayingInfo()
        delegate?.playerManager(self,
                                didChangeStateTo: state)
    }
    
    public func playerController(_ playerController: AKPlayerControllerProtocol,
                                 didChangeMediaTo media: AKPlayable) {
        setNowPlayingInfo()
        delegate?.playerManager(self,
                                didChangeMediaTo: media)
    }
    
    public func playerController(_ playerController: AKPlayerControllerProtocol,
                                 didChangePlaybackRateTo newRate: AKPlaybackRate,
                                 from oldRate: AKPlaybackRate) {
        setNowPlayingInfo()
        delegate?.playerManager(self,
                                didChangePlaybackRateTo: newRate, from: oldRate)
    }
    
    public func playerController(_ playerController: AKPlayerControllerProtocol,
                                 didChangeCurrentTimeTo currentTime: CMTime,
                                 for media: AKPlayable) {
        // setNowPlayingInfo()
        delegate?.playerManager(self,
                                didChangeCurrentTimeTo: currentTime,
                                for: media)
    }
    
    public func playerController(_ playerController: AKPlayerControllerProtocol,
                                 didInvokeBoundaryTimeObserverAt time: CMTime,
                                 for media: AKPlayable) {
        setNowPlayingInfo()
        delegate?.playerManager(self,
                                didInvokeBoundaryTimeObserverAt: time,
                                for: currentMedia!)
    }
    
    public func playerController(_ playerController: AKPlayerControllerProtocol,
                                 didReachEndAt time: CMTime,
                                 for media: AKPlayable) {
        setNowPlayingInfo()
        delegate?.playerManager(self,
                                didReachEndAt: time,
                                for: media)
    }
    
    public func playerController(_ playerController: AKPlayerControllerProtocol,
                                 didChangeVolumeTo volume: Float) {
        setNowPlayingInfo()
        delegate?.playerManager(self,
                                didChangeVolumeTo: volume)
    }
    
    public func playerController(_ playerController: AKPlayerControllerProtocol,
                                 didChangeMutedStatusTo isMuted: Bool) {
        setNowPlayingInfo()
        delegate?.playerManager(self,
                                didChangeMutedStatusTo: isMuted)
    }
    
    public func playerController(_ playerController: AKPlayerControllerProtocol,
                                 didEncounterUnavailableAction reason: AKPlayerUnavailableCommandReason) {
        setNowPlayingInfo()
        delegate?.playerManager(self,
                                didEncounterUnavailableAction: reason)
    }
    
    public func playerController(_ playerController: AKPlayerControllerProtocol,
                                 didFailWith error: AKPlayerError) {
        setNowPlayingInfo()
        delegate?.playerManager(self,
                                didFailWith: error)
    }
}
