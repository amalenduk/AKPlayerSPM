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

@MainActor
public class AKPlayer: NSObject, AKPlayerProtocol {
    
    // MARK: - Properties
    
    public var currentMedia: (any AKPlayable)? {
        return manager.currentMedia
    }
    
    public var currentItem: AVPlayerItem? {
        return manager.currentItem
    }
    
    public var currentTime: CMTime {
        return manager.currentTime
    }
    
    public var currentItemDuration: CMTime {
        return manager.currentItemDuration
    }
    
    public var remainingTime: CMTime? {
        return manager.remainingTime
    }
    
    public var autoPlay: Bool {
        return manager.autoPlay
    }
    
    public var isSeeking: Bool {
        return manager.isSeeking
    }
    
    public var lastRequestedSeekPosition: AKSeekTarget? {
        return manager.lastRequestedSeekPosition
    }
    
    public var state: AKPlayerState {
        return manager.state
    }
    
    public var defaultRate: AKPlaybackRate {
        get { return manager.defaultRate }
        set { manager.defaultRate = newValue }
    }
    
    public var rate: AKPlaybackRate {
        get { return manager.rate }
        set { manager.rate = newValue }
    }
    
    public var volume: Float {
        get { return manager.volume }
        set { manager.volume = newValue }
    }
    
    public var isMuted: Bool {
        get { return manager.isMuted }
        set { manager.isMuted = newValue }
    }
    
    public var error: AKPlayerError? {
        return manager.error
    }
    
    public var player: AVPlayer {
        return manager.player
    }
    
    public var manager: AKPlayerManagerProtocol
    
    public var nowPlayingSession: AKNowPlayingSession? {
        return manager.nowPlayingSession
    }
    
    public weak var delegate: AKPlayerDelegate?
    
    // MARK: - Init & Deinit
    
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
    
    public func prepare() throws {
        try manager.prepare()
    }
    
    public func addBoundaryTimeObserver(for times: [CMTime]) {
        manager.addBoundaryTimeObserver(for: times)
    }
    
    public func removeBoundaryTimeObserver() {
        manager.removeBoundaryTimeObserver()
    }
    
    // MARK: - Commands
    
    public func load(media: any AKPlayable, autoPlay: Bool, at position: AKSeekTarget?) {
        manager.load(
            media: media,
            autoPlay: autoPlay,
            at: position
        )
    }
    
    public func play() {
        manager.play()
    }
    
    public func play(at rate: AKPlaybackRate) {
        manager.play(at: rate)
    }
    
    public func pause() {
        manager.pause()
    }
    
    public func togglePlayPause() {
        manager.togglePlayPause()
    }
    
    public func stop() {
        manager.stop()
    }
    
    @discardableResult
    public func seek(to target: AKSeekTarget) async -> Bool {
        await manager.seek(to: target)
    }
    
    @discardableResult
    public func seek(to target: AKSeekTarget, toleranceBefore: CMTime, toleranceAfter: CMTime) async -> Bool {
        await manager.seek(to: target, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter)
    }
    
    public func seek(to target: AKSeekTarget, completionHandler: @escaping @Sendable (Bool) -> Void) {
        manager.seek(to: target, completionHandler: completionHandler)
    }
    
    public func seek(to target: AKSeekTarget, toleranceBefore: CMTime, toleranceAfter: CMTime, completionHandler: @escaping @Sendable (Bool) -> Void) {
        manager.seek(to: target, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter, completionHandler: completionHandler)
    }
    
    public func step(by count: Int) {
        manager.step(by: count)
    }
    
    public func fastForward() {
        manager.fastForward()
    }
    
    public func fastForward(at rate: AKPlaybackRate) {
        manager.fastForward(at: rate)
    }
    
    public func rewind() {
        manager.rewind()
    }
    
    public func rewind(at rate: AKPlaybackRate) {
        manager.rewind(at: rate)
    }
}

// MARK: - AKPlayerManagerDelegate

extension AKPlayer: AKPlayerManagerDelegate {
    
    public func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangeStateTo state: AKPlayerState
    ) {
        delegate?.akPlayer(self, didChangeStateTo: state)
    }
    
    public func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangeMediaTo media: any AKPlayable
    ) {
        delegate?.akPlayer(self, didChangeMediaTo: media)
    }
    
    public func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangePlaybackRateTo newRate: AKPlaybackRate,
        from oldRate: AKPlaybackRate
    ) {
        delegate?.akPlayer(self, didChangePlaybackRateTo: newRate, from: oldRate)
    }
    
    public func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangeCurrentTimeTo currentTime: CMTime,
        for media: any AKPlayable
    ) {
        delegate?.akPlayer(self, didChangeCurrentTimeTo: currentTime, for: media)
    }
    
    public func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didInvokeBoundaryTimeObserverAt time: CMTime,
        for media: any AKPlayable
    ) {
        delegate?.akPlayer(self, didInvokeBoundaryTimeObserverAt: time, for: media)
    }
    
    public func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didReachEndAt time: CMTime,
        for media: any AKPlayable
    ) {
        delegate?.akPlayer(self, didReachEndAt: time, for: media)
    }
    
    public func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangeVolumeTo volume: Float
    ) {
        delegate?.akPlayer(self, didChangeVolumeTo: volume)
    }
    
    public func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didChangeMutedStatusTo isMuted: Bool
    ) {
        delegate?.akPlayer(self, didChangeMutedStatusTo: isMuted)
    }
    
    public func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didEncounterUnavailableAction reason: AKPlayerUnavailableCommandReason
    ) {
        delegate?.akPlayer(self, didEncounterUnavailableAction: reason)
    }
    
    public func playerManager(
        _ playerManager: AKPlayerManagerProtocol,
        didFailWith error: AKPlayerError
    ) {
        delegate?.akPlayer(self, didFailWith: error)
    }
}
