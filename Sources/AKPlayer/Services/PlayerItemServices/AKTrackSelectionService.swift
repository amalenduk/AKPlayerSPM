//
//  AKTrackSelectionService.swift
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

import Foundation
@preconcurrency import AVFoundation
import MediaAccessibility

// MARK: - AKTrackSelectionServiceProtocol

/// A protocol defining track selection and query capabilities for media streams (audio, subtitles, captions).
@MainActor
public protocol AKTrackSelectionServiceProtocol {
    
    /// Retrieves all available media track options for a specific track type.
    /// - Parameter type: The target `AKTrackType` (audio, subtitle, closed caption, etc.).
    /// - Returns: An `AKTrackSelectionInfo` model containing available options and current selection.
    /// - Throws: `AKPlayerError.noItemToPlay` if no player item is loaded or `AKPlayerError.trackSelectionFailure` if loading media selection groups fails.
    func availableTracks(for type: AKTrackType) async throws -> AKTrackSelectionInfo
    
    /// Fetches the currently selected track option for a given track type.
    /// - Parameter type: The target `AKTrackType`.
    /// - Returns: The currently active `AKMediaTrackOption`, or `nil` if none is selected.
    /// - Throws: An `AKPlayerError.trackSelectionFailure` if loading the underlying asset group fails.
    func selectedTrack(for type: AKTrackType) async throws -> AKMediaTrackOption?
    
    /// Selects a specific track option for a given track type.
    /// - Parameters:
    ///   - option: The option to select, or `nil` / `.off` to disable.
    ///   - type: The target `AKTrackType`.
    /// - Throws: `AKPlayerError.noItemToPlay` if no active item exists, or `AKPlayerError.trackSelectionFailure` if selection fails or empty selection is disallowed.
    func select(_ option: AKMediaTrackOption?, for type: AKTrackType) async throws
    
    /// Selects the best track option based on user locale preferences or default settings.
    /// - Parameter type: The target `AKTrackType`.
    /// - Throws: An `AKPlayerError` if querying tracks or performing the selection fails.
    func selectPreferredTrack(for type: AKTrackType) async throws
    
    /// Clears track selection caches, observers, and resets session tracking.
    func resetSession() async
    
    /// Creates an `AsyncStream` emitting track selection updates whenever the active track changes.
    /// - Parameter type: The target `AKTrackType`.
    /// - Returns: An `AsyncStream` yielding optional `AKMediaTrackOption` updates.
    func selectionChanges(for type: AKTrackType) -> AsyncStream<AKMediaTrackOption?>
}

// MARK: - AKTrackSelectionService

/// Service responsible for managing, querying, and switching audio, subtitle, and caption tracks on an `AVPlayerItem`.
@MainActor
public final class AKTrackSelectionService: AKTrackSelectionServiceProtocol {
    
    // MARK: - Properties
    
    /// A weak reference to the parent media manager providing actor-safe access to the active `AVPlayerItem`.
    private weak var mediaManager: (any AKMediaManagerProtocol)?
    
    /// Cached `AVMediaSelectionGroup` objects mapped by asset item key and track type.
    private var groupCache: [String: AVMediaSelectionGroup] = [:]
    
    /// Active continuation listeners for streaming selection updates.
    private var continuations: [AKTrackType: [UUID: AsyncStream<AKMediaTrackOption?>.Continuation]] = [:]
    
    /// Last known track selections used to deduplicate broadcast updates.
    private var lastKnownSelection: [AKTrackType: AKMediaTrackOption?] = [:]
    
    /// Notification center token for external media selection observer.
    private var externalChangeObserver: NSObjectProtocol?
    
    /// Convenience non-throwing accessor for the active `AVPlayerItem`.
    private var playerItem: AVPlayerItem? {
        mediaManager?.playerItem
    }
    
    // MARK: - Initialization & Cleanup
    
    /// Initializes a new track selection service bound to a parent media manager.
    /// - Parameter mediaManager: The parent media manager instance.
    public init(mediaManager: any AKMediaManagerProtocol) {
        self.mediaManager = mediaManager
        
        // Start observing external track selection updates (e.g., system AVPlayerViewController changes)
        startObservingExternalChanges()
    }
    
