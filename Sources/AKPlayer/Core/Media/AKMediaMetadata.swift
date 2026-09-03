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

// https://developer.apple.com/documentation/avfoundation/avmetadataidentifier

import AVFoundation

public struct AKMediaMetadata {
    
    // MARK: - Properties
    
    public private(set) var accessibilityDescription: String?
    public private(set) var albumName: String?
    public private(set) var artist: String?
    public private(set) var artwork: Data?
    public private(set) var author: String?
    public private(set) var contributor: String?
    public private(set) var copyrights: String?
    public private(set) var creationDate: String?
    public private(set) var creator: String?
    public private(set) var description: String?
    public private(set) var format: String?
    public private(set) var language: String?
    public private(set) var lastModifiedDate: String?
    public private(set) var location: String?
    public private(set) var make: String?
    public private(set) var model: String?
    public private(set) var publisher: String?
    public private(set) var relation: String?
    public private(set) var software: String?
    public private(set) var source: String?
    public private(set) var subject: String?
    public private(set) var title: String?
    public private(set) var type: String?
    
    public private(set) var commonMetadata: [AVMetadataItem]?
    
    // MARK: - Init
    
    public init(with commonMetadata: [AVMetadataItem]) {
        self.commonMetadata = commonMetadata
    }
}
