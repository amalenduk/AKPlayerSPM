//
//  AKWaitingForNetworkState.swift
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

public class AKWaitingForNetworkState: AKBaseState {
    
    // MARK: - Properties
    
    private var rate: AKPlaybackRate?
    public private(set) var autoPlay: Bool = false
    private var stateToNavigateAfterBuffering: AKPlayerState?
    private var targetSeek: AKSeek?
    
    private var subscriptions: Set<AnyCancellable> = Set<AnyCancellable>()
    
    // MARK: - Init
    
    public init(playerController: AKPlayerControllerProtocol,
                autoPlay: Bool = false,
                rate: AKPlaybackRate? = nil,
                stateToNavigateAfterBuffering: AKPlayerState? = nil) {
        self.stateToNavigateAfterBuffering = stateToNavigateAfterBuffering
        self.autoPlay = autoPlay
        self.rate = rate
        super.init(playerController: playerController, state: .waitingForNetwork)
    }
    
    deinit {
        subscriptions.removeAll()
    }
    
    public override func processStateChange() {
        startObservingPlayerStatus()
        
        if !playerController.player.timeControlStatus.isPaused {
            playerController.performPause()
        }
        
        startObservingPlayerItemNotifications()
        observeNetworkChanges()
    }
    
    // MARK: - Commands
    
    public override func play() {
        if autoPlay {
            playerController.delegate?.playerController(playerController,
                                                        didEncounterUnavailableAction: .alreadyTryingToPlay)
        } else {
            self.autoPlay = true
        }
    }
    
    public override func play(at rate: AKPlaybackRate) {
        guard playerController.currentMedia!.canPlay(at: rate) else {
            playerController.delegate?.playerController(playerController,
                                                        didEncounterUnavailableAction: .canNotPlayAtSpecifiedRate)
            return
        }
        self.rate = rate
        autoPlay = true
    }
    
    public override func seek(to time: CMTime,
                              toleranceBefore: CMTime,
                              toleranceAfter: CMTime,
                              completionHandler: @escaping (Bool) -> Void) {
        targetSeek = AKSeek(position: .time(time),
                            toleranceBefore: toleranceBefore,
                            toleranceAfter: toleranceAfter,
                            completionHandler: completionHandler)
    }
    
    public override func seek(to time: CMTime,
                              toleranceBefore: CMTime,
                              toleranceAfter: CMTime) {
        targetSeek = AKSeek(position: .time(time),
                            toleranceBefore: toleranceBefore,
                            toleranceAfter: toleranceAfter)
    }
    
    public override func seek(to time: CMTime,
                              completionHandler: @escaping (Bool) -> Void) {
        targetSeek = AKSeek(position: .time(time),
                            completionHandler: completionHandler)
    }
    
    public override func seek(to time: CMTime) {
        targetSeek = AKSeek(position: .time(time))
    }
    
    public override func seek(to time: Double,
                              completionHandler: @escaping (Bool) -> Void) {
        let time = CMTime(seconds: time,
                          preferredTimescale: playerController.configuration.preferredTimeScale)
        targetSeek = AKSeek(position: .time(time),
                            completionHandler: completionHandler)
    }
    
    public override func seek(to time: Double) {
        let time = CMTime(seconds: time,
                          preferredTimescale: playerController.configuration.preferredTimeScale)
        targetSeek = AKSeek(position: .time(time))
    }
    
    public override func seek(toOffset offset: Double) {
        let time = CMTimeAdd(playerController.currentTime,
                             CMTimeMakeWithSeconds(offset, preferredTimescale: playerController.configuration.preferredTimeScale))
        seek(to: time)
    }
    
    public override func seek(toOffset offset: Double,
                              completionHandler: @escaping (Bool) -> Void) {
        let time = CMTimeAdd(playerController.currentTime,
                             CMTimeMakeWithSeconds(offset, preferredTimescale: playerController.configuration.preferredTimeScale))
        seek(to: time,
             completionHandler: completionHandler)
    }
    
    public override func seek(toPercentage percentage: Double,
                              completionHandler: @escaping (Bool) -> Void) {
        let time = CMTimeGetSeconds(playerController.currentItem!.duration) * (percentage / 100)
        seek(to: time,
             completionHandler: completionHandler)
    }
    
    public override func seek(toPercentage percentage: Double) {
        let time = CMTimeGetSeconds(playerController.currentItem!.duration) * (percentage / 100)
        seek(to: time)
    }
    
    // MARK: - Additional Helper Functions
    
    private func startObservingPlayerStatus() {
        playerController.player.publisher(for: \.status)
            .prepend(playerController.player.status)
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] status in
                guard status == .failed else { return }
                let controller = AKFailedState(playerController: playerController,
                                               error: .playerCanNoLongerPlay(error: playerController.player.error))
                change(controller)
            }.store(in: &subscriptions)
        
        playerController.player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.global(qos: .background))
            .sink { [unowned self] timeControlStatus in
                guard playerController.player.currentItem == nil else { return }
                stop()
            }.store(in: &subscriptions)
    }
    
    private func startObservingPlayerItemNotifications() {
        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime,
                                             object: playerController.currentMedia!.playerItem!)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            guard let self,
                  let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError else { return }
            guard error is URLError else {
                let controller = AKFailedState(playerController: playerController,
                                               error: .itemFailedToPlayToEndTime)
                return change(controller)
            }
            
            /*
             If playback failed for internet issue will wait till internet gets activated
             */
        }
        .store(in: &subscriptions)
    }
    
    public override func change(_ controller: AKPlayerStateControllerProtocol) {
        subscriptions.removeAll()
        playerController.change(controller)
        
        guard let seek = targetSeek,
              let bufferingState = controller as? AKBufferingState else { return }
        
        if let completionHandler = seek.completionHandler {
            switch seek.position {
            case .time(let cmTime):
                bufferingState.seek(to: cmTime,
                                    toleranceBefore: seek.toleranceBefore,
                                    toleranceAfter: seek.toleranceAfter,
                                    completionHandler: completionHandler)
            case .date(let date):
                break
            }
        } else {
            switch seek.position {
            case .time(let cmTime):
                bufferingState.seek(to: cmTime,
                                    toleranceBefore: seek.toleranceBefore,
                                    toleranceAfter: seek.toleranceAfter)
            case .date(let date):
                break
            }
        }
    }
    
    private func observeNetworkChanges() {
        observeNetworkStatus(in: &subscriptions) { [weak self] status in
            guard let self, status == .satisfied else { return }
            
            // Context is restored back into buffering
            let controller = AKBufferingState(
                playerController: self.playerController,
                autoPlay: self.autoPlay,
                rate: self.rate,
                stateToNavigateAfterBuffering: self.stateToNavigateAfterBuffering ?? .paused
            )
            self.change(controller)
        }
    }
    
    public override func availability(for action: AKPlayerAction) -> (allowed: Bool, reason: AKPlayerUnavailableCommandReason?) {
        switch action {
        case .step:
            return (false, .waitingForEstablishedNetwork)
        default:
            return super.availability(for: action)
        }
    }
}
