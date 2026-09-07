//
//  AKNowPlayableInfoProtocol.swift
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

import Foundation
import MediaPlayer
import UIKit

// MARK: - Now Playable Info Protocol

/// A protocol bridging static and dynamic metadata payload sources for
/// `MPNowPlayingInfoCenter`.
public protocol AKNowPlayableInfoProtocol: Sendable {
  /// The static metadata describing the media asset (e.g., title, artist,
  /// artwork).
  var staticMetadata: (any AKNowPlayableStaticMetadataProtocol)? { get set }

  /// The dynamic metadata reflecting live playback state (e.g., position,
  /// rate, duration).
  var dynamicMetadata: (any AKNowPlayableDynamicMetadataProtocol)? { get set }
}

extension AKNowPlayableInfoProtocol {
  /// Generates a consolidated dictionary suitable for populating
  /// `MPNowPlayingInfoCenter.nowPlayingInfo`.
  /// - Returns: A merged dictionary containing both static and dynamic
  /// metadata keys, or `nil` if both are empty.
  public func getNowPlayingInfo() -> [String: Any]? {
    let staticInfo = staticMetadata?.getNowPlayableStaticMetadata()
    let dynamicInfo = dynamicMetadata?.getNowPlayableDynamicMetadata()

    guard staticInfo != nil || dynamicInfo != nil else { return nil }

    var merged = staticInfo ?? [:]
    if let dynamicInfo {
      merged.merge(dynamicInfo) { _, new in new }
    }
    return merged
  }
}

// MARK: - Artwork Payload

/// Represents the visual artwork source associated with a media item.
public enum Artwork: @unchecked Sendable {
  /// Standard `UIImage` asset.
  case image(UIImage)

  /// Raw binary image data.
  case data(Data)

  /// An explicit system `MPMediaItemArtwork` instance.
  case artwork(MPMediaItemArtwork)
}

// MARK: - Static Metadata Protocol

/// A protocol defining immutable or rarely changed metadata properties for Now
/// Playing displays.
public protocol AKNowPlayableStaticMetadataProtocol: Sendable {
  /// Destination asset URL (`MPNowPlayingInfoPropertyAssetURL`).
  var assetURL: URL { get set }

  /// Media type classification (`MPNowPlayingInfoPropertyMediaType`).
  var mediaType: MPNowPlayingInfoMediaType { get set }

  /// Indicates if the item is a live stream
  /// (`MPNowPlayingInfoPropertyIsLiveStream`).
  var isLiveStream: Bool { get set }

  /// The primary title (`MPMediaItemPropertyTitle`).
  var title: String { get set }

  /// The primary artist (`MPMediaItemPropertyArtist`).
  var artist: String? { get set }

  /// Associated media artwork source (`MPMediaItemPropertyArtwork`).
  var artwork: Artwork? { get set }

  /// The album artist (`MPMediaItemPropertyAlbumArtist`).
  var albumArtist: String? { get set }

  /// The album title (`MPMediaItemPropertyAlbumTitle`).
  var albumTitle: String? { get set }

  /// Collection identifier (`MPNowPlayingInfoCollectionIdentifier`).
  var collectionIdentifier: String? { get set }

  /// External content identifier
  /// (`MPNowPlayingInfoPropertyExternalContentIdentifier`).
  var externalContentIdentifier: String? { get set }

  /// External user profile identifier
  /// (`MPNowPlayingInfoPropertyExternalUserProfileIdentifier`).
  var externalUserProfileIdentifier: String? { get set }

  /// Time ranges for advertisements (`MPNowPlayingInfoPropertyAdTimeRanges`).
  var adTimeRanges: [MPAdTimeRange]? { get set }
}

extension AKNowPlayableStaticMetadataProtocol {
  /// Computes or retrieves the standard `MPMediaItemArtwork` representation.
  public var itemArtwork: MPMediaItemArtwork? {
    guard let artwork else { return nil }
    switch artwork {
    case let .image(image):
      let boundsSize =
        image.size.width > 0 && image.size.height > 0
        ? image
          .size
        : CGSize(
          width: 300,
          height: 300
        )
      return MPMediaItemArtwork(boundsSize: boundsSize) { _ in image }
    case let .data(data):
      guard let image = UIImage(data: data) else { return nil }
      let boundsSize =
        image.size.width > 0 && image.size.height > 0
        ? image
          .size
        : CGSize(
          width: 300,
          height: 300
        )
      return MPMediaItemArtwork(boundsSize: boundsSize) { _ in image }
    case let .artwork(artwork):
      return artwork
    }
  }

