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

// MARK: - AKPlayerItemInitServiceProtocol

/// Protocol defining media asset initialization, playability validation, and AVPlayerItem construction routines.
@MainActor
public protocol AKPlayerItemInitServiceProtocol: AnyObject {
    
    /// The target playable media item backing this initialization pipeline.
    var media: any AKPlayable { get }
    
    /// The loaded URL asset backing the current initialization process.
    var asset: AVURLAsset? { get }
    
    /// The instantiated player item created from the validated asset.
    var playerItem: AVPlayerItem? { get }
    
    // MARK: - Fine-Grained Setup Steps
    
    /// Instantiates the underlying `AVURLAsset` for the assigned media.
    /// - Returns: The newly initialized `AVURLAsset`.
    @discardableResult
    func createAsset() -> AVURLAsset
    
    /// Asynchronously validates key asset properties (`isPlayable`, `hasProtectedContent`).
    /// - Throws: `AKPlayerError` if validation fails, or `CancellationError` if cancelled.
    func validateAssetPlayability() async throws
    
    /// Constructs an `AVPlayerItem` from the initialized `AVURLAsset`.
    /// - Returns: The configured `AVPlayerItem`.
    @discardableResult
    func createPlayerItemFromAsset() -> AVPlayerItem
    
    // MARK: - Unified Conveniences
    
    /// Executes the full initialization pipeline: creates asset, validates playability, and constructs player item.
    /// - Returns: A fully prepared `AVPlayerItem`.
    /// - Throws: An `AKPlayerError` or `CancellationError` if any pipeline stage fails.
    @discardableResult
    func preparePlayerItem() async throws -> AVPlayerItem
    
    /// Aborts active asset property loading and cancels pending asynchronous tasks.
    func abortAssetInitialization()
}

// MARK: - AKPlayerItemInitService

/// Service responsible for asynchronous AVAsset loading, playability checks, and AVPlayerItem instantiation.
@MainActor
public final class AKPlayerItemInitService: AKPlayerItemInitServiceProtocol {
    
    // MARK: - Properties
    
    /// The target playable media item backing this initialization pipeline.
    public let media: any AKPlayable
    
    /// The loaded URL asset backing the current initialization process.
    public private(set) var asset: AVURLAsset?
    
    /// The instantiated player item created from the validated asset.
    public private(set) var playerItem: AVPlayerItem?
    
    // MARK: - Initialization & Deinitialization
    
    /// Initializes an asset initialization service instance for a specific media item.
    /// - Parameter media: The target playable media context.
    public init(with media: any AKPlayable) {
        self.media = media
    }
    
    deinit {
        // Since asset might be a reference type, cancel loading safely.
        // In Swift 6+, accessing stored properties from deinit requires care,
        // but calling methods on non-isolated or safely captured classes is supported.
        asset?.cancelLoading()
    }
    
    // MARK: - Public Pipeline Methods
    
    /// Instantiates the underlying `AVURLAsset` for the assigned media.
    /// - Returns: The newly initialized `AVURLAsset`.
    @discardableResult
    public func createAsset() -> AVURLAsset {
        let asset = AVURLAsset(url: media.url, options: media.assetInitializationOptions)
        self.asset = asset
        return asset
    }
    
    /// Asynchronously validates key asset properties (`isPlayable`, `hasProtectedContent`).
    /// - Throws: `AKPlayerError` if validation fails, or `CancellationError` if cancelled.
    public func validateAssetPlayability() async throws {
        guard let asset else {
            let error = NSError(
                domain: "AKPlayer",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Asset must be created before validation."]
            )
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
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw AKPlayerError.assetLoadingFailed(reason: .notConnectedToInternet(error: error))
        } catch let error as AKPlayerError {
            throw error
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            throw AKPlayerError.assetLoadingFailed(reason: .propertyKeyLoadingFailed(error: error))
        }
    }
    
    /// Constructs an `AVPlayerItem` from the initialized `AVURLAsset`.
    /// - Returns: The configured `AVPlayerItem`.
    @discardableResult
    public func createPlayerItemFromAsset() -> AVPlayerItem {
        guard let asset else {
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
    
    /// Executes the full initialization pipeline: creates asset, validates playability, and constructs player item.
    /// - Returns: A fully prepared `AVPlayerItem`.
    /// - Throws: An `AKPlayerError` or `CancellationError` if any pipeline stage fails.
    @discardableResult
    public func preparePlayerItem() async throws -> AVPlayerItem {
        createAsset()
        try await validateAssetPlayability()
        return createPlayerItemFromAsset()
    }
    
    /// Aborts active asset property loading and cancels pending asynchronous tasks.
    public func abortAssetInitialization() {
        asset?.cancelLoading()
    }
}
