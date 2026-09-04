//
//  SimpleVideoPlayerViewModel.swift
//  AKPlayerDemo
//
//  Created by Amalendu Kar on 02/09/26.
//

import SwiftUI
import AKPlayer
import AVFoundation
import Combine
import Foundation

@MainActor
public class SimpleVideoPlayerViewModel: NSObject, ObservableObject {
    public let aVplayer = AVPlayer()
    
    public lazy var player: AKPlayer = {
        var configuration = AKPlayerConfiguration()
        configuration.isNowPlayingEnabled = true
        let p = AKPlayer(player: aVplayer, configuration: configuration, audioSessionService: audioSession)
        p.player.appliesMediaSelectionCriteriaAutomatically = true
        p.delegate = self
        return p
    }()
    
    static let session = AVAudioSession.sharedInstance()
    let audioSession = AKAudioSessionService(audioSession: session)
    
    @Published public var stateDescription: String = ""
    @Published public var currentTime: Double = 0
    @Published public var duration: Double = 0
    @Published public var volume: Float = 1.0
    @Published public var isMuted: Bool = false
    @Published public var canStepForward: Bool = false
    @Published public var canStepBackward: Bool = false
    @Published public var debugInfo: String?
    @Published public var playbackRate: AKPlaybackRate = .normal
    @Published public var bufferedRanges: [ClosedRange<Double>] = []
    @Published public var isLoading: Bool = false
    @Published public var unavailableMessage: String?
    @Published public var lastLoadedMedia: AKMedia?
    @Published public var autoPlayEnabled: Bool = true
    
    // Updated track selection groups backed by AKTrackSelectionService
    @Published public var selectionGroups: [SelectionGroup] = []
    
    private nonisolated(unsafe) var timeObserverToken: Any?
    private var cancellables = Set<AnyCancellable>()
    private var clearUnavailableWorkItem: DispatchWorkItem?
    
    // MARK: - Models for Selection Sheet
    
    public struct SelectionOption: Identifiable {
        public var id: String { option.id }
        public let option: AKMediaTrackOption
        public let isSelected: Bool
    }
    
    public struct SelectionGroup: Identifiable {
        public var id: String { title }
        public let type: AKTrackType
        public let title: String
        public let info: AKTrackSelectionInfo
        public var options: [SelectionOption]
    }
    
    override public init() {
        super.init()
        try? player.prepare()
    }
    
    public func load(media: AKMedia, autoPlay: Bool) {
        self.lastLoadedMedia = media
        player.load(media: media, autoPlay: autoPlay)
    }
    
    // MARK: - Track Selection via AKTrackSelectionService
    
    @MainActor
    public func refreshSelectionGroups() {
        guard let media = player.currentMedia else {
            self.selectionGroups = []
            return
        }
        
        Task {
            let trackTypes: [(AKTrackType, String)] = [
                (.audio, "Audio"),
                (.subtitle, "Subtitles"),
                (.closedCaption, "Closed Captions"),
                (.audioDescription, "Audio Description")
            ]
            
            var groups: [SelectionGroup] = []
            let trackService = media.trackSelection
            
            for (type, title) in trackTypes {
                do {
                    let info = try await trackService.availableTracks(for: type)
                    guard !info.options.isEmpty else { continue }
                    
                    let options = info.options.map { trackOption in
                        SelectionOption(
                            option: trackOption,
                            isSelected: trackOption == info.selected
                        )
                    }
                    
                    groups.append(SelectionGroup(type: type, title: title, info: info, options: options))
                } catch {
                    print("Failed to load tracks for \(title): \(error)")
                }
            }
            
            self.selectionGroups = groups
        }
    }
    
    @MainActor
    public func select(option: SelectionOption, in group: SelectionGroup) {
        guard let media = player.currentMedia else { return }
        
        Task {
            do {
                try await media.trackSelection.select(option.option, for: group.type)
                self.refreshSelectionGroups()
            } catch {
                print("Failed to select track: \(error)")
            }
        }
    }
    