  /// Converts all static metadata properties into key-value pairs for
  /// `MPNowPlayingInfoCenter`.
  public func getNowPlayableStaticMetadata() -> [String: Any] {
    var nowPlayingInfo = [String: Any]()

    nowPlayingInfo[MPNowPlayingInfoPropertyAssetURL] = assetURL
    nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = mediaType.rawValue
    nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = isLiveStream
    nowPlayingInfo[MPMediaItemPropertyTitle] = title
    nowPlayingInfo[MPMediaItemPropertyArtist] = artist
    nowPlayingInfo[MPMediaItemPropertyAlbumArtist] = albumArtist
    nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = albumTitle
    nowPlayingInfo[MPNowPlayingInfoCollectionIdentifier] =
      collectionIdentifier
    nowPlayingInfo[MPNowPlayingInfoPropertyExternalContentIdentifier] =
      externalContentIdentifier
    nowPlayingInfo[MPNowPlayingInfoPropertyExternalUserProfileIdentifier] =
      externalUserProfileIdentifier

    if let adTimeRanges {
      nowPlayingInfo[MPNowPlayingInfoPropertyAdTimeRanges] = adTimeRanges
    }

    if let itemArtwork {
      nowPlayingInfo[MPMediaItemPropertyArtwork] = itemArtwork
    }

    return nowPlayingInfo
  }
}

// MARK: - Dynamic Metadata Protocol

/// A protocol defining real-time changeable metadata properties for Now Playing
/// displays.
public protocol AKNowPlayableDynamicMetadataProtocol: Sendable {
  /// Current playback speed multiplier
  /// (`MPNowPlayingInfoPropertyPlaybackRate`).
  var rate: Double { get set }

  /// Default intended playback rate
  /// (`MPNowPlayingInfoPropertyDefaultPlaybackRate`).
  var defaultRate: Double { get set }

  /// Elapsed playback time in seconds
  /// (`MPNowPlayingInfoPropertyElapsedPlaybackTime`).
  var position: Double? { get set }

  /// Total duration of the media in seconds
  /// (`MPMediaItemPropertyPlaybackDuration`).
  var duration: Float? { get set }

  /// Active language options
  /// (`MPNowPlayingInfoPropertyCurrentLanguageOptions`).
  var currentLanguageOptions: [MPNowPlayingInfoLanguageOption]? { get set }

  /// Available language options
  /// (`MPNowPlayingInfoPropertyAvailableLanguageOptions`).
  var availableLanguageOptionGroups: [MPNowPlayingInfoLanguageOptionGroup]? {
    get set
  }

  /// Total chapter count (`MPNowPlayingInfoPropertyChapterCount`).
  var chapterCount: Int? { get set }

  /// Current chapter index (`MPNowPlayingInfoPropertyChapterNumber`).
  var chapterNumber: Int? { get set }

  /// Start offset for credits (`MPNowPlayingInfoPropertyCreditsStartTime`).
  var creditsStartTime: Double? { get set }

  /// Current wall-clock playback timestamp
  /// (`MPNowPlayingInfoPropertyCurrentPlaybackDate`).
  var currentPlaybackDate: Date? { get set }

  /// Playback completion percentage
  /// (`MPNowPlayingInfoPropertyPlaybackProgress`).
  var playbackProgress: Float? { get set }

  /// Total items in queue (`MPNowPlayingInfoPropertyPlaybackQueueCount`).
  var playbackQueueCount: Int? { get set }

  /// Current index within queue
  /// (`MPNowPlayingInfoPropertyPlaybackQueueIndex`).
  var playbackQueueIndex: Int? { get set }

  /// Unique service identifier (`MPNowPlayingInfoPropertyServiceIdentifier`).
  var serviceIdentifier: String? { get set }
}

// MARK: - Dynamic Metadata Serialization Extension

extension AKNowPlayableDynamicMetadataProtocol {
  /// Converts all dynamic metadata properties into key-value pairs for
  /// `MPNowPlayingInfoCenter`.
  public func getNowPlayableDynamicMetadata() -> [String: Any] {
    var nowPlayingInfo = [String: Any]()

    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate
    nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] =
      defaultRate
    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position

    if let duration, duration.isNormal {
      nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
    }

    nowPlayingInfo[MPNowPlayingInfoPropertyCurrentLanguageOptions] =
      currentLanguageOptions
    nowPlayingInfo[MPNowPlayingInfoPropertyAvailableLanguageOptions] =
      availableLanguageOptionGroups
    nowPlayingInfo[MPNowPlayingInfoPropertyChapterCount] = chapterCount
    nowPlayingInfo[MPNowPlayingInfoPropertyChapterNumber] = chapterNumber
    nowPlayingInfo[MPNowPlayingInfoPropertyCreditsStartTime] =
      creditsStartTime
    nowPlayingInfo[MPNowPlayingInfoPropertyCurrentPlaybackDate] =
      currentPlaybackDate
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackProgress] =
      playbackProgress
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueCount] =
      playbackQueueCount
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackQueueIndex] =
      playbackQueueIndex
    nowPlayingInfo[MPNowPlayingInfoPropertyServiceIdentifier] =
      serviceIdentifier

    return nowPlayingInfo
  }
}
