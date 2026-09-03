//
//  AKBaseState.swift
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
import Network

public enum AKPlayerAction {
    case load
    case play
    case pause
    case stop
    case seek(to: CMTime)
    case step(by: Int)
    case fastForward
    case rewind
}

open class AKBaseState: AKPlayerStateControllerProtocol {
    
    // MARK: - Properties
    
    unowned public let playerController: any AKPlayerControllerProtocol
    public let state: AKPlayerState
    
    // MARK: - Init
    
    public init(playerController: any AKPlayerControllerProtocol, state: AKPlayerState) {
        self.playerController = playerController
        self.state = state
    }
    
    deinit { }
    
    public func processStateChange() {
        // Default noop; concrete states may override
    }
    
    // MARK: - Commands (use canX checks)
    
    public func load(media: AKPlayable) {
        startLoad(media: media, autoPlay: false)
    }
    
    public func load(media: AKPlayable,
                     autoPlay: Bool) {
        startLoad(media: media, autoPlay: autoPlay)
    }
    
    public func load(media: AKPlayable,
                     autoPlay: Bool,
                     at position: CMTime) {
        startLoad(media: media, autoPlay: autoPlay, at: position)
    }
    
    public func load(media: AKPlayable,
                     autoPlay: Bool,
                     at position: Double) {
        let time = CMTime(seconds: position,
                          preferredTimescale: playerController.configuration.preferredTimeScale)
        startLoad(media: media, autoPlay: autoPlay, at: time)
    }
    
    public func play() {
        performIfAllowed(check: { [unowned self] in
            return availability(for: .play)
        }, action: { [weak self] in
            guard let s = self else { return }
            let controller = AKBufferingState(playerController: s.playerController,
                                              autoPlay: true)
            s.change(controller)
        }, blocked: { [weak self] reason in
            guard let s = self else { return }
            s.playerController.delegate?.playerController(s.playerController,
                                                          didEncounterUnavailableAction: reason)
        })
    }
    
    public func play(at rate: AKPlaybackRate) {
        performIfAllowed(check: { [unowned self] in
            return availability(for: .play)
        }, action: { [weak self] in
            guard let s = self else { return }
            let controller = AKBufferingState(playerController: s.playerController,
                                              autoPlay: true,
                                              rate: rate)
            s.change(controller)
        }, blocked: { [weak self] reason in
            guard let s = self else { return }
            s.playerController.delegate?.playerController(s.playerController,
                                                          didEncounterUnavailableAction: reason)
        })
    }
    
    public func pause() {
        performIfAllowed(check: { [unowned self] in
            return availability(for: .pause)
        }, action: { [weak self] in
            guard let s = self else { return }
            let controller = AKPausedState(playerController: s.playerController)
            s.change(controller)
        }, blocked: { [weak self] reason in
            guard let s = self else { return }
            s.playerController.delegate?.playerController(s.playerController,
                                                          didEncounterUnavailableAction: reason)
        })
    }
    
    public func togglePlayPause() {
        if state.isPlaying || autoPlay {
            pause()
        } else {
            play()
        }
    }
    
    public func stop() {
        performIfAllowed(check: { [unowned self] in
            return availability(for: .stop)
        }, action: { [weak self] in
            guard let s = self else { return }
            self?.beforeStop()
            let controller = AKStoppedState(playerController: s.playerController)
            s.change(controller)
        }, blocked: { [weak self] reason in
            guard let s = self else { return }
            s.playerController.delegate?.playerController(s.playerController,
                                                          didEncounterUnavailableAction: reason)
        })
    }
    
    public func seek(to time: CMTime,
                     toleranceBefore: CMTime,
                     toleranceAfter: CMTime,
                     completionHandler: @escaping (Bool) -> Void) {
        performIfAllowed(check: { [unowned self] in
            return availability(for: .seek(to: time))
        }, action: { [weak self] in
            guard let s = self else { completionHandler(false); return }
            let controller = AKBufferingState(playerController: s.playerController,
                                              autoPlay: s.state.isPlaying || s.autoPlay)
            controller.seek(to: time,
                            toleranceBefore: toleranceBefore,
                            toleranceAfter: toleranceAfter,
                            completionHandler: completionHandler)
            s.change(controller)
        }, blocked: { [weak self] reason in
            completionHandler(false)
            guard let s = self else { return }
            s.playerController.delegate?.playerController(s.playerController,
                                                          didEncounterUnavailableAction: reason)
        })
    }
    
    public func seek(to time: CMTime,
                     toleranceBefore: CMTime,
                     toleranceAfter: CMTime) {
        seek(to: time, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter, completionHandler: {_ in })
    }
    
    public func seek(to time: CMTime,
                     completionHandler: @escaping (Bool) -> Void) {
        performIfAllowed(check: { [unowned self] in
            return availability(for: .seek(to: time))
        }, action: { [weak self] in
            guard let s = self else { completionHandler(false); return }
            let controller = AKBufferingState(playerController: s.playerController,
                                              autoPlay: s.state.isPlaying || s.autoPlay)
            controller.seek(to: time,
                            completionHandler: completionHandler)
            s.change(controller)
        }, blocked: { [weak self] reason in
            completionHandler(false)
            guard let s = self else { return }
            s.playerController.delegate?.playerController(s.playerController,
                                                          didEncounterUnavailableAction: reason)
        })
    }
    
