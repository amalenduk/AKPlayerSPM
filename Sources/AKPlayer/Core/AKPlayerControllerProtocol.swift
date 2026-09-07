//
//  AKPlayerControllerProtocol.swift
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
import Combine
import Foundation

// MARK: - AKPlayerControllerPerforming

/// Defines raw low-level driver actions executed directly on the underlying playback pipeline.
@MainActor
public protocol AKPlayerControllerPerforming {
    /// Executes low-level playback initialization and unpauses the underlying player.
    func performPlay()

    /// Executes low-level playback at a specified speed rate.
    /// - Parameter rate: The target playback rate multiplier.
    func performPlay(at rate: AKPlaybackRate)

    /// Halts underlying playback pipeline without tearing down loaded assets.
    func performPause()

    /// Completely stops playback and resets internal player engine contexts.
    func performStop()

    /// Dispatches low-level seek operations to the underlying media item.
    /// - Parameter targetSeek: The seek target descriptor containing target position and tolerances.
    func performSeek(to targetSeek: AKSeek)

    /// Steps video playback by a fixed number of frames forward or backward.
    /// - Parameter count: Frame offset (positive for forward, negative for backward).
    func performStep(by count: Int)
}

// MARK: - AKPlayerControllerProtocol

/// Primary interface representing the core player controller driving playback engine, state transitions, and configuration.
@MainActor
public protocol AKPlayerControllerProtocol: AnyObject, AKPlayerProtocol,
    AKPlayerControllerPerforming
{
    /// Configuration options specifying playback policies and default rates.
    var configuration: any AKPlayerConfigurationProtocol { get }

    /// The active player state machine controller handling command validation.
    var controller: any AKPlayerStateControllerProtocol { get }

    /// Internal service handling media seek calculations and boundaries.
    var playerSeekingThroughMediaService: any AKPlayerSeekingThroughMediaServiceProtocol { get }

    /// Network monitor monitoring active connectivity status for media streaming.
    var networkStatusMonitor: any AKNetworkStatusMonitorProtocol { get }

    /// Prepares internal audio/video playback engines and system resources for playback.
    /// - Throws: An `AKPlayerError` if pipeline preparation fails.
    func prepare() throws

    /// Transitions the active state machine handler to a new target state controller.
    /// - Parameter controller: The new state machine controller instance.
    func change(_ controller: any AKPlayerStateControllerProtocol)

    /// Notifies the controller to re-process state logic after state transitions complete.
    func processStateChange()

    /// Single entry point for dispatching all player events across the framework.
    /// Broadcasts the event to the delegate and forwards it to event listeners (AsyncStream / Combine).
    /// - Parameter event: The player event that occurred.
    func emit(_ event: AKPlayerEvent)
}