    deinit { }
    
    // MARK: - Public API
    
    /// Retrieves all available media track options for a specific track type.
    /// - Parameter type: The target `AKTrackType` (audio, subtitle, closed caption, etc.).
    /// - Returns: An `AKTrackSelectionInfo` model containing available options and current selection.
    /// - Throws: `AKPlayerError.noItemToPlay` if no active player item exists, or `AKPlayerError.trackSelectionFailure` if fetching media groups fails.
    public func availableTracks(for type: AKTrackType) async throws -> AKTrackSelectionInfo {
        guard let playerItem else {
            throw AKPlayerError.noItemToPlay
        }
        
        guard let group = try await mediaGroup(for: type, in: playerItem.asset) else {
            return AKTrackSelectionInfo(options: [], selected: nil, allowsEmptySelection: true)
        }
        
        let filtered = filterSpecialized(group.options, for: type)
        let defaultOption = group.defaultOption
        
        var trackOptions = filtered.map {
            AKMediaTrackOption(option: $0, isDefault: $0 == defaultOption)
        }
        
        let allowsEmpty = group.allowsEmptySelection
        if (type == .subtitle || type == .closedCaption), allowsEmpty {
            trackOptions.insert(.off, at: 0)
        }
        
        let selected = try await selectedTrack(for: type)
        return AKTrackSelectionInfo(options: trackOptions, selected: selected, allowsEmptySelection: allowsEmpty)
    }
    
    /// Fetches the currently selected track option for a given track type.
    /// - Parameter type: The target `AKTrackType`.
    /// - Returns: The currently active `AKMediaTrackOption`, or `nil` if none is selected.
    /// - Throws: An `AKPlayerError.trackSelectionFailure` if media selection group fetching fails.
    public func selectedTrack(for type: AKTrackType) async throws -> AKMediaTrackOption? {
        guard let playerItem else {
            return offIfApplicable(type)
        }
        
        guard let group = try await mediaGroup(for: type, in: playerItem.asset) else {
            return offIfApplicable(type)
        }
        
        guard let selectedOption = playerItem.currentMediaSelection.selectedMediaOption(in: group) else {
            return offIfApplicable(type)
        }
        
        return AKMediaTrackOption(option: selectedOption, isDefault: selectedOption == group.defaultOption)
    }
    
    /// Selects a specific track option for a given track type.
    /// - Parameters:
    ///   - option: The option to select, or `nil` / `.off` to disable.
    ///   - type: The target `AKTrackType`.
    /// - Throws: `AKPlayerError.noItemToPlay` if no player item is set, or `AKPlayerError.trackSelectionFailure` if selection is forbidden.
    public func select(_ option: AKMediaTrackOption?, for type: AKTrackType) async throws {
        guard let playerItem else {
            throw AKPlayerError.noItemToPlay
        }
        
        guard let group = try await mediaGroup(for: type, in: playerItem.asset) else { return }
        
        let targetOption = option?.option
        
        if targetOption == nil && !group.allowsEmptySelection {
            throw AKPlayerError.trackSelectionFailure(reason: .emptySelectionForbidden(type))
        }
        
        // AVPlayerItem selection updates execute directly on MainActor
        if let mediaOption = targetOption {
            playerItem.select(mediaOption, in: group)
        } else {
            playerItem.select(nil, in: group)
        }
        
        let resolved = try await selectedTrack(for: type)
        recordAndBroadcastIfChanged(resolved, for: type)
    }
    
