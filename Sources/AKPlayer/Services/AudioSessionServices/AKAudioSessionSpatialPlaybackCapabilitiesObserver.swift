//
//  AKAudioSessionSpatialPlaybackCapabilitiesObserver.swift
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

public protocol AKAudioSessionSpatialPlaybackCapabilitiesObserverDelegate: AnyObject {
    func audioSessionSpatialPlaybackCapabilitiesObserver(_ observer: AKAudioSessionSpatialPlaybackCapabilitiesObserverProtocol, didChangeSpatialPlaybackCapabilitiesTo isSpatialAudioEnabled: Bool)
}

public protocol AKAudioSessionSpatialPlaybackCapabilitiesObserverProtocol {
    var audioSession: AVAudioSession { get }
    var delegate: AKAudioSessionSpatialPlaybackCapabilitiesObserverDelegate? { get set }
    
    func startObserving()
    func stopObserving()
}

open class AKAudioSessionSpatialPlaybackCapabilitiesObserver: AKAudioSessionSpatialPlaybackCapabilitiesObserverProtocol {
    
    // MARK: - Properties
    
    public let audioSession: AVAudioSession
    
    public weak var delegate: AKAudioSessionSpatialPlaybackCapabilitiesObserverDelegate?
    
    private var isObserving = false
    
    // MARK: - Init
    
    public init(audioSession: AVAudioSession) {
        self.audioSession = audioSession
    }
    
    deinit {
        stopObserving()
    }
    
    open func startObserving() {
        guard !isObserving else { return }
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleSpatialPlaybackCapabilitiesChangedNotification(_ :)),
                                               name: AVAudioSession.spatialPlaybackCapabilitiesChangedNotification,
                                               object: audioSession)
        
        isObserving = true
    }
    
    open func stopObserving() {
        guard isObserving else { return }
        
        NotificationCenter.default.removeObserver(self,
                                                  name: AVAudioSession.spatialPlaybackCapabilitiesChangedNotification,
                                                  object: audioSession)
        
        isObserving = false
    }
    
    @objc open func handleSpatialPlaybackCapabilitiesChangedNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let isSpatialAudioEnabled = userInfo[AVAudioSessionSpatialAudioEnabledKey] as? NSNumber,
              let delegate = delegate else { return }
        delegate.audioSessionSpatialPlaybackCapabilitiesObserver(self,
                                                                 didChangeSpatialPlaybackCapabilitiesTo: isSpatialAudioEnabled.boolValue)
    }
}

