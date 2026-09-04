//
//  AKAudioSessionRouteChangesObserver.swift
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

// Ref: https://developer.apple.com/documentation/avfaudio/avaudiosession/responding_to_audio_session_route_changes

import AVFoundation
import Combine

// MARK: - AKAudioSessionRouteChangesObserverDelegate

@MainActor
public protocol AKAudioSessionRouteChangesObserverDelegate: AnyObject {
    func audioSessionRouteChangesObserver(
        _ observer: AKAudioSessionRouteChangesObserverProtocol,
        didChangeRouteTo currentRoute: AVAudioSessionRouteDescription,
        from previousRoute: AVAudioSessionRouteDescription?,
        with reason: AVAudioSession.RouteChangeReason
    )
}

// MARK: - AKAudioSessionRouteChangesObserverProtocol

@MainActor
public protocol AKAudioSessionRouteChangesObserverProtocol: AnyObject {
    var audioSession: AVAudioSession { get }
    var delegate: AKAudioSessionRouteChangesObserverDelegate? { get set }
    
    func isExternalDeviceConnected() -> Bool
    func hasHeadphonesConnected() -> Bool
    func startObserving()
    func stopObserving()
}

// MARK: - AKAudioSessionRouteChangesObserver

@MainActor
public class AKAudioSessionRouteChangesObserver: AKAudioSessionRouteChangesObserverProtocol {
    
    // MARK: - Properties
    
    public let audioSession: AVAudioSession
    
    public weak var delegate: AKAudioSessionRouteChangesObserverDelegate?
    
    private var isObserving = false
    
    /// Container holding reactive Combine event subscriptions.
    /// Marked `nonisolated(unsafe)` for thread-safe cleanup during `deinit`.
    private nonisolated(unsafe) var subscriptions = Set<AnyCancellable>()
    
    // MARK: - Init & Deinit
    
    public init(audioSession: AVAudioSession) {
        self.audioSession = audioSession
    }
    
    deinit {
        subscriptions.removeAll()
    }
    
    // MARK: - Observation Lifecycle
    
    public func startObserving() {
        guard !isObserving else { return }
        
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification, object: audioSession)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }
                self.handleRouteChange(notification)
            }
            .store(in: &subscriptions)
        
        isObserving = true
    }
    
    public func stopObserving() {
        guard isObserving else { return }
        subscriptions.removeAll()
        isObserving = false
    }
    
    // MARK: - Handlers
    
    public func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription
        
        delegate?.audioSessionRouteChangesObserver(
            self,
            didChangeRouteTo: audioSession.currentRoute,
            from: previousRoute,
            with: reason
        )
    }
    
    // MARK: - Helper Functions
    
    public func isExternalDeviceConnected() -> Bool {
        return !audioSession.currentRoute.outputs.contains(where: { $0.portType == .builtInSpeaker })
    }
    
    public func hasHeadphonesConnected() -> Bool {
        return audioSession.currentRoute.outputs.contains(where: { $0.portType == .headphones })
    }
}
