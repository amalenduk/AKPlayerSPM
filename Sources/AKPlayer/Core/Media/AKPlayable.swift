//
//  AKPlayable.swift
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
 https://developer.apple.com/documentation/avfoundation/avurlasset
 */

import Foundation
import AVFoundation
import MediaPlayer

// MARK: - AKPlayable Protocol

/// A protocol representing a playable media item with metadata and playback properties.
public protocol AKPlayable: AnyObject, Equatable, Sendable {
    /// The media asset's destination URL (file path or remote stream).
    var url: URL { get }
    
    /// The type classification of the media item (e.g., audio, video, stream).
    var type: AKMediaType { get }
    
    /// Optional dictionary options used when initializing the underlying `AVURLAsset`.
    var assetInitializationOptions: [String: Any]? { get }
    
    /// Optional asset properties to automatically load asynchronously prior to playback.
    var automaticallyLoadedAssetKeys: [AVPartialAsyncProperty<AVAsset>]? { get }
    
    /// Optional static Now Playing metadata associated with the media.
    var staticMetadata: (any AKNowPlayableStaticMetadataProtocol)? { get }
    
    /// Indicates whether the media item is a live stream.
    func isLive() -> Bool
    
    /// Updates the static Now Playing metadata for the media item.
    /// - Parameter staticMetadata: The new metadata payload conforming to `AKNowPlayableStaticMetadataProtocol`.
    func updateMetadata(_ staticMetadata: any AKNowPlayableStaticMetadataProtocol)
}

// MARK: - Equatable Implementation

public extension AKPlayable {
    /// Default protocol equality comparison checking identity reference or URL and media type properties.
    /// - Parameters:
    ///   - lhs: The left-hand side `AKPlayable` instance.
    ///   - rhs: The right-hand side `AKPlayable` instance.
    /// - Returns: A Boolean value indicating whether two instances are equal.
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs === rhs || (lhs.url == rhs.url && lhs.type == rhs.type)
    }
    
    /// Compares two existential instances (`any AKPlayable`) by reference or properties.
    /// - Parameter other: The target `AKPlayable` instance to compare against.
    /// - Returns: A Boolean value indicating whether the current instance matches the target.
    func isEqual(to other: any AKPlayable) -> Bool {
        return self === other || (self.url == other.url && self.type == other.type)
    }
}

// MARK: - CustomStringConvertible Defaults

public extension AKPlayable {
    /// A textual representation of the playable media item detailing its URL and type.
    var description: String {
        return "url: \(url.description) | type: \(type.description)"
    }
}

// MARK: - Live Stream Helpers

public extension AKPlayable {
    /// Default implementation determining if the item is a live stream payload.
    /// - Returns: `true` if the item represents an active live stream; otherwise, `false`.
    func isLive() -> Bool {
        guard case let AKMediaType.stream(isLive) = type, isLive else { return false }
        return true
    }
}

// MARK: - Network and Storage Helpers

public extension AKPlayable {
    /// Returns `true` if the URL represents a local file on disk.
    /// - Returns: A Boolean value indicating if the asset is stored locally.
    func isLocal() -> Bool {
        return url.isFileURL
    }
    
    /// Returns `true` if the URL scheme points to a remote network resource (HTTP, HTTPS, RTSP, RTMP, etc.).
    /// - Returns: A Boolean value indicating if the asset requires a network connection to play.
    func isOverNetwork() -> Bool {
        guard !url.isFileURL else { return false }
        guard let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https", "rtsp", "rtmp"].contains(scheme)
    }
}
