//
//  AKNowPlayableMetadata.swift
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
@preconcurrency import MediaPlayer

// MARK: - AKNowPlayableMetadata

/// A concrete container holding combined static and dynamic metadata payload sources for MPNowPlayingInfoCenter.
public struct AKNowPlayableMetadata: AKNowPlayableInfoProtocol {
    
    // MARK: - Properties
    
    /// The static metadata describing the media asset.
    public var staticMetadata: (any AKNowPlayableStaticMetadataProtocol)?
    
    /// The dynamic metadata reflecting live playback state.
    public var dynamicMetadata: (any AKNowPlayableDynamicMetadataProtocol)?
    
    // MARK: - Init
    
    /// Initializes a combined metadata instance.
    /// - Parameters:
    ///   - staticMetadata: Immutable or rarely changed metadata payload.
    ///   - dynamicMetadata: Real-time changeable playback state metadata payload.
    public init(
        staticMetadata: (any AKNowPlayableStaticMetadataProtocol)? = nil,
        dynamicMetadata: (any AKNowPlayableDynamicMetadataProtocol)? = nil
    ) {
        self.staticMetadata = staticMetadata
        self.dynamicMetadata = dynamicMetadata
    }
}

// MARK: - AKNowPlayableStaticMetadata

/// A concrete struct implementing static metadata properties for Now Playing displays.
public struct AKNowPlayableStaticMetadata: AKNowPlayableStaticMetadataProtocol {
    
    // MARK: - Properties
    
    /// Destination asset URL.
    public var assetURL: URL
    
    /// Media type classification.
    public var mediaType: MPNowPlayingInfoMediaType
    
    /// Indicates if the item is a live stream.
    public var isLiveStream: Bool
    
    /// The primary title.
    public var title: String
    
    /// The primary artist.
    public var artist: String?
    
    /// Associated media artwork source.
    public var artwork: Artwork?
    
    /// The album artist.
    public var albumArtist: String?
    
    /// The album title.
    public var albumTitle: String?
    
    /// Collection identifier.
    public var collectionIdentifier: String?
    
    /// External content identifier.
    public var externalContentIdentifier: String?
    
    /// External user profile identifier.
    public var externalUserProfileIdentifier: String?
    
    /// Time ranges for advertisements.
    public var adTimeRanges: [MPAdTimeRange]?
    
    // MARK: - Init
    
    /// Initializes a static metadata payload container.
    /// - Parameters:
    ///   - assetURL: Destination asset URL.
    ///   - mediaType: Media type classification.
    ///   - isLiveStream: Flag indicating if the item is a live stream.
    ///   - title: Primary item title.
    ///   - artist: Primary artist name.
    ///   - artwork: Visual artwork payload.
    ///   - albumArtist: Album artist name.
    ///   - albumTitle: Album title.
    ///   - collectionIdentifier: Collection identifier.
    ///   - externalContentIdentifier: External content identifier.
    ///   - externalUserProfileIdentifier: External user profile identifier.
    ///   - adTimeRanges: Time ranges for advertisements.
    public init(
        assetURL: URL,
        mediaType: MPNowPlayingInfoMediaType,
        isLiveStream: Bool,
        title: String,
        artist: String? = nil,
        artwork: Artwork? = nil,
        albumArtist: String? = nil,
        albumTitle: String? = nil,
        collectionIdentifier: String? = nil,
        externalContentIdentifier: String? = nil,
        externalUserProfileIdentifier: String? = nil,
        adTimeRanges: [MPAdTimeRange]? = nil
    ) {
        self.assetURL = assetURL
        self.mediaType = mediaType
        self.isLiveStream = isLiveStream
        self.title = title
        self.artist = artist
        self.artwork = artwork
        self.albumArtist = albumArtist
        self.albumTitle = albumTitle
        self.collectionIdentifier = collectionIdentifier
        self.externalContentIdentifier = externalContentIdentifier
        self.externalUserProfileIdentifier = externalUserProfileIdentifier
        self.adTimeRanges = adTimeRanges
    }
}

// MARK: - AKNowPlayableDynamicMetadata

/// A concrete struct implementing dynamic metadata properties for Now Playing displays.
public struct AKNowPlayableDynamicMetadata: AKNowPlayableDynamicMetadataProtocol {
    
    // MARK: - Properties
    
    /// Current playback speed multiplier.
    public var rate: Double
    
    /// Default intended playback rate.
    public var defaultRate: Double
    
    /// Elapsed playback time in seconds.
    public var position: Double?
    
    /// Total duration of the media in seconds.
    public var duration: Float?
    
    /// Active language options.
    public var currentLanguageOptions: [MPNowPlayingInfoLanguageOption]?
    
    /// Available language options.
    public var availableLanguageOptionGroups: [MPNowPlayingInfoLanguageOptionGroup]?
    
    /// Total chapter count.
    public var chapterCount: Int?
    
    /// Current chapter index.
    public var chapterNumber: Int?
    
    /// Start offset for credits.
    public var creditsStartTime: Double?
    
    /// Current wall-clock playback timestamp.
    public var currentPlaybackDate: Date?
    
    /// Playback completion percentage.
    public var playbackProgress: Float?
    
    /// Total items in queue.
    public var playbackQueueCount: Int?
    
    /// Current index within queue.
    public var playbackQueueIndex: Int?
    
    /// Unique service identifier.
    public var serviceIdentifier: String?
    
    // MARK: - Init
    
    /// Initializes a dynamic metadata payload container.
    /// - Parameters:
    ///   - rate: Current playback speed multiplier.
    ///   - defaultRate: Default intended playback rate.
    ///   - position: Elapsed playback time in seconds.
    ///   - duration: Total duration in seconds.
    ///   - currentLanguageOptions: Active language options.
    ///   - availableLanguageOptionGroups: Available language option groups.
    ///   - chapterCount: Total chapter count.
    ///   - chapterNumber: Current chapter index.
    ///   - creditsStartTime: Start offset for credits.
    ///   - currentPlaybackDate: Current wall-clock playback timestamp.
    ///   - playbackProgress: Playback completion percentage.
    ///   - playbackQueueCount: Total items in queue.
    ///   - playbackQueueIndex: Current index within queue.
    ///   - serviceIdentifier: Unique service identifier.
    public init(
        rate: Double,
        defaultRate: Double,
        position: Double? = nil,
        duration: Float? = nil,
        currentLanguageOptions: [MPNowPlayingInfoLanguageOption]? = nil,
        availableLanguageOptionGroups: [MPNowPlayingInfoLanguageOptionGroup]? = nil,
        chapterCount: Int? = nil,
        chapterNumber: Int? = nil,
        creditsStartTime: Double? = nil,
        currentPlaybackDate: Date? = nil,
        playbackProgress: Float? = nil,
        playbackQueueCount: Int? = nil,
        playbackQueueIndex: Int? = nil,
        serviceIdentifier: String? = nil
    ) {
        self.rate = rate
        self.defaultRate = defaultRate
        self.position = position
        self.duration = duration
        self.currentLanguageOptions = currentLanguageOptions
        self.availableLanguageOptionGroups = availableLanguageOptionGroups
        self.chapterCount = chapterCount
        self.chapterNumber = chapterNumber
        self.creditsStartTime = creditsStartTime
        self.currentPlaybackDate = currentPlaybackDate
        self.playbackProgress = playbackProgress
        self.playbackQueueCount = playbackQueueCount
        self.playbackQueueIndex = playbackQueueIndex
        self.serviceIdentifier = serviceIdentifier
    }
}
