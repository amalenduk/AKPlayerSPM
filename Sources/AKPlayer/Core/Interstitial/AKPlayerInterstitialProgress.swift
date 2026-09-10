//
//  AKPlayerInterstitialProgress.swift
//  AKPlayer
//
//  Created by Amalendu Kar on 10/09/26.
//

import AVFoundation

public struct AKPlayerInterstitialProgress: Sendable {
    public let currentTime: TimeInterval
    public let duration: TimeInterval
    public let timeRemaining: TimeInterval
    
    public var percentage: Double {
        duration > 0 ? (currentTime / duration) : 0
    }
}
