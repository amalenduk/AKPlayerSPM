//
//  AKPlayerSeekingThroughMediaService.swift
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

import AVKit

public protocol AKPlayerSeekingThroughMediaServiceProtocol: AnyObject {
    var player: AVPlayer { get }
    var pendingSeeks: OrderedSet<AKSeek> { get }
    var lastRequestedSeekPosition: AKSeekPosition? { get }
    var isSeeking: Bool { get }
    
    func seek(to seek: AKSeek)
    func cancelAll()
}

open class AKPlayerSeekingThroughMediaService: AKPlayerSeekingThroughMediaServiceProtocol {
    
    // MARK: - Properties
    
    public let player: AVPlayer
    
    public private(set) var pendingSeeks = OrderedSet<AKSeek>()
    
    private var activeSeek: AKSeek?
    private var requestedSeekPosition: AKSeekPosition?
    
    open var lastRequestedSeekPosition: AKSeekPosition? {
        requestedSeekPosition
    }
    
    open var isSeeking: Bool {
        activeSeek != nil || !pendingSeeks.isEmpty
    }
    
    // MARK: - Init
    
    public init(with player: AVPlayer) {
        self.player = player
    }
    
    // MARK: - Public API
    
    open func seek(to seek: AKSeek) {
        guard player.currentItem != nil else {
            requestedSeekPosition = nil
            seek.completionHandler?(false)
            return
        }
        
        requestedSeekPosition = seek.position
        
        // Always store the newest requested seek
        pendingSeeks.insert(seek)
        
        // If no seek is actively being processed by AVPlayer, start immediately
        if activeSeek == nil {
            performNextSeek()
        }
    }

    open func cancelAll() {
        activeSeek?.completionHandler?(false)
        activeSeek = nil
        
        while let seek = pendingSeeks.first {
            pendingSeeks.removeFirst()
            seek.completionHandler?(false)
        }
        requestedSeekPosition = nil
    }
    
    // MARK: - Private Pipeline
    
    private func performNextSeek() {
        // Grab the LATEST requested seek (skip all intermediate seeks)
        guard let latestSeek = pendingSeeks.last else {
            activeSeek = nil
            requestedSeekPosition = nil
            return
        }
        
        // Cancel and notify all skipped intermediate seeks with `false`
        while let seekToCancel = pendingSeeks.first, seekToCancel != latestSeek {
            pendingSeeks.removeFirst()
            seekToCancel.completionHandler?(false)
        }
        
        // Mark the current active seek and remove from pending queue
        activeSeek = latestSeek
        pendingSeeks.remove(latestSeek)
        
        // Dispatch to AVPlayer
        enqueue(seek: latestSeek)
    }
    
    private func enqueue(seek: AKSeek) {
        let completion: (Bool) -> Void = { [weak self] finished in
            // Ensure thread safety on main thread
            if Thread.isMainThread {
                self?.handleSeekCompletion(for: seek, finished: finished)
            } else {
                DispatchQueue.main.async {
                    self?.handleSeekCompletion(for: seek, finished: finished)
                }
            }
        }
        
        switch seek.position {
        case .time(let cmTime):
            player.seek(to: cmTime,
                        toleranceBefore: seek.toleranceBefore,
                        toleranceAfter: seek.toleranceAfter,
                        completionHandler: completion)
        case .date(let date):
            player.seek(to: date, completionHandler: completion)
        }
    }
    
    private func handleSeekCompletion(for completedSeek: AKSeek, finished: Bool) {
        // Only process if this completion corresponds to our active seek
        guard activeSeek == completedSeek else { return }
        
        // Notify completion for the seek that just finished
        completedSeek.completionHandler?(finished)
        activeSeek = nil
        
        if !pendingSeeks.isEmpty {
            // New seeks arrived while AVPlayer was busy; execute the newest one
            performNextSeek()
        } else {
            // Queue is completely clean
            requestedSeekPosition = nil
        }
    }
}
