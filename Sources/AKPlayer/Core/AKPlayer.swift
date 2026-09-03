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

open class AKPlayer: NSObject, AKPlayerProtocol {
    
    // MARK: - Properties
    
    open var currentMedia: AKPlayable? {
        return manager.currentMedia
    }
    
    open var currentItem: AVPlayerItem? {
        return manager.currentItem
    }
    
    open var currentTime: CMTime {
        return manager.currentTime
    }
    
    open var currentItemDuration: CMTime {
        return manager.currentItemDuration
    }
    
    open var remainingTime: CMTime? {
        return player.currentTime()
    }
    
    open var autoPlay: Bool {
        return manager.autoPlay
    }
    
    open var isSeeking: Bool {
        return manager.isSeeking
    }
    
    open var lastRequestedSeekPosition: AKSeekPosition? {
        return manager.lastRequestedSeekPosition
    }
    
    open var state: AKPlayerState {
        return manager.state
    }
    
    open var defaultRate: AKPlaybackRate {
        get { return manager.defaultRate }
        set { manager.defaultRate = newValue }
    }
    
    open var rate: AKPlaybackRate {
        get { return manager.rate }
        set { manager.rate = newValue }
    }
    
    open var volume: Float {
        get { return manager.volume }
        set { manager.volume = newValue }
    }
    
    open var isMuted: Bool {
        get { return manager.isMuted }
        set { manager.isMuted = newValue }
    }
    
    open var error: AKPlayerError? {
        return manager.error
    }
    
    public var player: AVPlayer {
        return manager.player
    }
    
    public var manager: AKPlayerManagerProtocol
    
    public var nowPlayingSession: AKNowPlayingSession? {
        return manager.nowPlayingSession
    }
    
    open weak var delegate: AKPlayerDelegate?
    
    // MARK: - Init
    
    public init(player: AVPlayer = AVPlayer(),
                configuration: AKPlayerConfigurationProtocol = AKPlayerConfiguration.default,
                audioSessionService: AKAudioSessionServiceProtocol = AKAudioSessionService()) {
        manager = AKPlayerManager(player: player,
                                  configuration: configuration,
                                  audioSessionService: audioSessionService)
        super.init()
        manager.delegate = self
    }
    
    deinit { }
    
    open func prepare() throws {
        try manager.prepare()
    }
    
    open func addBoundaryTimeObserver(for times: [CMTime]) {
        manager.addBoundaryTimeObserver(for: times)
    }
    
    open func removeBoundaryTimeObserver() {
        manager.removeBoundaryTimeObserver()
    }
    
    // MARK: - Commands
    
    open func load(media: AKPlayable) {
        manager.load(media: media)
    }
    
    open func load(media: AKPlayable,
                   autoPlay: Bool) {
        manager.load(media: media,
                     autoPlay: autoPlay)
    }
    
    open func load(media: AKPlayable,
                   autoPlay: Bool,
                   at position: CMTime) {
        manager.load(media: media,
                     autoPlay: autoPlay,
                     at: position)
    }
    
    open func load(media: AKPlayable,
                   autoPlay: Bool,
                   at position: Double) {
        manager.load(media: media,
                     autoPlay: autoPlay,
                     at: position)
    }
    
    open func play() {
        manager.play()
    }
    
    open func play(at rate: AKPlaybackRate) {
        manager.play(at: rate)
    }
    
    open func pause() {
        manager.pause()
    }
    
    open func togglePlayPause() {
        manager.togglePlayPause()
    }
    
    open func stop() {
        manager.stop()
    }
    
    open func seek(to time: CMTime,
                   toleranceBefore: CMTime,
                   toleranceAfter: CMTime,
                   completionHandler: @escaping (Bool) -> Void) {
        manager.seek(to: time,
                     toleranceBefore: toleranceBefore,
                     toleranceAfter: toleranceAfter,
                     completionHandler: completionHandler)
    }
    
    open func seek(to time: CMTime,
                   toleranceBefore: CMTime,
                   toleranceAfter: CMTime) {
        manager.seek(to: time,
                     toleranceBefore: toleranceBefore,
                     toleranceAfter: toleranceAfter)
    }
    
