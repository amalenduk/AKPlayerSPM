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

public struct AKPlaybackRateChange {
    public let previousRate: AKPlaybackRate
    public let currentRate: AKPlaybackRate
    public let reason: AVPlayer.RateDidChangeReason
}

public protocol AKPlayerRateObserverProtocol {
    var player: AVPlayer { get }
    var rateChangePublisher: AnyPublisher<AKPlaybackRateChange, Never> { get }
    
    func startObserving()
    func stopObserving()
}

open class AKPlayerRateObserver: AKPlayerRateObserverProtocol {
    
    // MARK: - Properties
    
    public let player: AVPlayer
    
    public var rateChangePublisher: AnyPublisher<AKPlaybackRateChange, Never> {
        return _rateChangePublisher.eraseToAnyPublisher()
    }
    
    private var _rateChangePublisher = PassthroughSubject<AKPlaybackRateChange, Never>()
    
    private var isObserving = false
    
    private var rateChangeObserver: NSKeyValueObservation?
    
    private var subscriptions = Set<AnyCancellable>()
    
    // Safely typed as standard optionals
    private var oldRate: AKPlaybackRate?
    
    private var newRate: AKPlaybackRate?
    
    // MARK: - Init
    
    public init(with player: AVPlayer) {
        self.player = player
    }
    
    deinit {
        stopObserving()
    }
    
    open func startObserving() {
        guard !isObserving else { return }
        
        // Populate initial baseline rate safely from the player directly
        let initialRate = AKPlaybackRate(rate: player.rate)
        self.oldRate = initialRate
        self.newRate = initialRate
        
        rateChangeObserver = player.observe(\AVPlayer.rate,
                                             options: [.old, .new],
                                             changeHandler: { [weak self] player, change in
            guard let self = self else { return }
            
            if let newValue = change.newValue {
                self.oldRate = self.newRate ?? AKPlaybackRate(rate: change.oldValue ?? player.rate)
                self.newRate = AKPlaybackRate(rate: newValue)
            }
        })
        
        NotificationCenter.default.publisher(for: AVPlayer.rateDidChangeNotification, object: player)
            .receive(on: DispatchQueue.global(qos: .background))
            .sink { [weak self] notification in
                guard let self = self else { return }
                guard let userInfo = notification.userInfo,
                      let reason = userInfo[AVPlayer.rateDidChangeReasonKey] as? AVPlayer.RateDidChangeReason else {
                    return
                }
                
                // Fallback safely to current player rate if values aren't populated yet
                let previous = self.oldRate ?? AKPlaybackRate(rate: self.player.rate)
                let current = self.newRate ?? AKPlaybackRate(rate: self.player.rate)
                
                let change = AKPlaybackRateChange(previousRate: previous,
                                                  currentRate: current,
                                                  reason: reason)
                self._rateChangePublisher.send(change)
            }
            .store(in: &subscriptions)
        
        isObserving = true
    }
    
    open func stopObserving() {
        guard isObserving else { return }
        rateChangeObserver?.invalidate()
        rateChangeObserver = nil
        subscriptions.removeAll()
        isObserving = false
    }
}
