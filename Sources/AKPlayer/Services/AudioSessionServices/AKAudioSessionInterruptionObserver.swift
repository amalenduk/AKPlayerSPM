//
//  AKAudioSessionInterruptionObserver.swift
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
 https://developer.apple.com/documentation/avfaudio/avaudiosession/responding_to_audio_session_interruptions
 https://developer.apple.com/documentation/avfaudio/avaudiosession/1616596-interruptionnotification
 */

import AVFoundation
import Combine

// MARK: - AKAudioSessionInterruptionObserverDelegate

@MainActor
public protocol AKAudioSessionInterruptionObserverDelegate: AnyObject {
    func audioSessionInterruptionObserver(
        _ observer: AKAudioSessionInterruptionObserverProtocol,
        didBeginInterruptionWith reason: AVAudioSession.InterruptionReason?,
        for audioSession: AVAudioSession
    )
    
    func audioSessionInterruptionObserver(
        _ observer: AKAudioSessionInterruptionObserverProtocol,
        didEndInterruptionWith shouldResume: Bool,
        for audioSession: AVAudioSession
    )
}

// MARK: - AKAudioSessionInterruptionObserverProtocol

@MainActor
public protocol AKAudioSessionInterruptionObserverProtocol: AnyObject {
    var audioSession: AVAudioSession { get }
    var isInterrupted: Bool { get }
    var delegate: AKAudioSessionInterruptionObserverDelegate? { get set }
    
    func startObserving()
    func stopObserving()
}

// MARK: - AKAudioSessionInterruptionObserver

@MainActor
open class AKAudioSessionInterruptionObserver: AKAudioSessionInterruptionObserverProtocol {
    
    // MARK: - Properties
    
    public let audioSession: AVAudioSession
    
    public weak var delegate: AKAudioSessionInterruptionObserverDelegate?
    
    private var isObserving = false
    
    open private(set) var isInterrupted: Bool = false
    
    /// Container holding reactive Combine event subscriptions.
    /// Marked `nonisolated(unsafe)` for safe disposal in `deinit`.
    private nonisolated(unsafe) var subscriptions = Set<AnyCancellable>()
    
    // MARK: - Init & Deinit
    
    public init(audioSession: AVAudioSession) {
        self.audioSession = audioSession
    }
    
    deinit {
        subscriptions.removeAll()
    }
    
    // MARK: - Observation Lifecycle
    
    open func startObserving() {
        guard !isObserving else { return }
        
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification, object: audioSession)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }
                self.handleAudioSessionInterruption(notification)
            }
            .store(in: &subscriptions)
        
        isObserving = true
    }
    
    open func stopObserving() {
        guard isObserving else { return }
        subscriptions.removeAll()
        isObserving = false
    }
    
    // MARK: - Handlers
    
    open func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            var interruptionReason: AVAudioSession.InterruptionReason?
            if let reasonValue = userInfo[AVAudioSessionInterruptionReasonKey] as? UInt,
               let reason = AVAudioSession.InterruptionReason(rawValue: reasonValue) {
                interruptionReason = reason
            }
            isInterrupted = true
            delegate?.audioSessionInterruptionObserver(
                self,
                didBeginInterruptionWith: interruptionReason,
                for: audioSession
            )
            
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            isInterrupted = false
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            delegate?.audioSessionInterruptionObserver(
                self,
                didEndInterruptionWith: options.contains(.shouldResume),
                for: audioSession
            )
            
        @unknown default:
            break
        }
    }
}
