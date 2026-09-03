//
//  AKMediaTrackOption.swift
//  Pods
//
//  Created by Amalendu Kar on 26/08/26.
//

import AVFoundation

public enum AKTrackType {
    case audio
    case subtitle
    case closedCaption
    case videoAlternative
    case audioDescription
}

public struct AKMediaTrackOption: Identifiable {
    public let id: String
    public let title: String
    public let languageCode: String
    public let isDefault: Bool
    /// Nil only for `.off`. Not part of identity — AVMediaSelectionOption isn't
    /// reliably Hashable across OS versions, so we mint our own stable id instead.
    internal let option: AVMediaSelectionOption?
    
    init(option: AVMediaSelectionOption, isDefault: Bool) {
        self.option = option
        self.title = option.displayName
        self.languageCode = option.extendedLanguageTag ?? option.locale?.identifier ?? ""
        self.isDefault = isDefault
        // ObjectIdentifier isn't stable across process launches, but option instances
        // are also not Codable/persistable — callers persist languageCode instead.
        self.id = "\(ObjectIdentifier(option).hashValue)"
    }
    
    private init(off: Void) {
        self.option = nil
        self.title = "Off"
        self.languageCode = ""
        self.isDefault = false
        self.id = "__off__"
    }
    
    public static let off = AKMediaTrackOption(off: ())
}

extension AKMediaTrackOption: Hashable {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Result of a track query, including selection constraints the UI needs to respect.
public struct AKTrackSelectionInfo {
    public let options: [AKMediaTrackOption]
    public let selected: AKMediaTrackOption?
    /// If false, "Off" must not be offered/selectable — the content requires a selection
    /// (e.g. forced-narrative subtitles).
    public let allowsEmptySelection: Bool
}
