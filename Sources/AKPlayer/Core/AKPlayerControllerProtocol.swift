//
//  AKPlayerControllerProtocol.swift
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

public protocol AKPlayerControllerDelegate: AnyObject {
    func playerController(_ playerController: AKPlayerControllerProtocol,
                          didChangeStateTo state: AKPlayerState)
    func playerController(_ playerController: AKPlayerControllerProtocol,
                          didChangeMediaTo media: AKPlayable)
    func playerController(_ playerController: AKPlayerControllerProtocol,
                          didChangePlaybackRateTo currentRate: AKPlaybackRate,
                          from previousRate: AKPlaybackRate)
    func playerController(_ playerController: AKPlayerControllerProtocol,
                          didChangeCurrentTimeTo currentTime: CMTime,
                          for media: AKPlayable)
    func playerController(_ playerController: AKPlayerControllerProtocol,
                          didInvokeBoundaryTimeObserverAt time: CMTime,
                          for media: AKPlayable)
    func playerController(_ playerController: AKPlayerControllerProtocol,
                          didReachEndAt time: CMTime,
                          for media: AKPlayable)
    func playerController(_ playerController: AKPlayerControllerProtocol,
                          didChangeVolumeTo volume: Float)
    func playerController(_ playerController: AKPlayerControllerProtocol,
                          didChangeMutedStatusTo isMuted: Bool)
    func playerController(_ playerController: AKPlayerControllerProtocol,
                          didEncounterUnavailableAction reason: AKPlayerUnavailableCommandReason)
    func playerController(_ playerController: AKPlayerControllerProtocol,
                          didFailWith error: AKPlayerError)
}

public protocol AKPlayerControllerPerforming {
    func performPlay()
    func performPlay(at rate: AKPlaybackRate)
    func performPause()
    func performStop()
    func performSeek(to targetSeek: AKSeek)
    func performStep(by count: Int)
}

public protocol AKPlayerControllerProtocol: AKPlayerProtocol, AKPlayerControllerPerforming {
    var configuration: AKPlayerConfigurationProtocol { get }
    var controller: AKPlayerStateControllerProtocol { get }
    var delegate: AKPlayerControllerDelegate? { get set }
    
    var playerSeekingThroughMediaService: AKPlayerSeekingThroughMediaServiceProtocol { get }
    var networkStatusMonitor: AKNetworkStatusMonitorProtocol { get }
    
    func prepare() throws
    func change(_ controller: AKPlayerStateControllerProtocol)
    func processStateChange()
}
