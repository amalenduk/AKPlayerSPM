//
//  AKPlayerPlaybackTimeObserver.swift
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

// https://developer.apple.com/documentation/avfoundation/avplayer/1390404-currenttime

import AVFoundation
import Combine

public protocol AKPlayerPlaybackTimeObserverProtocol {
    var player: AVPlayer { get }
    var periodicTimePublisher: AnyPublisher<CMTime, Never> { get }
    var boundaryTimePublisher: AnyPublisher<CMTime, Never> { get }
    
    func startObservingPeriodicTime(for interval: CMTime)
    func startObservingBoundaryTime(for times: [CMTime])
    func stopObservingPeriodicTime()
    func stopObservingBoundaryTime()
}

public class AKPlayerPlaybackTimeObserver: AKPlayerPlaybackTimeObserverProtocol {
    
    // MARK: - Properties
    
    public let player: AVPlayer
    
    public var periodicTimePublisher: AnyPublisher<CMTime, Never> {
        return _periodicTimePublisher.eraseToAnyPublisher()
    }
    
    public var boundaryTimePublisher: AnyPublisher<CMTime, Never> {
        return _boundaryTimePublisher.eraseToAnyPublisher()
    }
    
    private var _periodicTimePublisher = PassthroughSubject<CMTime, Never>()
    private var _boundaryTimePublisher = PassthroughSubject<CMTime, Never>()
    
    private var periodicTimeObserverToken : Any?
    
    private var boundaryTimeObserverToken : Any?
    
    // MARK: - Init
    
    init(with player: AVPlayer) {
        self.player = player
    }
    
    deinit {
        stopObservingPeriodicTime()
        stopObservingBoundaryTime()
    }
    
    open func startObservingPeriodicTime(for interval: CMTime) {
        stopObservingPeriodicTime()
        // Add time observer. Invoke closure on the main queue.
        periodicTimeObserverToken = player.addPeriodicTimeObserver(forInterval: interval,
                                                                   queue: .main) { [weak self] time in
            guard let self else { return }
            _periodicTimePublisher.send(time)
        }
    }
    
    open func startObservingBoundaryTime(for times: [CMTime]) {
        stopObservingBoundaryTime()
        let boundaryTimes = times.map({ NSValue(time: $0 )})
        // Add time observer. Observe boundary time changes on the main queue.
        boundaryTimeObserverToken = player.addBoundaryTimeObserver(forTimes: boundaryTimes,
                                                                   queue: .main) { [weak self] in
            guard let self else { return }
            _boundaryTimePublisher.send(player.currentTime())
        }
    }
    
    open func stopObservingPeriodicTime() {
        // If a time observer exists, remove it
        if let timeObserverToken = periodicTimeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            periodicTimeObserverToken = nil
        }
    }
    
    open func stopObservingBoundaryTime() {
        if let timeObserverToken = boundaryTimeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            boundaryTimeObserverToken = nil
        }
    }
}
