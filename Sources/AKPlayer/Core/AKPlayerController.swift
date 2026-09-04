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

@MainActor
public class AKPlayerController: AKPlayerControllerProtocol {
    
    // MARK: - Properties
    
    public private(set) var player: AVPlayer
    
    public var state: AKPlayerState {
        return controller.state
    }
    
    public var defaultRate: AKPlaybackRate {
        get { return AKPlaybackRate(rate: player.defaultRate) }
        set { player.defaultRate = newValue.rate }
    }
    
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
    
    public private(set) var currentMedia: (any AKPlayable)?
    
    public var currentItem: AVPlayerItem? {
        return player.currentItem
    }
    
    public var currentItemDuration: CMTime {
        return currentItem?.duration ?? .indefinite
    }
    
    public var currentTime: CMTime {
        player.currentTime()
    }
    
    public var remainingTime: CMTime? {
        guard currentItemDuration.isValid else { return nil }
        return CMTimeSubtract(currentItemDuration, currentTime)
    }
    
    public var autoPlay: Bool {
        return controller.autoPlay
    }
    
    public var isSeeking: Bool {
        return playerSeekingThroughMediaService.isSeeking
    }
    
    public var lastRequestedSeekPosition: AKSeekTarget? {
        return playerSeekingThroughMediaService.lastRequestedSeekTarget
    }
    
    public var volume: Float {
        get { return player.volume }
        set { player.volume = newValue }
    }
    
    public var isMuted: Bool {
        get { return player.isMuted }
        set { player.isMuted = newValue }
    }
    
    public var error: AKPlayerError? {
        return (controller as? AKFailedState)?.error
    }
    
    public private(set) var configuration: AKPlayerConfigurationProtocol
    
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
    
    public weak var delegate: AKPlayerControllerDelegate?
    
    public var playerSeekingThroughMediaService: AKPlayerSeekingThroughMediaServiceProtocol
    
    public var networkStatusMonitor: AKNetworkStatusMonitorProtocol
    
    private var playerPlaybackTimeObserver: AKPlayerPlaybackTimeObserverProtocol
    
    private var playerRateObserver: AKPlayerRateObserverProtocol
    
    private nonisolated(unsafe) var subscriptions = Set<AnyCancellable>()
    
    // MARK: - Init & Deinit
    
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
        subscriptions.removeAll()
    }
    
    public func addBoundaryTimeObserver(for times: [CMTime]) {
        playerPlaybackTimeObserver.startObservingBoundaryTime(for: times)
    }
    
    public func removeBoundaryTimeObserver() {
        playerPlaybackTimeObserver.stopObservingBoundaryTime()
    }
    
    // MARK: - Commands
    
    public func load(media: any AKPlayable, autoPlay: Bool, at position: AKSeekTarget?) {
        if !state.isAny(of: [.idle, .paused, .stopped, .failed]) {
            pause()
        }
        currentMedia = media
        controller.load(media: media, autoPlay: autoPlay, at: position)
    }
    
    public func play() {
        controller.play()
    }
    
    public func play(at rate: AKPlaybackRate) {
        controller.play(at: rate)
    }
    
    public func pause() {
        controller.pause()
    }
    
    public func togglePlayPause() {
        controller.togglePlayPause()
    }
    
    public func stop() {
        controller.stop()
    }
    
    public func seek(to target: AKSeekTarget) async -> Bool {
        await controller.seek(to: target)
    }
    
    public func seek(to target: AKSeekTarget, toleranceBefore: CMTime, toleranceAfter: CMTime) async -> Bool {
        await controller.seek(to: target, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter)
    }
    
    public func step(by count: Int) {
        controller.step(by: count)
    }
    
    public func fastForward() {
        controller.fastForward()
    }
    
    public func fastForward(at rate: AKPlaybackRate) {
        controller.fastForward(at: rate)
    }
    
    public func rewind() {
        controller.rewind()
    }
    
    public func rewind(at rate: AKPlaybackRate) {
        controller.rewind(at: rate)
    }
    
    // MARK: - Helper Functions
    
    public func prepare() throws {
        controller = AKIdleState(playerController: self)
        networkStatusMonitor.startObserving()
        startPlayerObservers()
    }
    
    public func change(_ controller: AKPlayerStateControllerProtocol) {
        self.controller = controller
    }
    
    public func processStateChange() {
        switch state {
        case .idle, .loading, .loaded, .buffering, .paused, .playing, .stopped, .waitingForNetwork, .failed:
            break
        }
    }
    
    private func startPlayerObservers() {
        playerRateObserver.startObserving()
        playerPlaybackTimeObserver.startObservingPeriodicTime(for: configuration.getPeriodicTimeInterval())
        
        playerRateObserver.rateChangePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                guard let self else { return }
                self.delegate?.playerController(self, didChangePlaybackRateTo: change.currentRate, from: change.previousRate)
            }
            .store(in: &subscriptions)
        
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
    
    private func stopPlayerObservers() {
        playerRateObserver.stopObserving()
        playerPlaybackTimeObserver.stopObservingPeriodicTime()
        playerPlaybackTimeObserver.stopObservingBoundaryTime()
    }
    
    private func unavailableCommand(reason: AKPlayerUnavailableCommandReason) {
        delegate?.playerController(self, didEncounterUnavailableAction: reason)
    }
}

// MARK: - Direct Action Implementations

extension AKPlayerController {
    
    public func performPlay() {
        player.play()
    }
    
    public func performPlay(at rate: AKPlaybackRate) {
        player.rate = rate.rate
    }
    
    public func performPause() {
        player.pause()
    }
    
    public func performStop() {
        player.pause()
        player.seek(to: .zero)
        playerSeekingThroughMediaService.cancelAll()
    }
    
    public func performSeek(to targetSeek: AKSeek) {
        playerSeekingThroughMediaService.seek(to: targetSeek)
    }
    
    public func performStep(by count: Int) {
        player.currentItem?.step(byCount: count)
    }
}
