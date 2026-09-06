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

/// A delegate protocol for receiving updates when an audio session interruption begins or ends.
@MainActor
public protocol AKAudioSessionInterruptionObserverDelegate: AnyObject {
    
    /// Informs the delegate that an audio session interruption has begun.
    /// - Parameters:
    ///   - observer: The interruption observer reporting the event.
    ///   - reason: The specific `AVAudioSession.InterruptionReason` causing the interruption, if available.
    ///   - audioSession: The active `AVAudioSession` instance undergoing interruption.
    func audioSessionInterruptionObserver(
        _ observer: AKAudioSessionInterruptionObserverProtocol,
        didBeginInterruptionWith reason: AVAudioSession.InterruptionReason?,
        for audioSession: AVAudioSession
    )
    
    /// Informs the delegate that an audio session interruption has ended.
    /// - Parameters:
    ///   - observer: The interruption observer reporting the event.
    ///   - shouldResume: A Boolean value indicating whether playback should automatically resume.
    ///   - audioSession: The active `AVAudioSession` instance that recovered from interruption.
    func audioSessionInterruptionObserver(
        _ observer: AKAudioSessionInterruptionObserverProtocol,
        didEndInterruptionWith shouldResume: Bool,
        for audioSession: AVAudioSession
    )
}

// MARK: - AKAudioSessionInterruptionObserverProtocol

/// A protocol defining requirements for observing audio session lifecycle interruptions.
@MainActor
public protocol AKAudioSessionInterruptionObserverProtocol: AnyObject {
    
    /// The target `AVAudioSession` instance being monitored.
    var audioSession: AVAudioSession { get }
    
    /// A Boolean value indicating whether the audio session is currently in an interrupted state.
    var isInterrupted: Bool { get }
    
    /// The delegate object notified of audio interruption events.
    var delegate: AKAudioSessionInterruptionObserverDelegate? { get set }
    
    /// Begins observing system-level audio session interruption notifications.
    func startObserving()
    
    /// Stops monitoring audio session interruption notifications and removes active subscriptions.
    func stopObserving()
}

// MARK: - AKAudioSessionInterruptionObserver

/// A concrete implementation of `AKAudioSessionInterruptionObserverProtocol` utilizing Combine to monitor audio session interruptions.
@MainActor
open class AKAudioSessionInterruptionObserver: AKAudioSessionInterruptionObserverProtocol {
    
    // MARK: - Properties
    
    /// The `AVAudioSession` instance managed by this observer.
    public let audioSession: AVAudioSession
    
    /// The delegate object notified of interruption callbacks.
    public weak var delegate: AKAudioSessionInterruptionObserverDelegate?
    
    /// A Boolean flag tracking whether notification subscriptions are currently active.
    private var isObserving = false
    
    /// A Boolean value indicating whether the audio session is currently interrupted.
    open private(set) var isInterrupted: Bool = false
    
    /// Container holding reactive Combine event subscriptions.
    private var subscriptions = Set<AnyCancellable>()
    
    // MARK: - Init & Deinit
    
    /// Initializes a new interruption observer with a target audio session.
    /// - Parameter audioSession: The `AVAudioSession` instance to observe.
    public init(audioSession: AVAudioSession) {
        self.audioSession = audioSession
    }
    
    deinit { }
    
    // MARK: - Observation Lifecycle
    
    /// Starts observing audio session interruption notifications on the main queue.
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
    
    /// Stops observing interruptions and clears active Combine subscriptions.
    open func stopObserving() {
        guard isObserving else { return }
        subscriptions.removeAll()
        isObserving = false
    }
    
    // MARK: - Handlers
    
    /// Processes incoming interruption notifications and updates state or notifies the delegate.
    /// - Parameter notification: The `Notification` object containing interruption metadata.
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
