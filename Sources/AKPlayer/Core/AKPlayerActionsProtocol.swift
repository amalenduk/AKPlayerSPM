//
//  AKPlayerActionsProtocol.swift
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

public protocol AKPlayerActionsProtocol {
    func load(media: AKPlayable)
    func load(media: AKPlayable, autoPlay: Bool)
    func load(media: AKPlayable, autoPlay: Bool, at position: CMTime)
    func load(media: AKPlayable, autoPlay: Bool, at position: Double)
    // Controlling Playback
    func play()
    func play(at rate: AKPlaybackRate)
    func pause()
    func togglePlayPause()
    func stop()
    // Seeking Through Media
    func seek(to time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime, completionHandler: @escaping (Bool) -> Void)
    func seek(to time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime)
    func seek(to time: CMTime, completionHandler: @escaping (Bool) -> Void)
    func seek(to time: CMTime)
    func seek(to time: Double, completionHandler: @escaping (Bool) -> Void)
    func seek(to time: Double)
    func seek(toOffset offset: Double)
    func seek(toOffset offset: Double, completionHandler: @escaping (Bool) -> Void)
    func seek(toPercentage percentage: Double, completionHandler: @escaping (Bool) -> Void)
    func seek(toPercentage percentage: Double)
    func step(by count: Int)
    func fastForward()
    func fastForward(at rate: AKPlaybackRate)
    func rewind()
    func rewind(at rate: AKPlaybackRate)
}
