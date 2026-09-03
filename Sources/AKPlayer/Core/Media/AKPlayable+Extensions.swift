//
//  AKPlayable+Extensions.swift
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
import MediaPlayer
import Combine

private var managerKey: Void?

public extension AKPlayable {
    
    var manager: AKMediaManagerProtocol {
        if let existingManager = objc_getAssociatedObject(self, &managerKey) as? AKMediaManagerProtocol {
            return existingManager
        }
        let newManager = AKMediaManager(media: self)
        setRetainedAssociatedObject(self, &managerKey, newManager)
        return newManager
    }
    
    var statePublisher: AnyPublisher<AKPlayableState, Never> {
        return manager.statePublisher
    }
    
    @discardableResult
    func observe<Value>(
        _ keyPath: KeyPath<AVPlayerItem, Value>,
        options: NSKeyValueObservingOptions = [.initial, .new],
        action: @escaping (AKMediaManagerProtocol, Value) -> Void
    ) -> AnyCancellable? {
        // Ensure AKPlayable has access to its mediaManager or playerItem
        guard let mediaManager = manager as? AKMediaManager,
              let item = mediaManager.playerItem else { return nil }
        
        return item.publisher(for: keyPath, options: options)
            .sink { [weak mediaManager] value in
                Task { @MainActor [weak mediaManager] in
                    guard let mediaManager = mediaManager else { return }
                    action(mediaManager, value)
                }
            }
    }
}

// MARK: - Direct Delegation via Manager

public extension AKPlayable {
    
    var playerItem: AVPlayerItem? {
        get { return manager.playerItem }
    }
    
    var state: AKPlayableState {
        get { return manager.state }
    }
    
    var error: AKPlayerError? {
        get { return manager.error }
    }
}

public extension AKPlayable {
    
    func createAsset() {
        manager.createAsset()
    }
    
    func validateAssetPlayability() async throws {
        try await manager.validateAssetPlayability()
    }
    
    func createPlayerItemFromAsset() {
        manager.createPlayerItemFromAsset()
    }
    
    func abortAssetInitialization() {
        manager.abortAssetInitialization()
    }
    
    func startPlayerItemReadinessObserver() {
        manager.startPlayerItemReadinessObserver()
    }
    
    func stopPlayerItemReadinessObserver() {
        manager.stopPlayerItemReadinessObserver()
    }
}

public extension AKPlayable {
    
    func canStep(by count: Int) -> Bool {
        return manager.canStep(by: count)
    }
    
    func canPlay(at rate: AKPlaybackRate) -> Bool {
        return manager.canPlay(at: rate)
    }
    
    func canSeek(to time: CMTime) -> Bool {
        return manager.canSeek(to: time)
    }
}

public extension AKPlayable {
    
    var trackSelection: AKTrackSelectionServiceProtocol {
        return manager.trackSelectionService
    }
    
    var seekingThroughMedia: AKSeekingThroughMediaServiceProtocol {
        return manager.seekingThroughMediaService
    }
    
    var playerItemNotifications: AKPlayerItemNotificationsObserver {
        return manager.playerItemNotificationsObserver
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
