//
//  AKMedia.swift
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

import AVFoundation
import Foundation

// MARK: - AKMedia

/// A thread-safe concrete representation of a playable media item.
public class AKMedia: NSObject, AKPlayable, @unchecked Sendable {
    
    // MARK: - Properties
    
    /// The media asset's destination URL (file path or remote stream).
    public let url: URL
    
    /// The type classification of the media item (e.g., audio, video, stream).
    public let type: AKMediaType
    
    /// Optional dictionary options used when initializing the underlying `AVURLAsset`.
    public let assetInitializationOptions: [String: Any]?
    
    /// Optional asset properties to automatically load asynchronously prior to playback.
    public let automaticallyLoadedAssetKeys: [AVPartialAsyncProperty<AVAsset>]?
    
    /// Optional static Now Playing metadata associated with the media.
    public private(set) var staticMetadata: (any AKNowPlayableStaticMetadataProtocol)?
    
    // MARK: - Initialization
    
    /// Initializes a new media item with playback properties and optional metadata.
    /// - Parameters:
    ///   - url: The media URL destination.
    ///   - type: The media type classification.
    ///   - assetInitializationOptions: Options dictionary for initializing `AVURLAsset`.
    ///   - automaticallyLoadedAssetKeys: Asset property keys to pre-load.
    ///   - staticMetadata: Static Now Playing metadata.
    public init(
        url: URL,
        type: AKMediaType,
        assetInitializationOptions: [String: Any]? = nil,
        automaticallyLoadedAssetKeys: [AVPartialAsyncProperty<AVAsset>]? = nil,
        staticMetadata: (any AKNowPlayableStaticMetadataProtocol)? = nil
    ) {
        self.url = url
        self.type = type
        self.assetInitializationOptions = assetInitializationOptions
        self.automaticallyLoadedAssetKeys = automaticallyLoadedAssetKeys
        self.staticMetadata = staticMetadata
    }
    
    deinit {
        print("Deinit called from AKMedia 👌🏼")
    }
    
    // MARK: - Public Methods
    
    /// Updates the static Now Playing metadata for the media item.
    /// - Parameter staticMetadata: The new metadata payload conforming to `AKNowPlayableStaticMetadataProtocol`.
    public func updateMetadata(_ staticMetadata: any AKNowPlayableStaticMetadataProtocol) {
        self.staticMetadata = staticMetadata
    }
}