    /// Selects the best track option based on user locale preferences or default settings.
    /// - Parameter type: The target `AKTrackType`.
    /// - Throws: An `AKPlayerError` if querying tracks or performing selection encounters an error.
    public func selectPreferredTrack(for type: AKTrackType) async throws {
        let info = try await availableTracks(for: type)
        guard !info.options.isEmpty else { return }
        
        if (type == .subtitle || type == .closedCaption), !systemCaptioningEnabled() {
            if info.allowsEmptySelection {
                try await select(.off, for: type)
            }
            return
        }
        
        guard let playerItem else { return }
        let asset = playerItem.asset
        
        guard let group = try await mediaGroup(for: type, in: asset) else { return }
        
        let preferredLocale = Locale.preferredLanguages.first.map(Locale.init(identifier:)) ?? Locale.current
        let matches = AVMediaSelectionGroup.mediaSelectionOptions(from: group.options, with: preferredLocale)
        
        if let best = matches.first,
           let match = info.options.first(where: { $0.option == best }) {
            try await select(match, for: type)
        } else if let fallback = info.options.first(where: { $0.isDefault }) {
            try await select(fallback, for: type)
        }
    }
    
    /// Clears track selection caches, observers, and resets session tracking.
    public func resetSession() async {
        // 1. Clear cached AVMediaSelectionGroup instances
        groupCache.removeAll()
        
        // 2. Clear stale track selection states
        lastKnownSelection.removeAll()
        
        // 3. Remove existing notification observer if active
        if let externalChangeObserver {
            NotificationCenter.default.removeObserver(externalChangeObserver)
            self.externalChangeObserver = nil
        }
        
        // 4. Re-bind external change observation with the current player item
        startObservingExternalChanges()
    }
    
