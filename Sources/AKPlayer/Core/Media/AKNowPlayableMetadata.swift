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
import MediaPlayer

public struct AKNowPlayableMetadata: AKNowPlayableInfoProtocol {
    
    // MARK: - Properties
    
    public var staticMetadata: AKNowPlayableStaticMetadataProtocol?
    public var dynamicMetadata: AKNowPlayableDynamicMetadataProtocol?
    
    // MARK: - Init
    
    public init(staticMetadata: AKNowPlayableStaticMetadataProtocol?,
                dynamicMetadata: AKNowPlayableDynamicMetadataProtocol?
    ) {
        self.staticMetadata = staticMetadata
        self.dynamicMetadata = dynamicMetadata
    }
}

public struct AKNowPlayableStaticMetadata: AKNowPlayableStaticMetadataProtocol {
    
    public var assetURL: URL
    public var mediaType: MPNowPlayingInfoMediaType
    public var isLiveStream: Bool
    public var title: String
    public var artist: String?
    public var artwork: Artwork?
    public var albumArtist: String?
    public var albumTitle: String?
    public var collectionIdentifier: String?
    public var externalContentIdentifier: String?
    public var externalUserProfileIdentifier: String?
    public var adTimeRanges: MPAdTimeRange?
    
    // MARK: - Init
    
    public init(assetURL: URL,
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
                adTimeRanges: MPAdTimeRange? = nil
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

public struct AKNowPlayableDynamicMetadata: AKNowPlayableDynamicMetadataProtocol {
    public var rate: Double
    public var defaultRate: Double
    public var position: Double?
    public var duration: Float?
    public var currentLanguageOptions: [MPNowPlayingInfoLanguageOption]?
    public var availableLanguageOptionGroups: [MPNowPlayingInfoLanguageOptionGroup]?
    public var chapterCount: Int?
    public var chapterNumber: Int?
    public var creditsStartTime: Double?
    public var currentPlaybackDate: NSDate?
    public var playbackProgress: Float?
    public var playbackQueueCount: Int?
    public var playbackQueueIndex: Int?
    public var serviceIdentifier: String?
    
    init(rate: Double,
         defaultRate: Double,
         position: Double? = nil,
         duration: Float? = nil,
         currentLanguageOptions: [MPNowPlayingInfoLanguageOption]? = nil,
         availableLanguageOptionGroups: [MPNowPlayingInfoLanguageOptionGroup]? = nil,
         chapterCount: Int? = nil,
         chapterNumber: Int? = nil,
         creditsStartTime: Double? = nil,
         currentPlaybackDate: NSDate? = nil,
         playbackProgress: Float? = nil,
         playbackQueueCount: Int? = nil,
         playbackQueueIndex: Int? = nil,
         serviceIdentifier: String? = nil) {
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



