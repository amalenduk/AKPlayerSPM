//
//  AKMediaManager.swift
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

open class AKMediaManager: NSObject, AKMediaManagerProtocol {
    
    // MARK: - Properties
    
    public private(set) weak var media: AKPlayable?
    
    public var asset: AVURLAsset? {
        return playerItemInitService.asset
    }
    
    public var playerItem: AVPlayerItem? {
        return playerItemInitService.playerItem
    }
    
    public var error: AKPlayerError?
    
    public private(set) var state: AKPlayableState = .idle {
        didSet {
            stateSubject.send(state)
        }
    }
    
    public var statePublisher: AnyPublisher<AKPlayableState, Never> {
        return stateSubject.eraseToAnyPublisher()
    }
    
    private let stateSubject = PassthroughSubject<AKPlayableState, Never>()
    
    private var playerItemInitService: AKPlayerItemInitServiceProtocol
    
    private var _seekingThroughMediaService: AKSeekingThroughMediaServiceProtocol!
    private var _trackSelectionService: AKTrackSelectionServiceProtocol!
    private var _playerItemNotificationsObserver: AKPlayerItemNotificationsObserver!
    
    public var seekingThroughMediaService: AKSeekingThroughMediaServiceProtocol {
        _seekingThroughMediaService
    }
    public var trackSelectionService: AKTrackSelectionServiceProtocol {
        _trackSelectionService
    }
    public var playerItemNotificationsObserver: AKPlayerItemNotificationsObserver {
        _playerItemNotificationsObserver
    }
    
    // Distinct subscription sets so lifecycle calls don't clear each other
    private var readinessSubscriptions = Set<AnyCancellable>()
    private var assetKeySubscriptions = Set<AnyCancellable>()
    
    // MARK: - Init & Deinit
    
    public init(media: AKPlayable) {
        self.media = media
        self.playerItemInitService = AKPlayerItemInitService(with: media)
        super.init()
        
        self._seekingThroughMediaService = AKSeekingThroughMediaService { [weak self] in
            return self?.playerItem
        }
        self._trackSelectionService = AKTrackSelectionService { [weak self] in
            return self?.playerItem
        }
        self._playerItemNotificationsObserver = AKPlayerItemNotificationsObserver { [weak self] in
            return self?.playerItem
        }
    }
    
    deinit {
        stopPlayerItemReadinessObserver()
        stopPlayerItemAssetKeysObserver()
        print("Deinit called from AKMediaManager 👌🏼")
    }
    
    open func createAsset() {
        assert(state.isIdle || state.isFailed,
               "This function can only be called if the media is idle or has encountered an error.")
        self.error = nil
        playerItemInitService.createAsset()
        state = .assetLoaded
    }
    
    open func validateAssetPlayability() async throws {
        assert(state.isAssetLoaded,
               "This function requires the asset to be loaded first.")
        try await playerItemInitService.validateAssetPlayability()
    }
    
    open func createPlayerItemFromAsset() {
        assert(state.isAssetLoaded,
               "This function requires the asset to be loaded first.")
        self.error = nil
        playerItemInitService.createPlayerItemFromAsset()
        
        Task {
            await _trackSelectionService.resetSession()
        }
        state = .playerItemLoaded
    }
    
    open func abortAssetInitialization() {
        playerItemInitService.abortAssetInitialization()
    }
    
    open func startPlayerItemReadinessObserver() {
        assert(state.isPlayerItemLoaded || state.isReadyToPlay,
               "Cannot start readiness observer before player item is loaded.")
        
        guard let playerItem else { return }
        stopPlayerItemReadinessObserver()
        
        playerItem.publisher(for: \.status,
                             options: [.initial,
                                       .new])
        .receive(on: DispatchQueue.main)
        .sink { [unowned self] status in
            switch status {
            case .readyToPlay:
                state = .readyToPlay
            case .failed:
                self.error = .playerItemLoadingFailed(reason: .statusLoadingFailed(error: playerItem.error!))
                state = .failed
            default: break
            }
        }
        .store(in: &readinessSubscriptions)
    }
    
    open func stopPlayerItemReadinessObserver() {
        readinessSubscriptions.removeAll()
    }
    
    open func stopPlayerItemAssetKeysObserver() {
        assetKeySubscriptions.removeAll()
    }
    
    open func canStep(by count: Int) -> Bool {
        guard state.isPlayerItemLoaded || state.isReadyToPlay else { return false }
        var isForward: Bool { return count.signum() == 1 }
        return isForward ? playerItem!.canStepForward : playerItem!.canStepBackward
    }
    
    open func canPlay(at rate: AKPlaybackRate) -> Bool {
        guard state.isPlayerItemLoaded || state.isReadyToPlay else { return false }
        guard let playerItem else { return false }
        
        switch rate.rate {
        case 0.0...:
            switch rate.rate {
            case 2.0...:
                return playerItem.canPlayFastForward
            case 1.0..<2.0:
                return true
            case 0.0..<1.0:
                return playerItem.canPlaySlowForward
            default:
                return false
            }
        case ..<0.0:
            switch rate.rate {
            case -1.0:
                return playerItem.canPlayReverse
            case -1.0..<0.0:
                return playerItem.canPlaySlowReverse
            case ..<(-1.0):
                return playerItem.canPlayFastReverse
            default:
                return false
            }
        default:
            return false
        }
    }
    
    open func canSeek(to time: CMTime) -> Bool {
        guard state.isPlayerItemLoaded || state.isReadyToPlay else { return false }
        return seekingThroughMediaService.canSeek(to: time)
    }
    
    open func canSeek(to time: CMTime) -> (flag: Bool,
                                           reason: AKPlayerUnavailableCommandReason?) {
        guard state.isPlayerItemLoaded || state.isReadyToPlay else {
            if state.isIdle || state.isFailed {
                return (false, .loadMediaFirst)
            } else {
                return (false, .waitTillMediaLoaded)
            }
        }
        return seekingThroughMediaService.canSeek(to: time)
    }
}