    /// Creates an `AsyncStream` emitting track selection updates whenever the active track changes.
    /// - Parameter type: The target `AKTrackType`.
    /// - Returns: An `AsyncStream` yielding optional `AKMediaTrackOption` updates.
    public nonisolated func selectionChanges(for type: AKTrackType) -> AsyncStream<AKMediaTrackOption?> {
        AsyncStream { continuation in
            let id = UUID()
            
            Task { @MainActor in
                self.addContinuation(continuation, with: id, for: type)
                
                // Seed stream with initial selection value
                if let current = try? await self.selectedTrack(for: type) {
                    continuation.yield(current)
                    self.recordSelection(current, for: type)
                }
            }
            
            // Clean up when subscriber cancels stream
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.removeContinuation(id, for: type)
                }
            }
        }
    }
    
    // MARK: - External Change Observation
    
    /// Starts observing external notifications for media selection changes.
    private func startObservingExternalChanges() {
        guard let playerItem else { return }
        
        externalChangeObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.mediaSelectionDidChangeNotification,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.handleExternalChangeNotification()
            }
        }
    }
    
    /// Handles media selection changes triggered externally by updating stream continuations.
    private func handleExternalChangeNotification() async {
        for type in continuations.keys {
            guard let resolved = try? await selectedTrack(for: type) else { continue }
            recordAndBroadcastIfChanged(resolved, for: type)
        }
    }
    
    // MARK: - Private Helpers
    
    /// Checks whether captioning preferences are enabled in system settings.
    /// - Returns: A Boolean indicating if system captioning is turned on.
    private func systemCaptioningEnabled() -> Bool {
        guard let characteristics = MACaptionAppearanceCopyPreferredCaptioningMediaCharacteristics(.user)
            .takeRetainedValue() as? [AVMediaCharacteristic] else {
            return false
        }
        return !characteristics.isEmpty
    }
    
    /// Helper method returning the default `.off` option for caption and subtitle track types.
    /// - Parameter type: The target `AKTrackType`.
    /// - Returns: `.off` if the type is subtitle or closed caption, otherwise `nil`.
    private func offIfApplicable(_ type: AKTrackType) -> AKMediaTrackOption? {
        (type == .subtitle || type == .closedCaption) ? .off : nil
    }
    
    /// Maps an `AKTrackType` to its corresponding `AVMediaCharacteristic`.
    /// - Parameter type: The target `AKTrackType`.
    /// - Returns: The matching `AVMediaCharacteristic`.
    private func mediaCharacteristic(for type: AKTrackType) -> AVMediaCharacteristic {
        switch type {
        case .audio, .audioDescription: return .audible
        case .subtitle, .closedCaption: return .legible
        case .videoAlternative: return .visual
        }
    }
    
    /// Filters media options to isolate specialized tracks (e.g. accessibility/closed captions vs standard subtitles).
    /// - Parameters:
    ///   - options: Array of `AVMediaSelectionOption` items to filter.
    ///   - type: The target `AKTrackType`.
    /// - Returns: An array of filtered `AVMediaSelectionOption` objects matching the criteria.
    private func filterSpecialized(_ options: [AVMediaSelectionOption], for type: AKTrackType) -> [AVMediaSelectionOption] {
        switch type {
        case .closedCaption:
            // Returns accessibility/CC tracks (SDH, Closed Captions)
            return options.filter { $0.hasMediaCharacteristic(.transcribesSpokenDialogForAccessibility) }
        case .subtitle:
            // Returns regular subtitles (excludes dedicated Closed Captions)
            return options.filter { !$0.hasMediaCharacteristic(.transcribesSpokenDialogForAccessibility) }
        case .audioDescription:
            // Returns Audio Description tracks for visually impaired users
            return options.filter { $0.hasMediaCharacteristic(.describesVideoForAccessibility) }
        default:
            return options
        }
    }
    
    /// Loads or returns the cached `AVMediaSelectionGroup` for a specific track type in an asset.
    /// - Parameters:
    ///   - type: The target `AKTrackType`.
    ///   - asset: The `AVAsset` containing media options.
    /// - Returns: The corresponding `AVMediaSelectionGroup`, or `nil` if unavailable.
    /// - Throws: An `AKPlayerError.trackSelectionFailure` if group loading encounters an error.
    private func mediaGroup(for type: AKTrackType, in asset: AVAsset) async throws -> AVMediaSelectionGroup? {
        guard let playerItem else { return nil }
        let key = "\(ObjectIdentifier(playerItem).hashValue)-\(type)"
        if let cached = groupCache[key] { return cached }
        
        let characteristic = mediaCharacteristic(for: type)
        do {
            // Explicitly isolate or ensure the compiler knows this stays within actor boundaries
            let group = try await asset.loadMediaSelectionGroup(for: characteristic)
            guard let group else { return nil }
            groupCache[key] = group
            return group
        } catch {
            throw AKPlayerError.trackSelectionFailure(reason: .groupLoadFailed(type, error: error))
        }
    }
    
    /// Updates the local dictionary of active track selections.
    /// - Parameters:
    ///   - option: The newly selected track option.
    ///   - type: The associated `AKTrackType`.
    private func recordSelection(_ option: AKMediaTrackOption?, for type: AKTrackType) {
        lastKnownSelection[type] = option
    }
    
    /// Records track changes and broadcasts updates to stream listeners if the selection changed.
    /// - Parameters:
    ///   - option: The updated `AKMediaTrackOption`.
    ///   - type: The target `AKTrackType`.
    private func recordAndBroadcastIfChanged(_ option: AKMediaTrackOption?, for type: AKTrackType) {
        if lastKnownSelection[type] == option && lastKnownSelection.keys.contains(type) {
            return
        }
        
        lastKnownSelection[type] = option
        continuations[type]?.values.forEach { $0.yield(option) }
    }
    
    /// Registers an active continuation stream for track selection broadcasts.
    /// - Parameters:
    ///   - continuation: The stream continuation to append.
    ///   - id: Unique identifier for tracking subscriber life cycle.
    ///   - type: The associated `AKTrackType`.
    private func addContinuation(_ continuation: AsyncStream<AKMediaTrackOption?>.Continuation, with id: UUID, for type: AKTrackType) {
        continuations[type, default: [:]][id] = continuation
    }
    
    /// Removes a registered continuation stream subscriber.
    /// - Parameters:
    ///   - id: Unique subscriber identifier.
    ///   - type: The target `AKTrackType`.
    private func removeContinuation(_ id: UUID, for type: AKTrackType) {
        continuations[type]?.removeValue(forKey: id)
        if continuations[type]?.isEmpty == true {
            continuations.removeValue(forKey: type)
        }
    }
}
