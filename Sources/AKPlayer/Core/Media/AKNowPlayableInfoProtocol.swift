//
//  AKPlayableMetadata.swift
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

public protocol AKNowPlayableInfoProtocol {
    var staticMetadata: AKNowPlayableStaticMetadataProtocol? { get set }
    var dynamicMetadata: AKNowPlayableDynamicMetadataProtocol? { get set }
}

public extension AKNowPlayableInfoProtocol {
    
    func getNowPlayingInfo() -> [String: Any]? {
        let staticInfo = staticMetadata?.getNowPlayableStaticMetadata()
        let dynamicInfo = dynamicMetadata?.getNowPlayableDynamicMetadata()
        
        guard !((staticInfo == nil)
                && (dynamicInfo == nil)) else { return nil }
        return (staticInfo ?? [:]).merging(dict: dynamicInfo ?? [:])
    }
}

public enum Artwork {
    case image(UIImage)
    case data(Data)
    case artwork(MPMediaItemArtwork)
}

public protocol AKNowPlayableStaticMetadataProtocol {
    var assetURL: URL { get set }                            // MPNowPlayingInfoPropertyAssetURL
    var mediaType: MPNowPlayingInfoMediaType { get set }     // MPNowPlayingInfoPropertyMediaType
    var isLiveStream: Bool { get set }                       // MPNowPlayingInfoPropertyIsLiveStream
    var title: String { get set }                            // MPMediaItemPropertyTitle
    var artist: String? { get set }                          // MPMediaItemPropertyArtist
    var artwork: Artwork? { get set }                        // MPMediaItemPropertyArtwork
    var albumArtist: String? { get set }                     // MPMediaItemPropertyAlbumArtist
    var albumTitle: String? { get set }                      // MPMediaItemPropertyAlbumTitle
    var collectionIdentifier: String? { get set }            // MPNowPlayingInfoCollectionIdentifier
    var externalContentIdentifier: String? { get set }       // MPNowPlayingInfoPropertyExternalContentIdentifier
    var externalUserProfileIdentifier: String? { get set }   // MPNowPlayingInfoPropertyExternalUserProfileIdentifier
    var adTimeRanges: MPAdTimeRange? { get set }             // MPNowPlayingInfoPropertyAdTimeRanges
}

extension AKNowPlayableStaticMetadataProtocol {
    
    public var itemArtwork: MPMediaItemArtwork? {
        guard let artwork = artwork else { return nil }
        switch artwork {
        case .image(let image):
            let boundsSize = image.size.width > 0 && image.size.height > 0 ? image.size : CGSize(width: 300, height: 300)
            return MPMediaItemArtwork(boundsSize: boundsSize, requestHandler: { _ in
                return image
            })
        case .data(let data):
            guard let image = UIImage(data: data) else { return nil }
            let boundsSize = image.size.width > 0 && image.size.height > 0 ? image.size : CGSize(width: 300, height: 300)
            return MPMediaItemArtwork(boundsSize: boundsSize, requestHandler: { _ in
                return image
            })
        case .artwork(let artwork):
            return artwork
        }
    }
}

public protocol AKNowPlayableDynamicMetadataProtocol {
    var rate: Double { get set }                                                             // MPNowPlayingInfoPropertyPlaybackRate
    var defaultRate: Double { get set }                                                      // MPNowPlayingInfoPropertyDefaultPlaybackRate
    var position: Double? { get set }                                                        // MPNowPlayingInfoPropertyElapsedPlaybackTime
    var duration: Float? { get set }                                                         // MPMediaItemPropertyPlaybackDuration
    var currentLanguageOptions: [MPNowPlayingInfoLanguageOption]? { get set }                // MPNowPlayingInfoPropertyCurrentLanguageOptions
    var availableLanguageOptionGroups: [MPNowPlayingInfoLanguageOptionGroup]? { get set }    // MPNowPlayingInfoPropertyAvailableLanguageOptions
    var chapterCount: Int? { get set }                                                       // MPNowPlayingInfoPropertyChapterCount
    var chapterNumber: Int? { get set }                                                      // MPNowPlayingInfoPropertyChapterNumber
    var creditsStartTime: Double? { get set }                                                // MPNowPlayingInfoPropertyCreditsStartTime
    var currentPlaybackDate: NSDate? { get set }                                             // MPNowPlayingInfoPropertyCurrentPlaybackDate
    var playbackProgress: Float? { get set }                                                 // MPNowPlayingInfoPropertyPlaybackProgress
    var playbackQueueCount: Int? { get set }                                                 // MPNowPlayingInfoPropertyPlaybackQueueCount
    var playbackQueueIndex: Int? { get set }                                                 // MPNowPlayingInfoPropertyPlaybackQueueIndex
    var serviceIdentifier: String? { get set }                                               // MPNowPlayingInfoPropertyServiceIdentifier
}

public extension AKNowPlayableStaticMetadataProtocol {
    
    func getNowPlayableStaticMetadata() -> [String: Any] {
        var nowPlayingInfo = [String: Any]()
        
        nowPlayingInfo[MPNowPlayingInfoPropertyAssetURL] = assetURL
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = mediaType.rawValue
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = isLiveStream
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        nowPlayingInfo[MPMediaItemPropertyAlbumArtist] = albumArtist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = albumTitle
        
        nowPlayingInfo[MPMediaItemPropertyArtwork] = itemArtwork
        
        return nowPlayingInfo
    }
}

public extension AKNowPlayableDynamicMetadataProtocol {
    
    func getNowPlayableDynamicMetadata() -> [String: Any] {
        var nowPlayingInfo = [String: Any]()
        
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = defaultRate
        nowPlayingInfo[MPNowPlayingInfoPropertyCurrentLanguageOptions] = currentLanguageOptions
        nowPlayingInfo[MPNowPlayingInfoPropertyAvailableLanguageOptions] = availableLanguageOptionGroups
        
        if let duration = duration, duration.isNormal {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        }
        
        return nowPlayingInfo
    }
}