    open func seek(to time: CMTime,
                   completionHandler: @escaping (Bool) -> Void) {
        manager.seek(to: time,
                     completionHandler: completionHandler)
    }
    
    open func seek(to time: CMTime) {
        manager.seek(to: time)
    }
    
    open func seek(to time: Double,
                   completionHandler: @escaping (Bool) -> Void) {
        manager.seek(to: time,
                     completionHandler: completionHandler)
    }
    
    open func seek(to time: Double) {
        manager.seek(to: time)
    }
    
    open func seek(toOffset offset: Double) {
        manager.seek(toOffset: offset)
    }
    
    open func seek(toOffset offset: Double,
                   completionHandler: @escaping (Bool) -> Void) {
        manager.seek(toOffset: offset,
                     completionHandler: completionHandler)
    }
    
    open func seek(toPercentage percentage: Double,
                   completionHandler: @escaping (Bool) -> Void) {
        manager.seek(toPercentage: percentage,
                     completionHandler: completionHandler)
    }
    
    open func seek(toPercentage percentage: Double) {
        manager.seek(toPercentage: percentage)
    }
    
    open func step(by count: Int) {
        manager.step(by: count)
    }
    
    open func fastForward() {
        manager.fastForward()
    }
    
    open func fastForward(at rate: AKPlaybackRate) {
        manager.fastForward(at: rate)
    }
    
    open func rewind() {
        manager.rewind()
    }
    
    open func rewind(at rate: AKPlaybackRate) {
        manager.rewind(at: rate)
    }
}

// MARK: - AKPlayerManageableDelegate

extension AKPlayer: AKPlayerManagerDelegate {
    
    public func playerManager(_ playerManager: AKPlayerManagerProtocol,
                              didChangeStateTo state: AKPlayerState) {
        delegate?.akPlayer(self,
                           didChangeStateTo: state)
    }
    
    public func playerManager(_ playerManager: AKPlayerManagerProtocol,
                              didChangeMediaTo media: AKPlayable) {
        delegate?.akPlayer(self,
                           didChangeMediaTo: media)
    }
    
    public func playerManager(_ playerManager: AKPlayerManagerProtocol,
                              didChangePlaybackRateTo newRate: AKPlaybackRate,
                              from oldRate: AKPlaybackRate) {
        delegate?.akPlayer(self,
                           didChangePlaybackRateTo: newRate,
                           from: oldRate)
    }
    
    public func playerManager(_ playerManager: AKPlayerManagerProtocol,
                              didChangeCurrentTimeTo currentTime: CMTime,
                              for media: AKPlayable) {
        delegate?.akPlayer(self,
                           didChangeCurrentTimeTo: currentTime,
                           for: media)
    }
    
    public func playerManager(_ playerManager: AKPlayerManagerProtocol,
                              didInvokeBoundaryTimeObserverAt time: CMTime,
                              for media: AKPlayable) {
        delegate?.akPlayer(self,
                           didInvokeBoundaryTimeObserverAt: time,
                           for: media)
    }
    
    public func playerManager(_ playerManager: AKPlayerManagerProtocol,
                              didReachEndAt time: CMTime,
                              for media: AKPlayable) {
        delegate?.akPlayer(self,
                           didReachEndAt: time,
                           for: media)
    }
    
    public func playerManager(_ playerManager: AKPlayerManagerProtocol,
                              didChangeVolumeTo volume: Float) {
        delegate?.akPlayer(self,
                           didChangeVolumeTo: volume)
    }
    
    public func playerManager(_ playerManager: AKPlayerManagerProtocol,
                              didChangeMutedStatusTo isMuted: Bool) {
        delegate?.akPlayer(self,
                           didChangeMutedStatusTo: isMuted)
    }
    
    public func playerManager(_ playerManager: AKPlayerManagerProtocol,
                              didEncounterUnavailableAction reason: AKPlayerUnavailableCommandReason) {
        delegate?.akPlayer(self,
                           didEncounterUnavailableAction: reason)
    }
    
    public func playerManager(_ playerManager: AKPlayerManagerProtocol,
                              didFailWith error: AKPlayerError) {
        delegate?.akPlayer(self,
                           didFailWith: error)
    }
}
