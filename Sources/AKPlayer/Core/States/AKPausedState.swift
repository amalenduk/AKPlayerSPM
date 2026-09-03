//
//  AKPausedState.swift
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

public class AKPausedState: AKBaseState {
    
    // MARK: - Properties
    
    private let playerItemDidPlayToEndTime: Bool
    
    private var subscriptions = Set<AnyCancellable>()
    
    // MARK: - Init
    
    public init(playerController: AKPlayerControllerProtocol,
                playerItemDidPlayToEndTime: Bool = false) {
        self.playerItemDidPlayToEndTime = playerItemDidPlayToEndTime
        super.init(playerController: playerController, state: .paused)
    }
    
    deinit {
        subscriptions.removeAll()
    }
    
    public override func processStateChange() {
        startObservingPlayerStatus()
        startObservingPlayerItemNotifications()
        
        if !playerController.player.timeControlStatus.isPaused {
            playerController.performPause()
        }
        
        if playerItemDidPlayToEndTime, let currentMedia = playerController.currentMedia {
            playerController.delegate?.playerController(playerController,
                                                        didReachEndAt: playerController.currentTime,
                                                        for: playerController.currentMedia!)
        }
    }
    
    // MARK: - Commands
    
    public override func play() {
        guard let currentMedia = playerController.currentMedia,
              playerController.currentMedia!.state.isReadyToPlay else {
            if let media = playerController.currentMedia {
                load(media: media, autoPlay: true)
            }
            return
        }
        
        let controller = AKBufferingState(playerController: playerController,
                                          autoPlay: true)
        if playerItemDidPlayToEndTime {
            controller.seek(to: .zero,
                            toleranceBefore: .zero,
                            toleranceAfter: .zero)
        }
        change(controller)
    }
    
    public override func play(at rate: AKPlaybackRate) {
        guard let currentMedia = playerController.currentMedia,
              playerController.currentMedia!.state.isReadyToPlay else {
            let controller = AKLoadingState(playerController: playerController,
                                            media: playerController.currentMedia!,
                                            autoPlay: true,
                                            rate: rate)
            return change(controller)
        }
        
        guard currentMedia.canPlay(at: rate) else {
            playerController.delegate?.playerController(playerController,
                                                        didEncounterUnavailableAction: .canNotPlayAtSpecifiedRate)
            return
        }
        
        let controller = AKBufferingState(playerController: playerController,
                                          autoPlay: true,
                                          rate: rate)
        if playerItemDidPlayToEndTime {
            controller.seek(to: .zero,
                            toleranceBefore: .zero,
                            toleranceAfter: .zero)
        }
        change(controller)
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
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] timeControlStatus in
                guard playerController.player.currentItem == nil else { return }
                stop()
            }.store(in: &subscriptions)
    }
    
    private func startObservingPlayerItemNotifications() {
        guard let playerItem = playerController.currentMedia?.playerItem else { return }
        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime,
                                             object: playerItem)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            guard let self,
                  let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError else { return }
            guard error is URLError else {
                let controller = AKFailedState(playerController: playerController,
                                               error: .itemFailedToPlayToEndTime)
                return change(controller)
            }
            
            let controller = AKWaitingForNetworkState(playerController: playerController,
                                                      autoPlay: true)
            change(controller)
        }
        .store(in: &subscriptions)
    }
    
    public override func availability(for action: AKPlayerAction)
    -> (allowed: Bool, reason: AKPlayerUnavailableCommandReason?) {
        switch action {
        case .pause:
            return (false, .alreadyPaused)
        default:
            return super.availability(for: action)
        }
    }
    
    public override func beforeStateChange() {
        subscriptions.removeAll()
    }
}
