//
//  AKMediaMetadata.swift
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

// MARK: - AKMediaMetadata

/// A model representing metadata extracted from media assets using common metadata identifiers.
///
/// Ref: https://developer.apple.com/documentation/avfoundation/avmetadataidentifier
public struct AKMediaMetadata {
    // MARK: - Properties

    /// Accessibility description metadata.
    public private(set) var accessibilityDescription: String?

    /// The title of the album associated with the media.
    public private(set) var albumName: String?

    /// The primary artist or performer.
    public private(set) var artist: String?

    /// Raw artwork image data.
    public private(set) var artwork: Data?

    /// Author of the content.
    public private(set) var author: String?

    /// Secondary contributors to the media item.
    public private(set) var contributor: String?

    /// Copyright statement or notice.
    public private(set) var copyrights: String?

    /// Creation timestamp or date string.
    public private(set) var creationDate: String?

    /// Creator of the asset.
    public private(set) var creator: String?

    /// Summary or description of the content.
    public private(set) var description: String?

    /// Format specification of the media item.
    public private(set) var format: String?

    /// Language code or specification.
    public private(set) var language: String?

    /// Last modification timestamp or date string.
    public private(set) var lastModifiedDate: String?

    /// Geographical location metadata.
    public private(set) var location: String?

    /// Device make or manufacturer.
    public private(set) var make: String?

    /// Device model name or number.
    public private(set) var model: String?

    /// Publishing entity or label.
    public private(set) var publisher: String?

    /// Related resource or reference metadata.
    public private(set) var relation: String?

    /// Software or application used to produce the media.
    public private(set) var software: String?

    /// Source origin of the media item.
    public private(set) var source: String?

    /// Subject matter classification.
    public private(set) var subject: String?

    /// Title of the media asset.
    public private(set) var title: String?

    /// Type descriptor or media category.
    public private(set) var type: String?

    /// Array of raw `AVMetadataItem` objects representing the common metadata set.
    public private(set) var commonMetadata: [AVMetadataItem]?

    // MARK: - Initialization

    /// Initializes a metadata instance with an array of `AVMetadataItem` objects.
    /// - Parameter commonMetadata: The collection of metadata items retrieved from an asset.
    public init(with commonMetadata: [AVMetadataItem]) {
        self.commonMetadata = commonMetadata
    }
}
