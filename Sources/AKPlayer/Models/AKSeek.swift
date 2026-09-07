//
//   AKSeek.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import CoreMedia
import Foundation

// MARK: - AKSeek

/// Represents a media seek command containing the target position, tolerances,
/// and completion callback.
public struct AKSeek: Equatable, Hashable, Identifiable, Sendable {
    // MARK: - Properties

    /// Unique identifier for this specific seek request.
    public let id: UUID

    /// The target playback position.
    public let target: AKSeekTarget

    /// The maximum allowable time before the target time that the player may
    /// seek.
    public let toleranceBefore: CMTime

    /// The maximum allowable time after the target time that the player may
    /// seek.
    public let toleranceAfter: CMTime

    /// A completion handler invoked when the seek operation finishes or is
    /// canceled.
    /// Matches AVPlayer's native @Sendable closure signature.
    public let completionHandler: (@Sendable (Bool) -> Void)?

    // MARK: - Initialization

    /// Creates a new seek request.
    /// - Parameters:
    ///   - id: Unique identifier for this request. Defaults to a new `UUID()`.
    ///   - target: The target position to seek to.
    ///   - toleranceBefore: Tolerance before the target position. Defaults to
    /// `.positiveInfinity`.
    ///   - toleranceAfter: Tolerance after the target position. Defaults to
    /// `.positiveInfinity`.
    ///   - completionHandler: Callback executed when seeking completes or is
    /// canceled.
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
