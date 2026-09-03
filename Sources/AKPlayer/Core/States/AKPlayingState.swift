//
//  AKPlayingState.swift
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

public class AKPlayingState: AKBaseState {
    
    // MARK: - Properties
    
    private var rate: AKPlaybackRate?
    private var subscriptions = Set<AnyCancellable>()
    
    // MARK: - Init
    
    public init(playerController: AKPlayerControllerProtocol,
                rate: AKPlaybackRate? = nil) {
        self.rate = rate
        super.init(playerController: playerController, state: .playing)
    }
    
    deinit {
        subscriptions.removeAll()
    }
    
    public override func processStateChange() {
        startObservingPlayerStatus()
        startObservingPlayerItemNotifications()
        
        playerController.performPlay()
        
        guard let rate = rate,
              playerController.player.rate != rate.rate else { return }
        play(at: rate)
    }
    
    // MARK: - Commands
    
    public override func play(at rate: AKPlaybackRate) {
        guard let currentMedia = playerController.currentMedia,
              currentMedia.canPlay(at: rate) else {
            playerController.delegate?.playerController(playerController,
                                                        didEncounterUnavailableAction: .canNotPlayAtSpecifiedRate)
            return
        }
        self.rate = rate
        playerController.performPlay(at: rate)
    }
    
    public override func togglePlayPause() {
        pause()
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
            
            let controller = AKWaitingForNetworkState(playerController: playerController,
                                                      autoPlay: true,
                                                      rate: rate)
            change(controller)
        }
        .store(in: &subscriptions)
        
        NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification,
                                             object: playerController.currentMedia!.playerItem!)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            guard let self else { return }
            let controller = AKPausedState(playerController: playerController,
                                           playerItemDidPlayToEndTime: true)
            change(controller)
        }
        .store(in: &subscriptions)
        
        NotificationCenter.default.publisher(for: AVPlayerItem.playbackStalledNotification,
                                             object: playerController.currentMedia!.playerItem!)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            guard let self else { return }
            let controller = AKBufferingState(playerController: playerController,
                                              autoPlay: true,
                                              rate: rate)
            change(controller)
        }
        .store(in: &subscriptions)
    }
    
    public override func availability(for action: AKPlayerAction)
    -> (allowed: Bool, reason: AKPlayerUnavailableCommandReason?) {
        switch action {
        case .play:
            return (false, .alreadyPlaying)
        default:
            return super.availability(for: action)
        }
    }
    
    public override func beforeStateChange() {
        subscriptions.removeAll()
    }
}
