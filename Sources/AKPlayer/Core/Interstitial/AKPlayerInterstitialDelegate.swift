//
//  AKPlayerInterstitialDelegate.swift
//  AKPlayer
//
//  Created by Amalendu Kar on 10/09/26.
//

import AVFoundation

public protocol AKPlayerInterstitialDelegate: AnyObject {
    /// Called when an interstitial starts playing
    func player(_ monitor: AVPlayerInterstitialEventMonitor, didStartInterstitial event: AVPlayerInterstitialEvent)
    
    /// Called periodically with current ad time & duration
    func player(_ monitor: AVPlayerInterstitialEventMonitor, didUpdateInterstitialProgress progress: AKPlayerInterstitialProgress)
    
    /// Called when an interstitial finishes or is skipped
    func player(_ monitor: AVPlayerInterstitialEventMonitor, didFinishInterstitial event: AVPlayerInterstitialEvent)
}
