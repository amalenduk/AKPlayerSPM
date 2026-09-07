//
//  AKNowPlayingSession.swift
//  AKPlayer
//
//  Copyright (c) 2020 Amalendu Kar
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE
//  SOFTWARE.
//

import AVFoundation
import Foundation
import MediaPlayer

// MARK: - AKNowPlayingSessionProtocol

/// High-level manager for Now Playing session management with command
/// configuration.
/// Provides production-ready session management with easy enable/disable
/// capabilities.
@MainActor
public protocol AKNowPlayingSessionProtocol: AKNowPlayingSessionControllerProtocol {
  /// The command registry associated with this session.
  var commandRegistry: AKNowPlayingCommandRegistry { get }

  /// Applies a command configuration to this session asynchronously.
  func applyConfiguration(_ config: AKNowPlayingCommandConfiguration) async

  /// Configures now playing metadata across session updates.
  func setNowPlayingInfo(_ metadata: AKNowPlayableMetadata?)

  /// Checks if the session is currently active.
  var isActive: Bool { get }
}

// MARK: - AKNowPlayingSession

/// Production-ready implementation of `AKNowPlayingSessionProtocol`.
/// Wrapper class around `AKNowPlayingSessionController` to provide state
/// tracking via `AKNowPlayingCommandRegistry`.
@MainActor
public final class AKNowPlayingSession: AKNowPlayingSessionProtocol {
  // MARK: - Stored & Computed Properties

  /// The event emitter forwarding command invocation notifications.
  public var eventEmitter: AKRemoteCommandEventEmitter {
    controller.eventEmitter
  }

  /// The command registry tracking command state across the session.
  public let commandRegistry: AKNowPlayingCommandRegistry

  /// Underlying session controller handling low-level `MPRemoteCommandCenter`
  /// interactions.
  private let controller: AKNowPlayingSessionController

  /// Underlying system `MPRemoteCommandCenter` target.
  public var remoteCommandCenter: MPRemoteCommandCenter {
    controller.remoteCommandCenter
  }

  /// Underlying system `MPNowPlayingInfoCenter` target.
  public var nowPlayingInfoCenter: MPNowPlayingInfoCenter {
    controller.nowPlayingInfoCenter
  }

  /// Indicates whether the underlying session is currently active.
  public var isActive: Bool {
    controller.isActive
  }

  // MARK: - Initialization & Deinitialization

  /// Initializes a new Now Playing session bound to dynamic audio players
  /// (`AVPlayer` instances).
  /// - Parameters:
  ///   - players: Array of `AVPlayer` instances to monitor.
  ///   - registry: An optional custom command registry. Defaults to a new
  /// instance if nil.
  public init(
    players: [AVPlayer],
    registry: AKNowPlayingCommandRegistry? = nil
  ) {
    controller = AKNowPlayingSessionController(players: players)
    commandRegistry = registry ?? AKNowPlayingCommandRegistry()
  }

  /// Initializes a standalone Now Playing session using standard or custom
  /// command centers.
  /// - Parameters:
  ///   - remoteCommandCenter: Custom or shared `MPRemoteCommandCenter`.
  ///   - nowPlayingInfoCenter: Custom or default `MPNowPlayingInfoCenter`.
  ///   - registry: An optional custom command registry. Defaults to a new
  /// instance if nil.
  public init(
    remoteCommandCenter: MPRemoteCommandCenter = .shared(),
    nowPlayingInfoCenter: MPNowPlayingInfoCenter = .default(),
    registry: AKNowPlayingCommandRegistry? = nil
  ) {
    controller = AKNowPlayingSessionController(
      remoteCommandCenter: remoteCommandCenter,
      nowPlayingInfoCenter: nowPlayingInfoCenter
    )
    commandRegistry = registry ?? AKNowPlayingCommandRegistry()
  }

  deinit {
    // Actors deallocate safely on their own; synchronous clear omitted to
    // avoid isolation errors in deinit.
  }

  // MARK: - Configuration

