//
//   AKMediaSelectionOption.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation

// MARK: - AKMediaSelectionOption

/// A lightweight representation of a media selection option (such as audio or
/// subtitle tracks).
public struct AKMediaSelectionOption {
    // MARK: - Properties

    /// The localized display name of the media option.
    public var displayName: String

    /// A Boolean value indicating whether the option is playable.
    public var isPlayable: Bool

    /// The locale associated with the media option, if available.
    public var locale: Locale?

    /// The descriptive title of the media option, if available.
    public var title: String?

    // MARK: - Initialization

    /// Initializes a media selection option instance.
    /// - Parameters:
    ///   - displayName: The localized display name of the option.
    ///   - isPlayable: A Boolean value indicating playability.
    ///   - locale: The optional locale of the option.
    ///   - title: The optional title of the option.
    public init(
        displayName: String,
        isPlayable: Bool,
        locale: Locale?,
        title: String?
    ) {
        self.displayName = displayName
        self.isPlayable = isPlayable
        self.locale = locale
        self.title = title
    }
}
