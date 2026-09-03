//
//  AKSeekingThroughMediaService.swift
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

import AVFoundation

public protocol AKSeekingThroughMediaServiceProtocol: Sendable {
    func canSeek(to time: CMTime) -> Bool
    func canSeek(to time: CMTime) -> (flag: Bool, reason: AKPlayerUnavailableCommandReason?)
    func isTimeInRanges(_ time: CMTime, _ ranges: [CMTimeRange]) -> Bool
    func getRangesAvailable() -> [CMTimeRange]
}

public final class AKSeekingThroughMediaService: AKSeekingThroughMediaServiceProtocol {
    
    // MARK: - Properties
    
    private let playerItemProvider: @Sendable () -> AVPlayerItem?
    
    private var playerItem: AVPlayerItem? {
        playerItemProvider()
    }
    
    // MARK: - Init & Deinit
    
    public init(playerItemProvider: @escaping @Sendable () -> AVPlayerItem?) {
        self.playerItemProvider = playerItemProvider
    }
    
    // MARK: - Public API
    
    public func canSeek(to time: CMTime) -> Bool {
        guard let playerItem = playerItem else { return false }
        
        guard time.isValid && time.isNumeric && CMTimeGetSeconds(time) >= 0 else {
            return false
        }
        
        let duration = CMTimeGetSeconds(playerItem.duration)
        guard duration.isNormal else {
            let ranges = getRangesAvailable()
            return isTimeInRanges(time, ranges)
        }
        
        return CMTimeGetSeconds(time) < duration
    }
    
    public func canSeek(to time: CMTime) -> (flag: Bool, reason: AKPlayerUnavailableCommandReason?) {
        guard let playerItem = playerItem else {
            return (false, .waitTillMediaLoaded)
        }
        
        guard time.isValid && time.isNumeric && CMTimeGetSeconds(time) >= 0 else {
            return (false, .seekPositionNotAvailable)
        }
        
        let duration = CMTimeGetSeconds(playerItem.duration)
        guard duration.isNormal else {
            let ranges = getRangesAvailable()
            return isTimeInRanges(time, ranges) ? (true, nil) : (false, .seekPositionNotAvailable)
        }
        
        guard CMTimeGetSeconds(time) < duration else {
            return (false, .seekOverstepPosition)
        }
        
        return (true, nil)
    }
    
    public func isTimeInRanges(_ time: CMTime, _ ranges: [CMTimeRange]) -> Bool {
        return ranges.contains { $0.containsTime(time) }
    }
    
    public func getRangesAvailable() -> [CMTimeRange] {
        guard let playerItem = playerItem else { return [] }
        let ranges = playerItem.seekableTimeRanges + playerItem.loadedTimeRanges
        return ranges.map { $0.timeRangeValue }
    }
}