    public func seek(to time: CMTime) {
        performIfAllowed(check: { [unowned self] in
            return availability(for: .seek(to: time))
        }, action: { [weak self] in
            guard let s = self else { return }
            let controller = AKBufferingState(playerController: s.playerController,
                                              autoPlay: s.state.isPlaying || s.autoPlay)
            controller.seek(to: time)
            s.change(controller)
        }, blocked: { [weak self] reason in
            guard let s = self else { return }
            s.playerController.delegate?.playerController(s.playerController,
                                                          didEncounterUnavailableAction: reason)
        })
    }
    
    public func seek(to time: Double,
                     completionHandler: @escaping (Bool) -> Void) {
        seek(to: CMTime(seconds: time,
                        preferredTimescale: playerController.configuration.preferredTimeScale),
             completionHandler: completionHandler)
    }
    
    public func seek(to time: Double) {
        let time = CMTime(seconds: time,
                          preferredTimescale: playerController.configuration.preferredTimeScale)
        seek(to: time)
    }
    
    public func seek(toOffset offset: Double) {
        let time = CMTimeAdd(playerController.currentTime,
                             CMTimeMakeWithSeconds(offset, preferredTimescale: playerController.configuration.preferredTimeScale))
        seek(to: time)
    }
    
    public func seek(toOffset offset: Double,
                     completionHandler: @escaping (Bool) -> Void) {
        let time = CMTimeAdd(playerController.currentTime,
                             CMTimeMakeWithSeconds(offset, preferredTimescale: playerController.configuration.preferredTimeScale))
        seek(to: time,
             completionHandler: completionHandler)
    }
    
    public func seek(toPercentage percentage: Double,
                     completionHandler: @escaping (Bool) -> Void) {
        guard let item = playerController.currentItem, item.duration.isNumeric && item.duration > CMTime.zero else {
            completionHandler(false); return
        }
        let seconds = CMTimeGetSeconds(item.duration) * (percentage / 100.0)
        seek(to: CMTime(seconds: seconds, preferredTimescale: playerController.configuration.preferredTimeScale),
             completionHandler: completionHandler)
    }
    
    public func seek(toPercentage percentage: Double) {
        seek(toPercentage: percentage, completionHandler: { _ in })
    }
    
    public func step(by count: Int) {
        performIfAllowed(check: { [unowned self] in
            return availability(for: .step(by: count))
        }, action: { [weak self] in
            guard let s = self else { return }
            s.playerController.performStep(by: count)
        }, blocked: { [weak self] reason in
            guard let s = self else { return }
            s.playerController.delegate?.playerController(s.playerController,
                                                          didEncounterUnavailableAction: reason)
        })
    }
    
    public func fastForward() {
        play(at: playerController.configuration.fastForwardRate)
    }
    
    public func fastForward(at rate: AKPlaybackRate) {
        play(at: rate)
    }
    
    public func rewind() {
        play(at: playerController.configuration.rewindRate)
    }
    
    public func rewind(at rate: AKPlaybackRate) {
        play(at: rate)
    }
    
    // MARK: - Additional Helper Functions
    
    public func change(_ controller: AKPlayerStateControllerProtocol) {
        beforeStateChange()
        playerController.change(controller)
    }
    
    public func performIfAllowed(check: @escaping () -> (Bool, AKPlayerUnavailableCommandReason?),
                                 action: @escaping () -> Void,
                                 blocked: ((AKPlayerUnavailableCommandReason) -> Void)? = nil) {
        // controller-level preflight could be added here if needed
        let result = check()
        guard result.0 else {
            if let reason = result.1 {
                blocked?(reason)
            }
            return
        }
        action()
    }
    
    // Per-action canX hooks — override in concrete states to change behavior and return denial reason if any.
    
    public func availability(for action: AKPlayerAction)
    -> (allowed: Bool, reason: AKPlayerUnavailableCommandReason?) {
        switch action {
        case .seek(to: let time):
            guard let currentMedia = playerController.currentMedia else { return (false, .loadMediaFirst)}
            
            let (flag, reason) = currentMedia.seekingThroughMedia.canSeek(to: time)
            
            return (
                allowed: flag,
                reason: reason
            )
        case .step(by: let count):
            guard let currentMedia = playerController.currentMedia else { return (false, .loadMediaFirst)}
            let result = currentMedia.canStep(by: count)
            
            return (
                allowed: result,
                reason: result
                ? nil
                : count > 0
                ? .canNotStepForward
                : .canNotStepBackward
            )
        default:
            // canStep() default: allow, concrete state can check media.canStep(by:) if needed
            return (true, .none)
        }
    }
    
    public func observeNetworkStatus(in subscriptions: inout Set<AnyCancellable>,
                                     handler: @escaping (NWPath.Status) -> Void) {
        // Automatically skip network tracking for local files
        guard let currentMedia = playerController.currentMedia, currentMedia.isOverNetwork() else { return }
        
        playerController.networkStatusMonitor.networkStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { status in
                handler(status)
            }
            .store(in: &subscriptions)
    }
    
    private func startLoad(media: AKPlayable, autoPlay: Bool, at position: CMTime? = nil) {
        beforeLoad(media: media, autoPlay: autoPlay, position: position)
        let controller = AKLoadingState(playerController: playerController,
                                        media: media,
                                        autoPlay: autoPlay,
                                        position: position)
        change(controller)
    }
    
    // MARK: - Pre-load hook
    
    func beforeLoad(media: AKPlayable, autoPlay: Bool, position: CMTime?) { }
    func beforeStop() { }
    func beforeStateChange() { }
    func afterStateChange() { }
}
