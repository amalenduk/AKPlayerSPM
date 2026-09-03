//
//  AKPlayerItemNotificationsObserver.swift
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

public protocol AKPlayerItemNotificationsObserverProtocol: AnyObject {
    var didPlayToEndTimePublisher: AnyPublisher<CMTime, Never> { get }
    var failedToPlayToEndTimePublisher: AnyPublisher<AKPlayerError, Never> { get }
    var playbackStalledPublisher: AnyPublisher<Void, Never> { get }
    var timeJumpedPublisher: AnyPublisher<Void, Never> { get }
    var mediaSelectionDidChangePublisher: AnyPublisher<Void, Never> { get }
    var recommendedTimeOffsetFromLiveDidChangePublisher: AnyPublisher<CMTime, Never> { get }
    
    func startObserving()
    func stopObserving()
}

open class AKPlayerItemNotificationsObserver: AKPlayerItemNotificationsObserverProtocol {
    
    // MARK: - Properties
    
    private let playerItemProvider: @Sendable () -> AVPlayerItem?
    
    private var playerItem: AVPlayerItem? {
        playerItemProvider()
    }
    
    private(set) public var isObserving = false
    private var subscriptions = Set<AnyCancellable>()
    
    // MARK: - Publishers
    
    private let didPlayToEndTimeSubject = PassthroughSubject<CMTime, Never>()
    private let failedToPlayToEndTimeSubject = PassthroughSubject<AKPlayerError, Never>()
    private let playbackStalledSubject = PassthroughSubject<Void, Never>()
    private let timeJumpedSubject = PassthroughSubject<Void, Never>()
    private let mediaSelectionDidChangeSubject = PassthroughSubject<Void, Never>()
    private let recommendedTimeOffsetFromLiveDidChangeSubject = PassthroughSubject<CMTime, Never>()
    
    public var didPlayToEndTimePublisher: AnyPublisher<CMTime, Never> { didPlayToEndTimeSubject.eraseToAnyPublisher() }
    public var failedToPlayToEndTimePublisher: AnyPublisher<AKPlayerError, Never> { failedToPlayToEndTimeSubject.eraseToAnyPublisher() }
    public var playbackStalledPublisher: AnyPublisher<Void, Never> { playbackStalledSubject.eraseToAnyPublisher() }
    public var timeJumpedPublisher: AnyPublisher<Void, Never> { timeJumpedSubject.eraseToAnyPublisher() }
    public var mediaSelectionDidChangePublisher: AnyPublisher<Void, Never> { mediaSelectionDidChangeSubject.eraseToAnyPublisher() }
    public var recommendedTimeOffsetFromLiveDidChangePublisher: AnyPublisher<CMTime, Never> { recommendedTimeOffsetFromLiveDidChangeSubject.eraseToAnyPublisher() }
    
    // MARK: - Init & Deinit
    
    public init(playerItemProvider: @escaping @Sendable () -> AVPlayerItem?) {
        self.playerItemProvider = playerItemProvider
    }
    
    deinit {
        stopObserving()
    }
    
    // MARK: - Observation Lifecycle
    
    open func startObserving() {
        guard !isObserving else { return }
        
        // Safely extract the item instance at observation start
        guard let currentItem = playerItem else { return }
        isObserving = true
        
        /* Did Play To End Time */
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: currentItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak currentItem] _ in
                guard let self = self, let item = currentItem else { return }
                self.didPlayToEndTimeSubject.send(item.currentTime())
            }
            .store(in: &subscriptions)
        
        /* Failed To Play To End Time */
        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: currentItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError else { return }
                self.failedToPlayToEndTimeSubject.send(.playerItemFailedToPlay(reason: .failedToPlayToEndTime(error: error)))
            }
            .store(in: &subscriptions)
        
        /* Playback Stalled */
        NotificationCenter.default.publisher(for: .AVPlayerItemPlaybackStalled, object: currentItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.playbackStalledSubject.send()
            }
            .store(in: &subscriptions)
        
        /* Time Jumped */
        NotificationCenter.default.publisher(for: AVPlayerItem.timeJumpedNotification, object: currentItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.timeJumpedSubject.send()
            }
            .store(in: &subscriptions)
        
        /* Media Selection Changed */
        NotificationCenter.default.publisher(for: AVPlayerItem.mediaSelectionDidChangeNotification, object: currentItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.mediaSelectionDidChangeSubject.send()
            }
            .store(in: &subscriptions)
        
        /* Recommended Time Offset From Live */
        NotificationCenter.default.publisher(for: AVPlayerItem.recommendedTimeOffsetFromLiveDidChangeNotification, object: currentItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak currentItem] _ in
                guard let self = self, let item = currentItem else { return }
                self.recommendedTimeOffsetFromLiveDidChangeSubject.send(item.recommendedTimeOffsetFromLive)
            }
            .store(in: &subscriptions)
    }
    
    open func stopObserving() {
        guard isObserving else { return }
        subscriptions.removeAll()
        isObserving = false
    }
}
