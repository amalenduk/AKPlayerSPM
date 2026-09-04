//
//  AKPlayerRateObserver.swift
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

// MARK: - AKPlaybackRateChange

/// Model representing a rate change event emitted by an AVPlayer instance.
public struct AKPlaybackRateChange: Sendable {
    public let previousRate: AKPlaybackRate
    public let currentRate: AKPlaybackRate
    public let reason: AVPlayer.RateDidChangeReason
    
    public init(
        previousRate: AKPlaybackRate,
        currentRate: AKPlaybackRate,
        reason: AVPlayer.RateDidChangeReason
    ) {
        self.previousRate = previousRate
        self.currentRate = currentRate
        self.reason = reason
    }
}

// MARK: - AKPlayerRateObserverProtocol

/// Interface describing an object capable of observing rate change notifications on an AVPlayer.
@MainActor
public protocol AKPlayerRateObserverProtocol: AnyObject {
    var player: AVPlayer { get }
    var rateChangePublisher: AnyPublisher<AKPlaybackRateChange, Never> { get }
    
    func startObserving()
    func stopObserving()
}

// MARK: - AKPlayerRateObserver

/// Class responsible for tracking AVPlayer rate transitions and publishing unified change events.
@MainActor
public class AKPlayerRateObserver: AKPlayerRateObserverProtocol {
    
    // MARK: - Properties
    
    public let player: AVPlayer
    
    public var rateChangePublisher: AnyPublisher<AKPlaybackRateChange, Never> {
        _rateChangePublisher.eraseToAnyPublisher()
    }
    
    private let _rateChangePublisher = PassthroughSubject<AKPlaybackRateChange, Never>()
    
    private var isObserving = false
    private var rateChangeObserver: NSKeyValueObservation?
    
    /// Container holding reactive Combine event subscriptions.
    /// Marked `nonisolated(unsafe)` for safe disposal in `deinit`.
    private nonisolated(unsafe) var subscriptions = Set<AnyCancellable>()
    
    private var oldRate: AKPlaybackRate?
    private var newRate: AKPlaybackRate?
    
    // MARK: - Init & Deinit
    
    /// Initializes a rate observer instance bound to an AVPlayer.
    /// - Parameter player: The AVPlayer instance to monitor.
    public init(with player: AVPlayer) {
        self.player = player
    }
    
    deinit {
        rateChangeObserver?.invalidate()
        subscriptions.removeAll()
    }
    
    // MARK: - Observation Lifecycle
    
    public func startObserving() {
        guard !isObserving else { return }
        
        // Establish initial baseline rate directly from player
        let initialRate = AKPlaybackRate(rate: player.rate)
        self.oldRate = initialRate
        self.newRate = initialRate
        
        // KVO observer running synchronously on MainActor
        rateChangeObserver = player.observe(
            \.rate,
             options: [.old, .new]
        ) { [weak self] player, change in
            Task { @MainActor [weak self] in
                guard let self else { return }
                
                if let newValue = change.newValue {
                    self.oldRate = self.newRate ?? AKPlaybackRate(rate: change.oldValue ?? player.rate)
                    self.newRate = AKPlaybackRate(rate: newValue)
                }
            }
        }
        
        // Receive NotificationCenter updates on main thread to preserve UI & actor isolation
        NotificationCenter.default.publisher(for: AVPlayer.rateDidChangeNotification, object: player)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }
                guard let userInfo = notification.userInfo,
                      let reason = userInfo[AVPlayer.rateDidChangeReasonKey] as? AVPlayer.RateDidChangeReason else {
                    return
                }
                
                let previous = self.oldRate ?? AKPlaybackRate(rate: self.player.rate)
                let current = self.newRate ?? AKPlaybackRate(rate: self.player.rate)
                
                let change = AKPlaybackRateChange(
                    previousRate: previous,
                    currentRate: current,
                    reason: reason
                )
                self._rateChangePublisher.send(change)
            }
            .store(in: &subscriptions)
        
        isObserving = true
    }
    
    public func stopObserving() {
        guard isObserving else { return }
        rateChangeObserver?.invalidate()
        rateChangeObserver = nil
        subscriptions.removeAll()
        isObserving = false
    }
}