    public func play() { player.play() }
    public func pause() { player.pause() }
    public func stop() { player.stop() }
    public func setVolume(_ v: Float) { player.volume = v; volume = v }
    public func toggleMute() { player.isMuted = !player.isMuted; isMuted = player.isMuted }
    public func seek(to seconds: Double) {
        Task {
            await player.seek(to: .seconds(seconds))
        }
    }
    public func step(by count: Int) { player.step(by: count) }
    public func seekOffset(_ offset: Double) {
        Task {
            await player.seek(to: .offset(offset))
        }
    }
    public func setRate(_ rate: AKPlaybackRate) { player.play(at: .custom(rate.rate)) }
    
    public func loadAndObserveCurrentTime() {
        if let token = timeObserverToken {
            player.player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            if let dur = self.player.currentItem?.duration.seconds, dur.isFinite {
                self.duration = dur
            }
        }
    }
    
    deinit {
        //if let token = timeObserverToken { player.player.removeTimeObserver(token) }
    }
}

extension SimpleVideoPlayerViewModel: AKPlayerDelegate {
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeStateTo state: AKPlayerState) {
        DispatchQueue.main.async {
            self.stateDescription = state.description
            self.isLoading = (state == .waitingForNetwork || state == .buffering || state == .loading)
        }
    }
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeCurrentTimeTo currentTime: CMTime, for media: AKPlayable) {
        DispatchQueue.main.async { self.currentTime = currentTime.seconds }
    }
    nonisolated public func akPlayer(_ player: AKPlayer, didChangePlaybackRateTo newRate: AKPlaybackRate, from oldRate: AKPlaybackRate) {
        DispatchQueue.main.async { self.playbackRate = newRate }
    }
    nonisolated public func akPlayer(_ player: AKPlayer, didInvokeBoundaryTimeObserverAt time: CMTime, for media: any AKPlayable) {}
    nonisolated public func akPlayer(_ player: AKPlayer, didReachEndAt time: CMTime, for media: any AKPlayable) {}
    nonisolated public func akPlayer(_ player: AKPlayer, didEncounterUnavailableAction reason: AKPlayerUnavailableCommandReason) {
        DispatchQueue.main.async {
            self.clearUnavailableWorkItem?.cancel()
            self.unavailableMessage = reason.description
            let work = DispatchWorkItem { [weak self] in
                DispatchQueue.main.async { self?.unavailableMessage = nil }
            }
            self.clearUnavailableWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)
        }
    }
    nonisolated public func akPlayer(_ player: AKPlayer, didFailWith error: AKPlayerError) {}
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeVolumeTo volume: Float) {}
    nonisolated public func akPlayer(_ player: AKPlayer, didChangeMutedStatusTo isMuted: Bool) {}
}

extension SimpleVideoPlayerViewModel {
    public func akMedia(_ media: AKPlayable, didChangeItemDurationTo itemDuration: CMTime) {
        DispatchQueue.main.async {
            if itemDuration.isNumeric && itemDuration.seconds.isFinite {
                self.duration = itemDuration.seconds
            }
        }
    }
    public func akMedia(_ media: AKPlayable, didChangeCanStepForwardStatusTo canStepForward: Bool) {}
    public func akMedia(_ media: AKPlayable, didChangeCanStepBackwardStatusTo canStepBackward: Bool) {}
    public func akMedia(_ media: AKPlayable, didChangeLoadedTimeRangesTo loadedTimeRanges: [NSValue]) {
        DispatchQueue.main.async {
            guard self.duration > 0 else { self.bufferedRanges = []; return }
            let ranges = loadedTimeRanges.compactMap { (ns: NSValue) -> ClosedRange<Double>? in
                let tr = ns.timeRangeValue
                let start = tr.start.seconds
                let end = tr.start.seconds + tr.duration.seconds
                guard start.isFinite && end.isFinite else { return nil }
                return start...end
            }
            self.bufferedRanges = ranges
        }
    }
    public func akMedia(_ media: AKPlayable, didChangeSeekableTimeRangesTo seekableTimeRanges: [NSValue]) {}
}
