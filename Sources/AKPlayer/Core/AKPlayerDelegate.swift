//
//  AKPlayerDelegate.swift
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

public protocol AKPlayerDelegate: AnyObject {
    func akPlayer(_ player: AKPlayer,
                  didChangeStateTo state: AKPlayerState)
    func akPlayer(_ player: AKPlayer,
                  didChangeMediaTo media: AKPlayable)
    func akPlayer(_ player: AKPlayer,
                  didChangePlaybackRateTo newRate: AKPlaybackRate,
                  from oldRate: AKPlaybackRate)
    func akPlayer(_ player: AKPlayer,
                  didChangeCurrentTimeTo currentTime: CMTime,
                  for media: AKPlayable)
    func akPlayer(_ player: AKPlayer,
                  didReachEndAt time: CMTime,
                  for media: AKPlayable)
    func akPlayer(_ player: AKPlayer,
                  didInvokeBoundaryTimeObserverAt time: CMTime,
                  for media: AKPlayable)
    func akPlayer(_ player: AKPlayer,
                  didChangeVolumeTo volume: Float)
    func akPlayer(_ player: AKPlayer,
                  didChangeMutedStatusTo isMuted: Bool)
    func akPlayer(_ player: AKPlayer,
                  didEncounterUnavailableAction reason: AKPlayerUnavailableCommandReason)
    func akPlayer(_ player: AKPlayer,
                  didFailWith error: AKPlayerError)
}

public extension AKPlayerDelegate {
    func akPlayer(_ player: AKPlayer,
                  didChangeStateTo state: AKPlayerState) { }
    func akPlayer(_ player: AKPlayer,
                  didChangeMediaTo media: AKPlayable) { }
    func akPlayer(_ player: AKPlayer,
                  didChangePlaybackRateTo newRate: AKPlaybackRate,
                  from oldRate: AKPlaybackRate) { }
    func akPlayer(_ player: AKPlayer,
                  didChangeCurrentTimeTo currentTime: CMTime,
                  for media: AKPlayable) { }
    func akPlayer(_ player: AKPlayer,
                  didInvokeBoundaryTimeObserverAt time: CMTime,
                  for media: AKPlayable) { }
    func akPlayer(_ player: AKPlayer,
                  didReachEndAt time: CMTime,
                  for media: AKPlayable) { }
    func akPlayer(_ player: AKPlayer,
                  didChangeVolumeTo volume: Float) { }
    func akPlayer(_ player: AKPlayer,
                  didChangeMutedStatusTo isMuted: Bool) { }
    func akPlayer(_ player: AKPlayer,
                  didEncounterUnavailableAction reason: AKPlayerUnavailableCommandReason) { }
    func akPlayer(_ player: AKPlayer,
                  didFailWith error: AKPlayerError) { }
}
