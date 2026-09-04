//
//  AKSeek.swift
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
import CoreMedia

// MARK: - AKSeek

/// Represents a media seek command containing the target position, tolerances, and completion callback.
public struct AKSeek: Equatable, Hashable, Identifiable, Sendable {
    
    /// Unique identifier for this specific seek request.
    public let id: UUID
    
    /// The target playback position.
    public let target: AKSeekTarget
    
    /// The maximum allowable time before the target time that the player may seek.
    public let toleranceBefore: CMTime
    
    /// The maximum allowable time after the target time that the player may seek.
    public let toleranceAfter: CMTime
    
    /// A completion handler invoked when the seek operation finishes or is canceled.
    /// Matches AVPlayer's native @Sendable closure signature.
    public let completionHandler: (@Sendable (Bool) -> Void)?
    
    // MARK: - Initialization
    
    /// Creates a new seek request.
    /// - Parameters:
    ///   - id: Unique identifier for this request. Defaults to a new `UUID()`.
    ///   - target: The target position to seek to.
    ///   - toleranceBefore: Tolerance before the target position. Defaults to `.positiveInfinity`.
    ///   - toleranceAfter: Tolerance after the target position. Defaults to `.positiveInfinity`.
    ///   - completionHandler: Callback executed when seeking completes or is canceled.
    public init(
        id: UUID = UUID(),
        target: AKSeekTarget,
        toleranceBefore: CMTime = .positiveInfinity,
        toleranceAfter: CMTime = .positiveInfinity,
        completionHandler: (@Sendable (Bool) -> Void)? = nil
    ) {
        self.id = id
        self.target = target
        self.toleranceBefore = toleranceBefore
        self.toleranceAfter = toleranceAfter
        self.completionHandler = completionHandler
    }
    
    // MARK: - Equatable & Hashable
    
    public static func == (lhs: AKSeek, rhs: AKSeek) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
