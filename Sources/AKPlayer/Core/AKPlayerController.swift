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

open class AKPlayerController: AKPlayerControllerProtocol {
    
    // MARK: - Properties
    
    open private(set) var player: AVPlayer
    
    open var state: AKPlayerState { return controller.state }
    
    open var defaultRate: AKPlaybackRate {
        get { return AKPlaybackRate(rate: player.defaultRate) }
        set { player.defaultRate = newValue.rate }
    }
    
    open var rate: AKPlaybackRate {
        get { return AKPlaybackRate(rate: player.rate) }
        set {
            if newValue.rate == 0 { pause() }
            else { play(at: newValue) }
        }
    }
    
    open private(set) var currentMedia: AKPlayable?
    
    open var currentItem: AVPlayerItem? { return player.currentItem }
    
    open var currentItemDuration: CMTime { return currentItem?.duration ?? .indefinite }
    
    open var currentTime: CMTime { player.currentTime() }
    
    open var remainingTime: CMTime? {
        guard currentItemDuration.isValid else { return nil }
        return CMTimeSubtract(currentItemDuration, currentTime)
    }
    
    open var autoPlay: Bool {
        return controller.autoPlay
    }
    
    open var isSeeking: Bool {
        return playerSeekingThroughMediaService.isSeeking
    }
    
    open var lastRequestedSeekPosition: AKSeekPosition? {
        return playerSeekingThroughMediaService.lastRequestedSeekPosition
    }
    
    open var volume: Float {
        get { return player.volume }
        set { player.volume = newValue }
    }
    
    open var isMuted: Bool {
        get { return player.isMuted }
        set { player.isMuted = newValue }
    }
    
    open var error: AKPlayerError? { return (controller as? AKFailedState)?.error }
    
    public private(set) var configuration: AKPlayerConfigurationProtocol
    
    open private(set) var controller: AKPlayerStateControllerProtocol {
        get { return _controller ?? AKIdleState(playerController: self) }
        set {
            _controller = newValue
            newValue.processStateChange()
            processStateChange()
            delegate?.playerController(self, didChangeStateTo: newValue.state)
        }
    }
    
    private var _controller: AKPlayerStateControllerProtocol?
    
    open weak var delegate: AKPlayerControllerDelegate?
    
    public var playerSeekingThroughMediaService: AKPlayerSeekingThroughMediaServiceProtocol
    
    public var networkStatusMonitor: AKNetworkStatusMonitorProtocol
    
    private var playerPlaybackTimeObserver: AKPlayerPlaybackTimeObserverProtocol
    
    private var playerRateObserver: AKPlayerRateObserverProtocol
    
    private var subscriptions : Set<AnyCancellable> = Set<AnyCancellable>()
    
    // MARK: - Init
    
    public init(player: AVPlayer,
                configuration: AKPlayerConfigurationProtocol) {
        self.player = player
        self.configuration = configuration
        
        playerRateObserver = AKPlayerRateObserver(with: player)
        playerPlaybackTimeObserver = AKPlayerPlaybackTimeObserver(with: player)
        playerSeekingThroughMediaService = AKPlayerSeekingThroughMediaService(with: player)
        networkStatusMonitor = AKNetworkStatusMonitor()
    }
    
    deinit {
        print("AKPlayerController: Deinit called from the AKPlayerController ✌🏼")
        stopPlayerObservers()
        networkStatusMonitor.stopObserving()
    }
    
    open func addBoundaryTimeObserver(for times: [CMTime]) {
        playerPlaybackTimeObserver.startObservingBoundaryTime(for: times)
    }
    
    open func removeBoundaryTimeObserver() {
        playerPlaybackTimeObserver.stopObservingPeriodicTime()
    }
    
    // MARK: - Commands
    
    open func load(media: AKPlayable) {
        if !state.isAny(of: [.idle,
                             .paused,
                             .stopped,
                             .failed]) {
            pause()
        }
        currentMedia = media
        controller.load(media: media)
    }
    
    open func load(media: AKPlayable,
                   autoPlay: Bool) {
        if !state.isAny(of: [.idle,
                             .paused,
                             .stopped,
                             .failed]) {
            pause()
        }
        currentMedia = media
        controller.load(media: media,
                        autoPlay: autoPlay)
    }
    
    open func load(media: AKPlayable,
                   autoPlay: Bool,
                   at position: CMTime) {
        if !state.isAny(of: [.idle,
                             .paused,
                             .stopped,
                             .failed]) {
            pause()
        }
        currentMedia = media
        controller.load(media: media,
                        autoPlay: autoPlay,
                        at: position)
    }
    
    open func load(media: AKPlayable,
                   autoPlay: Bool,
                   at position: Double) {
        if !state.isAny(of: [.idle,
                             .paused,
                             .stopped,
                             .failed]) {
            pause()
        }
        currentMedia = media
        controller.load(media: media,
                        autoPlay: autoPlay,
                        at: position)
    }
    
    open func play() {
        controller.play()
    }
    
    open func play(at rate: AKPlaybackRate) {
        controller.play(at: rate)
    }
    
    open func pause() {
        controller.pause()
    }
    
    open func togglePlayPause() {
        controller.togglePlayPause()
    }
    
    open func stop() {
        controller.stop()
    }
    
