//
//  AKPlayerInterstitialService.swift
//  AKPlayer
//
//  Created by Amalendu Kar on 10/09/26.
//

import AVFoundation
import Combine

public final class AKPlayerInterstitialService: @unchecked Sendable {
    private var monitor: AVPlayerInterstitialEventMonitor?
    private var controller: AVPlayerInterstitialEventController?
    private var timeObserverToken: Any?
    private weak var primaryPlayer: AVPlayer?
    
    public weak var delegate: AKPlayerInterstitialDelegate?
    
    // Notification Subscribers
    private var cancellables = Set<AnyCancellable>()

    public init(player: AVPlayer) {
        self.primaryPlayer = player
        self.monitor = AVPlayerInterstitialEventMonitor(primaryPlayer: player)
        self.controller = AVPlayerInterstitialEventController(primaryPlayer: player)
        
        setupObservers()
    }
    
    // MARK: - Event Monitoring
    
    private func setupObservers() {
        guard let monitor else { return }
        
        // Listen to Current Interstitial Event Changes
        NotificationCenter.default.publisher(for: AVPlayerInterstitialEventMonitor.currentEventDidChangeNotification, object: monitor)
            .sink { [weak self] _ in
                self?.handleCurrentEventChange()
            }
            .store(in: &cancellables)
            
        // Listen to Interstitial Completion
        NotificationCenter.default.publisher(for: AVPlayerInterstitialEventMonitor.eventsDidChangeNotification, object: monitor)
            .sink { [weak self] note in
                self?.handleEventDidFinish(notification: note)
            }
            .store(in: &cancellables)
    }
    
    private func handleCurrentEventChange() {
        guard let currentEvent = monitor?.currentEvent else {
            removeTimeObserver()
            return
        }
        
        // Notify Delegate Ad Started
        delegate?.player(monitor!, didStartInterstitial: currentEvent)
        
        // Start Dedicated Interstitial Timer
        setupInterstitialTimeObserver()
    }

    // MARK: - Interstitial Progress Timer
    
    private func setupInterstitialTimeObserver() {
        removeTimeObserver()
        
        guard let primaryPlayer = monitor?.interstitialPlayer else { return }
        
        // Periodic timer (every 0.25 sec) during ad playback
        let interval = CMTime(value: 1, timescale: 4)
        
        timeObserverToken = primaryPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self = self,
                  let currentItem = primaryPlayer.currentItem else { return }
            
            let current = currentItem.currentTime().seconds
            let duration = currentItem.duration.seconds
            
            if current.isFinite && duration.isFinite && duration > 0 {
                let progress = AKPlayerInterstitialProgress(
                    currentTime: current,
                    duration: duration,
                    timeRemaining: max(0, duration - current)
                )
                self.delegate?.player(monitor!, didUpdateInterstitialProgress: progress)
            }
        }
    }

    private func removeTimeObserver() {
        if let token = timeObserverToken, let primaryPlayer = monitor?.interstitialPlayer {
            primaryPlayer.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    private func handleEventDidFinish(notification: Notification) {
        removeTimeObserver()
        
        // Extract the finished event from userInfo or monitor history
        if let event = notification.userInfo?[AVPlayerInterstitialEventMonitor.currentEventDidChangeNotification] as? AVPlayerInterstitialEvent {
            delegate?.player(monitor!, didFinishInterstitial: event)
        } else if let currentEvent = monitor?.currentEvent {
            delegate?.player(monitor!, didFinishInterstitial: currentEvent)
        }
    }
    
    // MARK: - API: Skip Interstitial Event
    
    /// Skip current playing interstitial event programmatically
    public func skipCurrentInterstitial() {
        guard let currentItem = primaryPlayer?.currentItem else { return }
        // Seeking to end triggers AVPlayer to step past interstitial item
        let end = currentItem.duration
        if end.isValid && !end.isIndefinite {
            primaryPlayer?.seek(to: end)
        }
    }
    
    // MARK: - API: Schedule Client-Side Ad
    
    public func scheduleAd(at time: CMTime, templateItems: [AVPlayerItem]) {
        guard let primaryItem = primaryPlayer?.currentItem, let controller = controller else { return }
        
        let event = AVPlayerInterstitialEvent(
            primaryItem: primaryItem,
            time: time
        )
        event.templateItems = templateItems
        controller.events.append(event)
    }
}
