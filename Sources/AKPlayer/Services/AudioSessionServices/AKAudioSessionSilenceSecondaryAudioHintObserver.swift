//
//  AKAudioSessionSilenceSecondaryAudioHintObserver.swift
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

// Ref: https://developer.apple.com/documentation/avfaudio/avaudiosession/1616622-silencesecondaryaudiohintnotific

import AVFoundation

public protocol AKAudioSessionSilenceSecondaryAudioHintObserverDelegate: AnyObject {
    func audioSessionSilenceSecondaryAudioHintObserver(_ observer: AKAudioSessionSilenceSecondaryAudioHintObserverProtocol,
                                                       silenceSecondaryAudioHintDidStartFor audioSession: AVAudioSession)
    func audioSessionSilenceSecondaryAudioHintObserver(_ observer: AKAudioSessionSilenceSecondaryAudioHintObserverProtocol,
                                                       silenceSecondaryAudioHintDidEndFor audioSession: AVAudioSession)
}

public protocol AKAudioSessionSilenceSecondaryAudioHintObserverProtocol {
    var audioSession: AVAudioSession { get }
    var delegate: AKAudioSessionSilenceSecondaryAudioHintObserverDelegate? { get set }
    
    func startObserving()
    func stopObserving()
}

open class AKAudioSessionSilenceSecondaryAudioHintObserver: AKAudioSessionSilenceSecondaryAudioHintObserverProtocol {
    
    // MARK: - Properties
    
    public let audioSession: AVAudioSession
    
    public weak var delegate: AKAudioSessionSilenceSecondaryAudioHintObserverDelegate?
    
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
                                               selector: #selector(handleSilenceSecondaryAudioHintNotification(_ :)),
                                               name: AVAudioSession.silenceSecondaryAudioHintNotification,
                                               object: audioSession)
        
        isObserving = true
    }
    
    open func stopObserving() {
        guard isObserving else { return }
        
        NotificationCenter.default.removeObserver(self,
                                                  name: AVAudioSession.silenceSecondaryAudioHintNotification,
                                                  object: audioSession)
        
        isObserving = false
    }
    
    @objc open func handleSilenceSecondaryAudioHintNotification(_ notification: Notification) {
        // Determine hint type
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt,
              let type = AVAudioSession.SilenceSecondaryAudioHintType(rawValue: typeValue),
              let delegate = delegate else { return }
        switch type {
        case .begin:
            delegate.audioSessionSilenceSecondaryAudioHintObserver(self,
                                                                   silenceSecondaryAudioHintDidStartFor: audioSession)
        case .end:
            delegate.audioSessionSilenceSecondaryAudioHintObserver(self,
                                                                   silenceSecondaryAudioHintDidEndFor: audioSession)
        @unknown default:
            assertionFailure("Required Implementation")
        }
    }
}