    open func seek(to time: CMTime,
                   toleranceBefore: CMTime,
                   toleranceAfter: CMTime,
                   completionHandler: @escaping (Bool) -> Void) {
        controller.seek(to: time,
                        toleranceBefore: toleranceBefore,
                        toleranceAfter: toleranceAfter,
                        completionHandler: completionHandler)
    }
    
    open func seek(to time: CMTime,
                   toleranceBefore: CMTime,
                   toleranceAfter: CMTime) {
        controller.seek(to: time,
                        toleranceBefore: toleranceBefore,
                        toleranceAfter: toleranceAfter)
    }
    
    open func seek(to time: CMTime,
                   completionHandler: @escaping (Bool) -> Void) {
        controller.seek(to: time,
                        completionHandler: completionHandler)
    }
    
    open func seek(to time: CMTime) {
        controller.seek(to: time)
    }
    
    open func seek(to time: Double,
                   completionHandler: @escaping (Bool) -> Void) {
        controller.seek(to: time,
                        completionHandler: completionHandler)
    }
    
    open func seek(to time: Double) {
        controller.seek(to: time)
    }
    
    open func seek(toOffset offset: Double) {
        controller.seek(toOffset: offset)
    }
    
    open func seek(toOffset offset: Double,
                   completionHandler: @escaping (Bool) -> Void) {
        controller.seek(toOffset: offset,
                        completionHandler: completionHandler)
    }
    
    open func seek(toPercentage percentage: Double,
                   completionHandler: @escaping (Bool) -> Void) {
        controller.seek(toPercentage: percentage,
                        completionHandler: completionHandler)
    }
    
    open func seek(toPercentage percentage: Double) {
        controller.seek(toPercentage: percentage)
    }
    
    open func step(by count: Int) {
        controller.step(by: count)
    }
    
    open func fastForward() {
        controller.fastForward()
    }
    
    open func fastForward(at rate: AKPlaybackRate) {
        controller.fastForward(at: rate)
    }
    
    open func rewind() {
        controller.rewind()
    }
    
    open func rewind(at rate: AKPlaybackRate) {
        controller.rewind(at: rate)
    }
    
    // MARK: - Additional Helper Functions
    
    open func prepare() throws {
        controller = AKIdleState(playerController: self)
        networkStatusMonitor.startObserving()
        startPlayerObservers()
    }
    
    open func change(_ controller: AKPlayerStateControllerProtocol) {
        self.controller = controller
    }
    
    open func processStateChange() {
        switch state {
        case .idle:
            break
        case .loading:
            break
        case .loaded:
            break
        case .buffering:
            break
        case .paused:
            break
        case .playing:
            break
        case .stopped:
            break
        case .waitingForNetwork:
            break
        case .failed:
            break
        }
    }
    
    private func startPlayerObservers() {
        playerRateObserver.startObserving()
        playerPlaybackTimeObserver.startObservingPeriodicTime(for: configuration.getPeriodicTimeInterval())
        
        playerRateObserver.rateChangePublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] change in
                delegate?.playerController(self,
                                           didChangePlaybackRateTo: change.currentRate,
                                           from: change.previousRate)
            }
            .store(in: &subscriptions)
        
        player.publisher(for: \.volume)
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] volume in
                delegate?.playerController(self,
                                           didChangeVolumeTo: volume)
            }
            .store(in: &subscriptions)
        
        player.publisher(for: \.isMuted)
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] isMuted in
                delegate?.playerController(self,
                                           didChangeMutedStatusTo: isMuted)
            }
            .store(in: &subscriptions)
        
        playerPlaybackTimeObserver.periodicTimePublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] time in
                delegate?.playerController(self,
                                           didChangeCurrentTimeTo: time,
                                           for: currentMedia!)
            }
            .store(in: &subscriptions)
        
        playerPlaybackTimeObserver.boundaryTimePublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] time in
                delegate?.playerController(self,
                                           didInvokeBoundaryTimeObserverAt: time,
                                           for: currentMedia!)
            }
            .store(in: &subscriptions)
    }
    
    private func stopPlayerObservers() {
        playerRateObserver.stopObserving()
        playerPlaybackTimeObserver.stopObservingPeriodicTime()
        playerPlaybackTimeObserver.stopObservingBoundaryTime()
    }
    
    private func unaivalableCommand(reason: AKPlayerUnavailableCommandReason) {
        delegate?.playerController(self, didEncounterUnavailableAction: reason)
    }
}

extension AKPlayerController {
    public func performPlay() {
        // Directly control AVPlayer and update controller internals.
        // IMPORTANT: do NOT call `self.play()` (public) here — that would re-enter state routing.
        DispatchQueue.main.async { // ensure AVPlayer/UI updates happen on main as needed
            self.player.play()
        }
    }
    
    public func performPlay(at rate: AKPlaybackRate) {
        DispatchQueue.main.async {
            self.player.rate = rate.rate
        }
    }
    
    public func performPause() {
        DispatchQueue.main.async {
            self.player.pause()
        }
    }
    
    public func performStop() {
        DispatchQueue.main.async {
            self.player.pause()
            self.player.seek(to: .zero)
            self.playerSeekingThroughMediaService.cancelAll()
        }
    }
    
    public func performSeek(to targetSeek: AKSeek) {
        DispatchQueue.main.async {
            self.playerSeekingThroughMediaService.seek(to: targetSeek)
        }
    }
    
    public func performStep(by count: Int) {
        DispatchQueue.main.async {
            self.player.currentItem?.step(byCount: count)
        }
    }
}
