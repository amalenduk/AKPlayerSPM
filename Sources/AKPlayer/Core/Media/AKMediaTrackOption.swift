//
//  AKMediaTrackOption.swift
//  Pods
//
//  Created by Amalendu Kar on 26/08/26.
//

import AVFoundation

// MARK: - AKTrackType

/// Defines the supported media track types within the player.
public enum AKTrackType: String, Sendable, Hashable, CaseIterable, Codable {
    case audio
    case subtitle
    case closedCaption
    case videoAlternative
    case audioDescription
}

// MARK: - AKMediaOptionBox

/// An internal, thread-safe wrapper box for AVFoundation's non-Sendable `AVMediaSelectionOption`.
internal struct AKMediaOptionBox: @unchecked Sendable {
    internal let option: AVMediaSelectionOption?
}

// MARK: - AKMediaTrackOption

/// Represents an available media track option (audio channel, subtitle, caption).
public struct AKMediaTrackOption: Identifiable, Hashable, Sendable {
    
    // MARK: - Public Properties
    
    public let id: String
    public let title: String
    public let languageCode: String
    public let isDefault: Bool
    
    // MARK: - Internal Properties
    
    /// Internal wrapper housing the system selection option.
    private let optionBox: AKMediaOptionBox
    
    /// The underlying system selection option. `nil` for the static `.off` option.
    internal var option: AVMediaSelectionOption? {
        optionBox.option
    }
    
    // MARK: - Initializers
    
    /// Initializes a track option wrapper from an `AVMediaSelectionOption`.
    /// - Parameters:
    ///   - option: The backing system option.
    ///   - isDefault: Flag indicating whether this option is marked as default in the asset.
    public init(option: AVMediaSelectionOption, isDefault: Bool) {
        self.optionBox = AKMediaOptionBox(option: option)
        self.title = option.displayName
        self.languageCode = option.extendedLanguageTag ?? option.locale?.identifier ?? ""
        self.isDefault = isDefault
        
        // Derive a stable, non-negative in-memory identifier
        let memoryAddress = UInt(bitPattern: ObjectIdentifier(option))
        self.id = String(memoryAddress, radix: 16)
    }
    
    /// Private initializer for representing the disabled/off state.
    private init(title: String = "Off", id: String = "__off__") {
        self.optionBox = AKMediaOptionBox(option: nil)
        self.title = title
        self.languageCode = ""
        self.isDefault = false
        self.id = id
    }
    
    // MARK: - Static Constants
    
    /// Represents a disabled track selection state (e.g., Subtitles Off).
    public static let off = AKMediaTrackOption()
    
    // MARK: - Hashable & Equatable
    
    public static func == (lhs: AKMediaTrackOption, rhs: AKMediaTrackOption) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - AKTrackSelectionInfo

/// Describes the available options and selection constraints for a target track type.
public struct AKTrackSelectionInfo: Sendable, Hashable {
    
    /// List of available track options for the specified track type.
    public let options: [AKMediaTrackOption]
    
    /// Currently selected track option, or `nil` if none selected.
    public let selected: AKMediaTrackOption?
    
    /// Flag indicating whether the system permits an empty selection (e.g., turning subtitles off).
    public let allowsEmptySelection: Bool
    
    public init(
        options: [AKMediaTrackOption],
        selected: AKMediaTrackOption?,
        allowsEmptySelection: Bool
    ) {
        self.options = options
        self.selected = selected
        self.allowsEmptySelection = allowsEmptySelection
    }
}
