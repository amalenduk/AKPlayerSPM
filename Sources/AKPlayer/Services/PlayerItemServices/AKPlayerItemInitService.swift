//
//  AKPlayerItemInitService.swift
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
 https://developer.apple.com/documentation/avfoundation/avasynchronouskeyvalueloading
 https://developer.apple.com/documentation/avfoundation/avasset
 https://developer.apple.com/documentation/avfoundation/avplayeritem
 https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/MediaPlaybackGuide/Contents/Resources/en.lproj/ExploringAVFoundation/ExploringAVFoundation.html
 */

import AVFoundation

public protocol AKPlayerItemInitServiceProtocol: AnyObject {
    var media: AKPlayable { get }
    var asset: AVURLAsset? { get }
    var playerItem: AVPlayerItem? { get }
    
    // MARK: - Fine-Grained Setup Steps (Advanced Use)
    
    @discardableResult
    func createAsset() -> AVURLAsset
    
    func validateAssetPlayability() async throws
    
    @discardableResult
    func createPlayerItemFromAsset() -> AVPlayerItem
    
    // MARK: - Unified Conveniences
    
    @discardableResult
    func preparePlayerItem() async throws -> AVPlayerItem
    
    func abortAssetInitialization()
}

public final class AKPlayerItemInitService: AKPlayerItemInitServiceProtocol {
    
    // MARK: - Properties
    
    public let media: AKPlayable
    
    public private(set) var asset: AVURLAsset?
    public private(set) var playerItem: AVPlayerItem?
    
    // MARK: - Init & Deinit
    
    public init(with media: AKPlayable) {
        self.media = media
    }
    
    deinit {
        // Cleanup resources if deallocated while loading
        asset?.cancelLoading()
    }
    
    // MARK: - Public Methods
    
    @discardableResult
    public func createAsset() -> AVURLAsset {
        let asset = AVURLAsset(url: media.url, options: media.assetInitializationOptions)
        self.asset = asset
        return asset
    }
    
    public func validateAssetPlayability() async throws {
        guard let asset = asset else {
            let error = NSError(domain: "AKPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Asset must be created before validation."])
            throw AKPlayerError.assetLoadingFailed(reason: .propertyKeyLoadingFailed(error: error))
        }
        
        do {
            let (isPlayable, hasProtectedContent) = try await asset.load(.isPlayable, .hasProtectedContent)
            
            try Task.checkCancellation()
            
            guard isPlayable else {
                throw AKPlayerError.assetLoadingFailed(reason: .notPlayable)
            }
            guard !hasProtectedContent else {
                throw AKPlayerError.assetLoadingFailed(reason: .protectedContent)
            }
        } catch is CancellationError {
            // Re-throw pure CancellationError so structured task cancellation flows cleanly
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            // Map low-level network operation cancellations to standard CancellationError
            throw CancellationError()
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw AKPlayerError.assetLoadingFailed(reason: .notConnectedToInternet(error: error))
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            throw AKPlayerError.assetLoadingFailed(reason: .propertyKeyLoadingFailed(error: error))
        }
    }
    
    @discardableResult
    public func createPlayerItemFromAsset() -> AVPlayerItem {
        guard let asset = asset else {
            fatalError("Asset must be created before calling createPlayerItemFromAsset().")
        }
        
        let item: AVPlayerItem
        if let keys = media.automaticallyLoadedAssetKeys {
            item = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: keys)
        } else {
            item = AVPlayerItem(asset: asset)
        }
        
        self.playerItem = item
        return item
    }
    
    // MARK: - Unified Convenience API
    
    @discardableResult
    public func preparePlayerItem() async throws -> AVPlayerItem {
        createAsset()
        try await validateAssetPlayability()
        return createPlayerItemFromAsset()
    }
    
    public func abortAssetInitialization() {
        asset?.cancelLoading()
    }
}
