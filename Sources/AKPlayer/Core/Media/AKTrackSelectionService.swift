//
//  AKTrackSelectionService.swift
//  Pods
//
//  Created by Amalendu Kar on 26/08/26.
//

import Foundation
import AVFoundation
import MediaAccessibility

public protocol AKTrackSelectionServiceProtocol: Sendable {
    func availableTracks(for type: AKTrackType) async throws -> AKTrackSelectionInfo
    func selectedTrack(for type: AKTrackType) async throws -> AKMediaTrackOption?
    func select(_ option: AKMediaTrackOption?, for type: AKTrackType) async throws
    func selectPreferredTrack(for type: AKTrackType) async throws
    
    func resetSession() async
    
    func selectionChanges(for type: AKTrackType) -> AsyncStream<AKMediaTrackOption?>
}

public actor AKTrackSelectionService: AKTrackSelectionServiceProtocol {
    
    // MARK: - Properties
    
    private var groupCache: [String: AVMediaSelectionGroup] = [:]
    private var continuations: [AKTrackType: [UUID: AsyncStream<AKMediaTrackOption?>.Continuation]] = [:]
    private var lastKnownSelection: [AKTrackType: AKMediaTrackOption?] = [:]
    private let playerItemProvider: @Sendable () -> AVPlayerItem?
    
    private var playerItem: AVPlayerItem {
        get throws {
            guard let item = playerItemProvider() else {
                throw AKPlayerError.noItemToPlay
            }
            return item
        }
    }
    
    private var externalChangeObserver: NSObjectProtocol?
    
    // MARK: - Init & Deinit
    
    public init(playerItemProvider: @escaping @Sendable () -> AVPlayerItem?) {
        self.playerItemProvider = playerItemProvider
        
        // Start observing external changes
        Task { await self.startObservingExternalChanges() }
    }
    
    deinit {
        if let externalChangeObserver {
            NotificationCenter.default.removeObserver(externalChangeObserver)
        }
    }
    
    // MARK: - Public API
    
    public func availableTracks(for type: AKTrackType) async throws -> AKTrackSelectionInfo {
        let currentItem = try playerItem
        guard let group = try await mediaGroup(for: type, in: currentItem.asset) else {
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
    
    public func selectedTrack(for type: AKTrackType) async throws -> AKMediaTrackOption? {
        let currentItem = try playerItem
        guard let group = try await mediaGroup(for: type, in: currentItem.asset) else {
            return offIfApplicable(type)
        }
        
        guard let selectedOption = await currentItem.currentMediaSelection.selectedMediaOption(in: group) else {
            return offIfApplicable(type)
        }
        
        return AKMediaTrackOption(option: selectedOption, isDefault: selectedOption == group.defaultOption)
    }
    
    public func select(_ option: AKMediaTrackOption?, for type: AKTrackType) async throws {
        let currentItem = try playerItem
        guard let group = try await mediaGroup(for: type, in: currentItem.asset) else { return }
        
        let targetOption = option?.option
        
        if targetOption == nil && !group.allowsEmptySelection {
            throw AKPlayerError.trackSelectionFailure(reason: .emptySelectionForbidden(type))
        }
        
        // AVPlayerItem selection updates must execute on the Main Thread
        await MainActor.run {
            if let mediaOption = targetOption {
                currentItem.select(mediaOption, in: group)
            } else {
                currentItem.select(nil, in: group)
            }
        }
        
        let resolved = try await selectedTrack(for: type)
        recordAndBroadcastIfChanged(resolved, for: type)
    }
    
    public func selectPreferredTrack(for type: AKTrackType) async throws {
        let info = try await availableTracks(for: type)
        guard !info.options.isEmpty else { return }
        
        if (type == .subtitle || type == .closedCaption), !systemCaptioningEnabled() {
            if info.allowsEmptySelection {
                try await select(.off, for: type)
            }
            return
        }
        
        let asset = try await playerItem.asset
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
    
    public func resetSession() async {
        // 1. Clear cached AVMediaSelectionGroup instances
        groupCache.removeAll()
        
        // 2. Clear stale track selection states
        lastKnownSelection.removeAll()
        
        // 3. Remove existing notification observer if any
        if let externalChangeObserver {
            NotificationCenter.default.removeObserver(externalChangeObserver)
            self.externalChangeObserver = nil
        }
        
        // 4. Re-bind external change observation with the current player item
        startObservingExternalChanges()
    }
    
    public nonisolated func selectionChanges(for type: AKTrackType) -> AsyncStream<AKMediaTrackOption?> {
        AsyncStream { continuation in
            let id = UUID()
            
            // Asynchronously register the continuation inside actor-isolated state
            Task {
                await self.addContinuation(continuation, with: id, for: type)
                
                // Seed stream with initial value
                if let current = try? await self.selectedTrack(for: type) {
                    continuation.yield(current)
                    await self.recordSelection(current, for: type)
                }
            }
            
            // Clean up when caller cancels subscription
            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeContinuation(id, for: type)
                }
            }
        }
    }
    
    // MARK: - External Change Observation
    
    private func startObservingExternalChanges() {
        guard let currentItem = try? playerItem else { return }
        
        externalChangeObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.mediaSelectionDidChangeNotification,
            object: currentItem,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            Task { [weak self] in
                await self?.handleExternalChangeNotification()
            }
        }
    }
    
    private func handleExternalChangeNotification() async {
        for type in continuations.keys {
            guard let resolved = try? await selectedTrack(for: type) else { continue }
            recordAndBroadcastIfChanged(resolved, for: type)
        }
    }
    
    // MARK: - Helpers
    
    private func systemCaptioningEnabled() -> Bool {
        guard let characteristics = MACaptionAppearanceCopyPreferredCaptioningMediaCharacteristics(.user)
            .takeRetainedValue() as? [AVMediaCharacteristic] else {
            return false
        }
        return !characteristics.isEmpty
    }
    
    private func offIfApplicable(_ type: AKTrackType) -> AKMediaTrackOption? {
        (type == .subtitle || type == .closedCaption) ? .off : nil
    }
    
    private func mediaCharacteristic(for type: AKTrackType) -> AVMediaCharacteristic {
        switch type {
        case .audio, .audioDescription: return .audible
        case .subtitle, .closedCaption: return .legible
        case .videoAlternative: return .visual
        }
    }
    
    private func filterSpecialized(_ options: [AVMediaSelectionOption], for type: AKTrackType) -> [AVMediaSelectionOption] {
        switch type {
        case .closedCaption:
            // Returns only Accessibility/CC tracks (SDH, Closed Captions)
            return options.filter { $0.hasMediaCharacteristic(.transcribesSpokenDialogForAccessibility) }
        case .subtitle:
            // Returns regular subtitles (excludes dedicated Closed Captions)
            return options.filter { !$0.hasMediaCharacteristic(.transcribesSpokenDialogForAccessibility) }
        case .audioDescription:
            // Returns only Audio Description tracks for visually impaired
            return options.filter { $0.hasMediaCharacteristic(.describesVideoForAccessibility) }
        default:
            return options
        }
    }
    
    private func mediaGroup(for type: AKTrackType, in asset: AVAsset) async throws -> AVMediaSelectionGroup? {
        let currentItem = try playerItem
        let key = "\(ObjectIdentifier(currentItem).hashValue)-\(type)"
        if let cached = groupCache[key] { return cached }
        
        let characteristic = mediaCharacteristic(for: type)
        do {
            guard let group = try await asset.loadMediaSelectionGroup(for: characteristic) else {
                return nil
            }
            groupCache[key] = group
            return group
        } catch {
            throw AKPlayerError.trackSelectionFailure(reason: .groupLoadFailed(type, error: error))
        }
    }
    
    private func recordSelection(_ option: AKMediaTrackOption?, for type: AKTrackType) {
        lastKnownSelection[type] = option
    }
    
    private func recordAndBroadcastIfChanged(_ option: AKMediaTrackOption?, for type: AKTrackType) {
        // Correctly guards against nil == nil updates
        if lastKnownSelection[type] == option && lastKnownSelection.keys.contains(type) {
            return
        }
        
        lastKnownSelection[type] = option
        continuations[type]?.values.forEach { $0.yield(option) }
    }
    
    private func addContinuation(_ continuation: AsyncStream<AKMediaTrackOption?>.Continuation, with id: UUID, for type: AKTrackType) {
        continuations[type, default: [:]][id] = continuation
    }
    
    private func removeContinuation(_ id: UUID, for type: AKTrackType) {
        continuations[type]?.removeValue(forKey: id)
        if continuations[type]?.isEmpty == true {
            continuations.removeValue(forKey: type)
        }
    }
}
