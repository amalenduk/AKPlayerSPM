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

public protocol AKPlayable: AnyObject {
    var url: URL { get }
    var type: AKMediaType { get }
    var assetInitializationOptions: [String: Any]? { get }
    var automaticallyLoadedAssetKeys: [AVPartialAsyncProperty<AVAsset>]? { get }
    var staticMetadata: AKNowPlayableStaticMetadataProtocol? { get }
    
    func isLive() -> Bool
    func updateMetadata(_ staticMetadata: AKNowPlayableStaticMetadataProtocol)
}

public extension AKPlayable {
    var description: String {
        return "url: \(url.description) | type: \(type.description)"
    }
}

public extension AKPlayable {
    func isLive() -> Bool {
        guard case let AKMediaType.stream(isLive) = type, isLive else { return false }
        return true
    }
}

public extension AKPlayable {
    /// Returns `true` if the URL represents a local file on disk.
    func isLocal() -> Bool {
        return url.isFileURL
    }
    
    /// Returns `true` if the URL scheme points to a remote network resource (HTTP, HTTPS, HLS, RTMP, etc.).
    func isOverNetwork() -> Bool {
        guard !url.isFileURL else { return false }
        guard let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https", "rtsp", "rtmp"].contains(scheme)
    }
}