  /// Applies a command configuration to this session.
  /// Registers commands, attaches custom handlers, and configures active
  /// status on `MPRemoteCommandCenter`.
  /// - Parameter config: The `AKNowPlayingCommandConfiguration` to apply.
  public func applyConfiguration(
    _ config: AKNowPlayingCommandConfiguration
  ) async {
    let commands = config.allCommands

    // Register all commands in internal registry
    for command in commands {
      await commandRegistry.register(
        command,
        isEnabled: config.isEnabled(command)
      )
    }

    // Attach handlers to registry and controller
    for command in commands {
      if let handler = config.handler(for: command) {
        await commandRegistry.setCustomHandler(
          command,
          handler: handler
        )
        controller.setHandler(for: command, handler: handler)
      }
    }

    // Register target handlers on MPRemoteCommandCenter
    controller.register(commands: commands)

    // Enable or disable command targets based on configuration state
    for command in commands {
      if config.isEnabled(command) {
        controller.enable(commands: [command])
      } else {
        controller.disable(commands: [command])
      }
    }
  }

  // MARK: - Command Management

  /// Registers commands in the internal registry and low-level controller.
  public func register(commands: [AKRemoteCommand]) async {
    for command in commands {
      await commandRegistry.register(command)
    }
    controller.register(commands: commands)
  }

  /// Unregisters commands from the internal registry and low-level
  /// controller.
  public func unregister(commands: [AKRemoteCommand]) async {
    for command in commands {
      await commandRegistry.unregister(command)
    }
    controller.unregister(commands: commands)
  }

  /// Enables specified commands in both registry and target remote command
  /// center.
  public func enable(commands: [AKRemoteCommand]) async {
    var enabledCommands: [AKRemoteCommand] = []
    for command in commands {
      if await commandRegistry.enable(command) {
        enabledCommands.append(command)
      }
    }
    controller.enable(commands: enabledCommands)
  }

  /// Disables specified commands in both registry and target remote command
  /// center.
  public func disable(commands: [AKRemoteCommand]) async {
    var disabledCommands: [AKRemoteCommand] = []
    for command in commands {
      if await commandRegistry.disable(command) {
        disabledCommands.append(command)
      }
    }
    controller.disable(commands: disabledCommands)
  }

  /// Queries whether a given command is currently marked enabled in the
  /// command registry.
  public func isCommandEnabled(_ command: AKRemoteCommand) async -> Bool {
    await commandRegistry.isEnabled(command)
  }

  /// Sets a custom event handler closure for a specific remote command.
  public func setHandler(
    for command: AKRemoteCommand,
    handler: @escaping AKRemoteCommandHandler
  )
    async
  {
    await commandRegistry.setCustomHandler(command, handler: handler)
    controller.setHandler(for: command, handler: handler)
  }

  /// Removes a custom event handler closure for a specific remote command.
  public func removeHandler(for command: AKRemoteCommand) async {
    await commandRegistry.removeCustomHandler(command)
    controller.removeHandler(for: command)
  }

  // MARK: - Metadata & Player Management

  /// Sets now playing playback metadata on the active info center.
  public func setNowPlayingInfo(_ metadata: AKNowPlayableMetadata?) {
    controller.setNowPlayingInfo(metadata)
  }

  /// Clears now playing playback info from the active info center.
  public func clearNowPlayingPlaybackInfo() {
    controller.clearNowPlayingPlaybackInfo()
  }

  /// Determines whether the now playing session can transition to an active
  /// state.
  public func canBecomeActive() -> Bool {
    controller.canBecomeActive()
  }

  /// Adds an `AVPlayer` instance to the underlying session.
  public func addPlayer(_ player: AVPlayer) {
    controller.addPlayer(player)
  }

  /// Removes an `AVPlayer` instance from the underlying session.
  public func removePlayer(_ player: AVPlayer) {
    controller.removePlayer(player)
  }

  /// Requests activation of the underlying session if possible.
  public func becomeActiveIfPossible() async -> Bool {
    await controller.becomeActiveIfPossible()
  }
}

// MARK: - Convenience Extensions

extension AKNowPlayingSession {
  /// Configures session with a preset configuration asynchronously.
  public func configureWithPreset(_ preset: AKNowPlayingCommandConfiguration) async {
    await applyConfiguration(preset)
  }
}
