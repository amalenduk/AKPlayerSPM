//
//  AKLoadedState.swift
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

public class AKLoadedState: AKBaseState {
    
    // MARK: - Properties
    
    public private(set) var autoPlay: Bool
    private let position: CMTime?
    private var rate: AKPlaybackRate?
    
    private var subscriptions = Set<AnyCancellable>()
    
    // MARK: - Init
    
    public init(playerController: AKPlayerControllerProtocol,
                autoPlay: Bool = false,
                position: CMTime? = nil,
                rate: AKPlaybackRate? = nil) {
        self.autoPlay = autoPlay
        self.position = position
        self.rate = rate
        super.init(playerController: playerController, state: .loaded)
    }
    
    deinit {
        subscriptions.removeAll()
    }
    
    public override func processStateChange() {
        startObservingPlayerProperties()
        
        if let currentMedia = playerController.currentMedia {
            playerController.delegate?.playerController(playerController,
                                                        didChangeCurrentTimeTo: playerController.currentTime,
                                                        for: currentMedia)
        }
        if autoPlay {
            play()
        } else if let position = position, let currentMedia = playerController.currentMedia {
            let (flag, reason) = currentMedia.seekingThroughMedia.canSeek(to: position)
            guard flag else {
                playerController.delegate?.playerController(playerController,
                                                            didEncounterUnavailableAction: reason!)
                return
            }
            seek(to: position)
        }
    }
    
    // MARK: - Commands
    
    public override func play() {
        let controller = AKBufferingState(playerController: playerController,
                                          autoPlay: true,
                                          rate: rate)
        if let position = position { controller.seek(to: position) }
        change(controller)
    }
    
    public override func play(at rate: AKPlaybackRate) {
        guard let currentMedia = playerController.currentMedia,
              playerController.currentMedia!.canPlay(at: rate) else {
            playerController.delegate?.playerController(playerController,
                                                        didEncounterUnavailableAction: .canNotPlayAtSpecifiedRate)
            return
        }
        let controller = AKBufferingState(playerController: playerController,
                                          autoPlay: true,
                                          rate: rate)
        if let position = position { controller.seek(to: position) }
        change(controller)
    }
    
    public override func pause() {
        if autoPlay {
            autoPlay = false
        } else {
            playerController.delegate?.playerController(playerController,
                                                        didEncounterUnavailableAction: .alreadyPaused)
        }
    }
    
    // MARK: - Additional Helper Functions
    
    private func startObservingPlayerProperties() {
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
    
    public override func beforeStateChange() {
        subscriptions.removeAll()
    }
}
