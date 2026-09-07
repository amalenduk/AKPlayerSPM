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

// MARK: - AKAudioSessionServiceProtocol

/// A protocol defining requirements for managing audio session configuration, category settings, and activation state.
@MainActor
public protocol AKAudioSessionServiceProtocol: AnyObject {
    /// The underlying `AVAudioSession` instance managed by the service.
    var audioSession: AVAudioSession { get }

    /// Configures the audio session category, mode, and options.
    /// - Parameters:
    ///   - category: The audio session category to apply.
    ///   - mode: The audio session mode to apply.
    ///   - options: The category options governing behavior such as mixing or ducking.
    /// - Throws: An error if the category configuration fails.
    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws

    /// Activates or deactivates the audio session.
    /// - Parameters:
    ///   - active: A Boolean value indicating whether to activate (`true`) or deactivate (`true` / `false`) the session.
    ///   - options: Options governing activation/deactivation behavior (such as notifying other audio sessions).
    /// - Throws: An error if activation or deactivation fails.
    func activate(
        _ active: Bool,
        options: AVAudioSession.SetActiveOptions
    ) throws
}

// MARK: - AKAudioSessionService

/// A concrete implementation of `AKAudioSessionServiceProtocol` for managing system audio session configurations safely on the main actor.
@MainActor
public class AKAudioSessionService: AKAudioSessionServiceProtocol {
    // MARK: - Properties

    /// The managed `AVAudioSession` instance.
    public let audioSession: AVAudioSession

    // MARK: - Init & Deinit

    /// Initializes a new audio session service with a target audio session instance.
    /// - Parameter audioSession: The `AVAudioSession` instance to manage. Defaults to the shared instance.
    public init(audioSession: AVAudioSession = AVAudioSession.sharedInstance()) {
        self.audioSession = audioSession
    }

    deinit {}

    // MARK: - Configuration Methods

    /// Configures the underlying audio session category, mode, and options, wrapping any failures into player-specific errors.
    /// - Parameters:
    ///   - category: The audio session category.
    ///   - mode: The audio session mode. Defaults to `.default`.
    ///   - options: The category options. Defaults to an empty set.
    /// - Throws: `AKPlayerError.audioSessionFailure` if setting the category fails.
    public func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode = .default,
        options: AVAudioSession.CategoryOptions = []
    ) throws {
        do {
            try audioSession.setCategory(
                category,
                mode: mode,
                options: options
            )
        } catch {
            throw AKPlayerError.audioSessionFailure(reason: .failedToSetCategory(error: error))
        }
    }

    /// Activates or deactivates the underlying audio session, wrapping any failures into player-specific errors.
    /// - Parameters:
    ///   - active: A Boolean flag indicating activation state.
    ///   - options: Set options guiding the activation behavior. Defaults to an empty set.
    /// - Throws: `AKPlayerError.audioSessionFailure` if activation or deactivation fails.
    public func activate(
        _ active: Bool,
        options: AVAudioSession.SetActiveOptions = []
    ) throws {
        do {
            try audioSession.setActive(
                active,
                options: options
            )
        } catch {
            throw AKPlayerError.audioSessionFailure(
                reason: active
                    ? .failedToActivate(error: error)
                    : .failedToDeactivate(error: error)
            )
        }
    }
}
