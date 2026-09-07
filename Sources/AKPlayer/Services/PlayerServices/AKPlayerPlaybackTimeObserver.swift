//
//   AKPlayerPlaybackTimeObserver.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation
import Combine

// MARK: - AKPlayerPlaybackTimeObserverProtocol

/// Protocol declaring capabilities for monitoring AVPlayer periodic and
/// boundary time updates.
@MainActor
public protocol AKPlayerPlaybackTimeObserverProtocol: AnyObject {
    var player: AVPlayer { get }
    var periodicTimePublisher: AnyPublisher<CMTime, Never> { get }
    var boundaryTimePublisher: AnyPublisher<CMTime, Never> { get }

    func startObservingPeriodicTime(for interval: CMTime)
    func startObservingBoundaryTime(for times: [CMTime])
    func stopObservingPeriodicTime()
    func stopObservingBoundaryTime()
}

// MARK: - AKPlayerPlaybackTimeObserver

/// Concrete observer delivering periodic and boundary time progress updates via
/// Combine publishers.
@MainActor
public class AKPlayerPlaybackTimeObserver: AKPlayerPlaybackTimeObserverProtocol {
    // MARK: - Properties

    public let player: AVPlayer

    public var periodicTimePublisher: AnyPublisher<CMTime, Never> {
        _periodicTimePublisher.eraseToAnyPublisher()
    }

    public var boundaryTimePublisher: AnyPublisher<CMTime, Never> {
        _boundaryTimePublisher.eraseToAnyPublisher()
    }

    private let _periodicTimePublisher = PassthroughSubject<CMTime, Never>()
    private let _boundaryTimePublisher = PassthroughSubject<CMTime, Never>()

    /// Opaque token returned by AVPlayer when registering periodic observer.
    /// Marked `nonisolated(unsafe)` to enable clean removal during
    /// deinitialization.
    private nonisolated(unsafe) var periodicTimeObserverToken: Any?

    /// Opaque token returned by AVPlayer when registering boundary observer.
    /// Marked `nonisolated(unsafe)` to enable clean removal during
    /// deinitialization.
    private nonisolated(unsafe) var boundaryTimeObserverToken: Any?

    // MARK: - Init & Deinit

    /// Initializes an observer for player playback time events.
    /// - Parameter player: The AVPlayer instance to observe.
    public init(with player: AVPlayer) {
        self.player = player
    }

    deinit {
        if let token = periodicTimeObserverToken {
            player.removeTimeObserver(token)
        }
        if let token = boundaryTimeObserverToken {
            player.removeTimeObserver(token)
        }
    }

    // MARK: - Periodic Time Observation

    public func startObservingPeriodicTime(for interval: CMTime) {
        stopObservingPeriodicTime()

        periodicTimeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self._periodicTimePublisher.send(time)
            }
        }
    }

    public func stopObservingPeriodicTime() {
        if let token = periodicTimeObserverToken {
            player.removeTimeObserver(token)
            periodicTimeObserverToken = nil
        }
    }

    // MARK: - Boundary Time Observation

    public func startObservingBoundaryTime(for times: [CMTime]) {
        stopObservingBoundaryTime()

        let boundaryTimes = times.map { NSValue(time: $0) }
        boundaryTimeObserverToken = player.addBoundaryTimeObserver(
            forTimes: boundaryTimes,
            queue: .main
        ) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self._boundaryTimePublisher.send(self.player.currentTime())
            }
        }
    }

    public func stopObservingBoundaryTime() {
        if let token = boundaryTimeObserverToken {
            player.removeTimeObserver(token)
            boundaryTimeObserverToken = nil
        }
    }
}
