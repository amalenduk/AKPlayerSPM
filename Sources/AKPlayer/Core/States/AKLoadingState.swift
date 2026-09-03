//
//  AKLoadingState.swift
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

public class AKLoadingState: AKBaseState {
    
    // MARK: - Properties
    
    private let media: AKPlayable
    public private(set) var autoPlay: Bool
    private let position: CMTime?
    private var rate: AKPlaybackRate?
    
    private var isCancelled: Bool = false
    private var task: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()
    
    // MARK: - Init
    
    public init(playerController: AKPlayerControllerProtocol,
                media: AKPlayable,
                autoPlay: Bool = false,
                position: CMTime? = nil,
                rate: AKPlaybackRate? = nil) {
        self.media = media
        self.autoPlay = autoPlay
        self.position = position
        self.rate = rate
        super.init(playerController: playerController, state: .loading)
    }
    
    deinit {
        subscriptions.removeAll()
        task?.cancel()
    }
    
    public override func processStateChange() {
        resetPlayer()
        playerController.delegate?.playerController(playerController,
                                                    didChangeMediaTo: media)
        
        media.statePublisher
            .prepend(media.state)
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] state in
                hanldeChangeInMedia(state)
            }.store(in: &subscriptions)
    }
    
    // MARK: - Commands
    
    public override func play() {
        autoPlay = true
    }
    
    public override func play(at rate: AKPlaybackRate) {
        playerController.delegate?.playerController(playerController,
                                                    didEncounterUnavailableAction: .waitTillMediaLoaded)
    }
    
    public override func pause() {
        autoPlay = false
    }
    
    public override func togglePlayPause() {
        autoPlay ? pause() : play()
    }
    
    // MARK: - Additional Helper Functions
    
    private func hanldeChangeInMedia(_ state: AKPlayableState) {
        switch state {
        case .idle:
            createAsset()
        case .assetLoaded:
            task = Task { [weak self] in
                guard let self else { return }
                await validateAssetPlayability()
                if isCancelled { return }
                createPlayerItemFromAsset()
            }
        case .playerItemLoaded:
            playerItemLoaded()
        case .readyToPlay where !(playerController.player.currentItem == media.playerItem):
            playerItemLoaded()
        case .readyToPlay:
            becameReadyToPlay()
        case .failed:
            if let error = media.error {
                failedToPrepareForPlayback(with: error)
            }
        }
    }
    
    private func createAsset() {
        media.createAsset()
    }
    
    private func validateAssetPlayability() async {
        do {
            try await media.validateAssetPlayability()
        } catch let playerError as AKPlayerError {
            failedToPrepareForPlayback(with: playerError)
        } catch {
            // Will not call
            failedToPrepareForPlayback(with: .playerCanNoLongerPlay(error: error))
        }
    }
    
    private func createPlayerItemFromAsset() {
        media.createPlayerItemFromAsset()
    }
    
    private func playerItemLoaded() {
        /*
         You should call this method before associating the player item with the player to make
         sure you capture all state changes to the item’s status.
         */
        media.startPlayerItemReadinessObserver()
        if let item = media.playerItem {
            playerController.player.replaceCurrentItem(with: item)
        }
    }
    
    private func becameReadyToPlay() {
        playerController.player.publisher(for: \.status,
                                          options: [.initial, .new])
        .receive(on: DispatchQueue.main)
        .sink { [unowned self] status in
            switch status {
            case .readyToPlay:
                let controller = AKLoadedState(playerController: playerController,
                                               autoPlay: autoPlay,
                                               position: position)
                change(controller)
            case .failed:
                let controller = AKFailedState(playerController: playerController,
                                               error: .playerCanNoLongerPlay(error: playerController.player.error))
                change(controller)
            default: break
            }
        }.store(in: &subscriptions)
    }
    
    
    private func abortAssetInitialization() {
        task?.cancel()
        isCancelled = true
        subscriptions.removeAll()
        media.abortAssetInitialization()
    }
    
    private func stopPlayerItemObservers() {
        media.stopPlayerItemReadinessObserver()
    }
    
    private func resetPlayer() {
        if !playerController.player.timeControlStatus.isPaused {
            playerController.performPause()
        }
        stopPlayerItemObservers()
        /*
         It seems to be a good idea to reset player current item
         Fix side effect when coming from failed state
         */
        playerController.currentItem?.cancelPendingSeeks()
        playerController.player.replaceCurrentItem(with: nil)
    }
    
    // MARK: - Error Handling - Preparing Assets for Playback Failed
    
    private func failedToPrepareForPlayback(with error: AKPlayerError) {
        guard !isCancelled else { return }
        let controller = AKFailedState(playerController: playerController, error: error)
        change(controller)
    }
    
    override func beforeLoad(media: any AKPlayable, autoPlay: Bool, position: CMTime?) {
        abortAssetInitialization()
    }
    
    override func beforeStop() {
        abortAssetInitialization()
        stopPlayerItemObservers()
    }
    
    public override func availability(for action: AKPlayerAction)
    -> (allowed: Bool, reason: AKPlayerUnavailableCommandReason?) {
        switch action {
        case .seek, .step, .fastForward, .rewind:
            return (false, .waitTillMediaLoaded)
        default:
            return super.availability(for: action)
        }
    }
    
    override func beforeStateChange() {
        subscriptions.removeAll()
    }
}
