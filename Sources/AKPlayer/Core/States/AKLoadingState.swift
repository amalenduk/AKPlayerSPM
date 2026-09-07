//
//  AKLoadingState.swift
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
import Combine

// MARK: - AKLoadingState

/// Concrete state representing a state where media is currently being
/// initialized, loaded, and prepared for active playback.
@MainActor
public class AKLoadingState: AKBaseState {
    // MARK: - Properties

    /// The media item being loaded into the player pipeline.
    private let media: any AKPlayable

    /// Indicates whether playback should automatically start once loading
    /// completes.
    public private(set) var autoPlay: Bool

    /// An optional initial position to seek to upon entering loaded state.
    private let position: AKSeekTarget?

    /// An optional playback rate target to set upon loading complete.
    private var rate: AKPlaybackRate?

    /// Tracks if initialization operations were explicitly aborted or
    /// cancelled.
    private var isCancelled: Bool = false

    /// Asynchronous validation task reference used for loading asset
    /// playability.
    private var task: Task<Void, Never>?

    /// Container holding reactive Combine event subscriptions.
    private var subscriptions = Set<AnyCancellable>()

    // MARK: - Initialization & Deinitialization

    /// Initializes a loading state instance with specified options.
    /// - Parameters:
    ///   - playerController: The underlying player controller driving
    /// execution.
    ///   - media: The target media item to load.
    ///   - autoPlay: Whether auto-start is requested post-loading.
    ///   - position: Optional initial seek target.
    ///   - rate: Optional initial playback speed multiplier.
    public init(
        playerController: any AKPlayerControllerProtocol,
        media: any AKPlayable,
        autoPlay: Bool = false,
        position: AKSeekTarget? = nil,
        rate: AKPlaybackRate? = nil
    ) {
        self.media = media
        self.autoPlay = autoPlay
        self.position = position
        self.rate = rate
        super.init(playerController: playerController, state: .loading)
    }

    deinit {
        task?.cancel()
    }

    // MARK: - Lifecycle Hooks

    /// Entry point for state setup. Cleans up prior item observers, emits
    /// initial media change events, and monitors media load state transitions.
    override public func processStateChange() {
        resetPlayer()
        playerController.emit(.mediaDidChange(media))

        media.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                hanldeChangeInMedia(state)
            }
            .store(in: &subscriptions)
    }

    // MARK: - Commands

    /// Registers playback request while media is still loading. Sets `autoPlay`
    /// flag to true.
    override public func play() {
        autoPlay = true
    }

    /// Intercepts specific speed adjustments requested during loading state and
    /// fires unavailable action delegate notifications.
    /// - Parameter rate: The target speed requested.
    override public func play(at _: AKPlaybackRate) {
        playerController.emit(.commandUnavailable(reason: .waitTillMediaLoaded))
    }

    /// Cancels queued autoplay request while media is loading.
    override public func pause() {
        autoPlay = false
    }

    /// Toggles autoplay behavior based on current state.
    override public func togglePlayPause() {
        autoPlay ? pause() : play()
    }

    // MARK: - Helper Functions

    /// Handles progressive steps across media preparation stages.
    /// - Parameter state: Current asset loading lifecycle phase.
    private func hanldeChangeInMedia(_ state: AKPlayableState) {
        switch state {
        case .idle:
            createAsset()
        case .assetLoaded:
            task = Task { [weak self] in
                guard let self else { return }
                await validateAssetPlayability()
                if isCancelled {
                    return
                }
                createPlayerItemFromAsset()
            }
        case .playerItemLoaded:
            playerItemLoaded()
        case .readyToPlay
            where !(playerController.player.currentItem == media.playerItem):
            playerItemLoaded()
        case .readyToPlay:
            becameReadyToPlay()
        case .failed:
            if let error = media.error {
                failedToPrepareForPlayback(with: error)
            }
        }
    }

    /// Requests underlying media instance to construct its underlying AVAsset.
    private func createAsset() {
        media.createAsset()
    }

    /// Validates asset integrity and playability metrics asynchronously.
    private func validateAssetPlayability() async {
        do {
            try await media.validateAssetPlayability()
        } catch let playerError as AKPlayerError {
            failedToPrepareForPlayback(with: playerError)
        } catch {
            failedToPrepareForPlayback(
                with: .playerCanNoLongerPlay(error: error)
            )
        }
    }

    /// Requests media wrapper to generate AVPlayerItem out of validated asset.
    private func createPlayerItemFromAsset() {
        media.createPlayerItemFromAsset()
    }

    /// Prepares player item and links it with AVPlayer pipeline once loaded.
    private func playerItemLoaded() {
        /*
         You should call this method before associating the player item with the player to make
         sure you capture all state changes to the item’s status.
         */
        if let item = media.playerItem {
            playerController.player.replaceCurrentItem(with: item)
        }
    }

    /// Evaluates AVPlayer ready status and transitions state to `AKLoadedState`
    /// upon success.
    private func becameReadyToPlay() {
        playerController.player.publisher(
            for: \.status,
            options: [.initial, .new]
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] status in
            guard let self else { return }
            switch status {
            case .readyToPlay:
                let controller = AKLoadedState(
                    playerController: playerController,
                    autoPlay: autoPlay,
                    position: position
                )
                change(controller)
            case .failed:
                let controller = AKFailedState(
                    playerController: playerController,
                    error: .playerCanNoLongerPlay(error: playerController
                        .player.error)
                )
                change(controller)
            default:
                break
            }
        }
        .store(in: &subscriptions)
    }

    /// Aborts tasks and asset loading operations.
    private func abortAssetInitialization() {
        task?.cancel()
        isCancelled = true
        subscriptions.removeAll()
        media.abortAssetInitialization()
    }

    /// Resets active player item and pauses current playback.
    private func resetPlayer() {
        if !playerController.player.timeControlStatus.isPaused {
            playerController.performPause()
        }
        /*
         It seems to be a good idea to reset player current item
         Fix side effect when coming from failed state
         */
        playerController.currentItem?.cancelPendingSeeks()
        playerController.player.replaceCurrentItem(with: nil)
    }

    // MARK: - Error Handling

    /// Transitions state engine into `AKFailedState` when media initialization
    /// fails.
    /// - Parameter error: Specific player error description encounter.
    private func failedToPrepareForPlayback(with error: AKPlayerError) {
        guard !isCancelled else { return }
        let controller = AKFailedState(
            playerController: playerController,
            error: error
        )
        change(controller)
    }

    // MARK: - Transition Overrides

    /// Aborts current load routines prior to processing a new media load
    /// command.
    override public func beforeLoad(
        media _: any AKPlayable, autoPlay _: Bool, position _: AKSeekTarget?
    ) {
        abortAssetInitialization()
    }

    /// Cancels asset loads and strips observers prior to stopping the player
    /// controller.
    override public func beforeStop() {
        abortAssetInitialization()
    }

    /// Checks availability for specified target actions during loading phase.
    override public func availability(for action: AKPlayerAction)
        -> (allowed: Bool, reason: AKPlayerUnavailableCommandReason?)
    {
        switch action {
        case .seek, .step, .fastForward, .rewind:
            (false, .waitTillMediaLoaded)
        default:
            super.availability(for: action)
        }
    }

    /// Cleans active Combine observers prior to completing state exit.
    override public func beforeStateChange() {
        subscriptions.removeAll()
    }
}
