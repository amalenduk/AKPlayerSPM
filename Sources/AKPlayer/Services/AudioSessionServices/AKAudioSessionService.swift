//
//  AKAudioSessionService.swift
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

/*
 Ref:
 https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/Introduction/Introduction.html#//apple_ref/doc/uid/TP40007875-CH1-SW1
 https://developer.apple.com/documentation/avfaudio/avaudiosession/responding_to_audio_session_interruptions
 */

import AVFoundation

public protocol AKAudioSessionServiceProtocol {
    var audioSession: AVAudioSession { get }
    
    func setCategory(_ category: AVAudioSession.Category,
                     mode: AVAudioSession.Mode,
                     options: AVAudioSession.CategoryOptions) throws
    func activate(_ active: Bool,
                  options: AVAudioSession.SetActiveOptions) throws
}

open class AKAudioSessionService: AKAudioSessionServiceProtocol {
    
    // MARK: - Properties
    
    public let audioSession: AVAudioSession
    
    // MARK: - Init
    
    public init(audioSession: AVAudioSession = AVAudioSession.sharedInstance()) {
        self.audioSession = audioSession
    }
    
    deinit {
        try? activate(false)
    }
    
    open func setCategory(_ category: AVAudioSession.Category,
                          mode: AVAudioSession.Mode = .default,
                          options: AVAudioSession.CategoryOptions = []) throws {
        do {
            try audioSession.setCategory(category,
                                         mode: mode,
                                         options: options)
        } catch let error {
            throw AKPlayerError.audioSessionFailure(reason: .failedToSetCategory(error: error))
        }
    }
    
    open func activate(_ active: Bool,
                       options: AVAudioSession.SetActiveOptions = []) throws {
        
        do {
            try audioSession.setActive(active,
                                       options: options)
        } catch let error {
            throw AKPlayerError.audioSessionFailure(reason: active 
                                                    ? .failedToActivate(error: error)
                                                    : .failedToDeactivate(error: error))
        }
    }
}
