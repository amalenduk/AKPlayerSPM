//
//   AKMediaDelegate.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import AVFoundation

@MainActor
public protocol AKMediaDelegate: AnyObject {
    func akMedia(
        _ media: any AKPlayable,
        didChangeState state: AKPlayableState
    )
    func akMedia(
        _ media: any AKPlayable,
        didChangeItemDurationTo itemDuration: CMTime
    )
    func akMedia(
        _ media: any AKPlayable,
        didChangeTimebaseTo timebase: CMTimebase?
    )
    func akMedia(
        _ media: any AKPlayable,
        didChangeCapability capability: AKMediaCapability,
        to isSupported: Bool
    )
    func akMedia(
        _ media: any AKPlayable,
        didChangeLoadedTimeRangesTo loadedTimeRanges: [CMTimeRange]
    )
    func akMedia(
        _ media: any AKPlayable,
        didChangeSeekableTimeRangesTo seekableTimeRanges: [CMTimeRange]
    )
    func akMedia(
        _ media: any AKPlayable,
        didChangeTracksTo tracks: [AVPlayerItemTrack]
    )
    func akMedia(
        _ media: any AKPlayable,
        didChangePresentationSizeTo size: CGSize
    )
}

public extension AKMediaDelegate {
    func akMedia(
        _: any AKPlayable,
        didChangeState _: AKPlayableState
    ) {}
    func akMedia(
        _: any AKPlayable,
        didChangeItemDurationTo _: CMTime
    ) {}
    func akMedia(
        _: any AKPlayable,
        didChangeTimebaseTo _: CMTimebase?
    ) {}
    func akMedia(
        _: any AKPlayable,
        didChangeCapability _: AKMediaCapability,
        to _: Bool
    ) {}
    func akMedia(
        _: any AKPlayable,
        didChangeLoadedTimeRangesTo _: [CMTimeRange]
    ) {}
    func akMedia(
        _: any AKPlayable,
        didChangeSeekableTimeRangesTo _: [CMTimeRange]
    ) {}
    func akMedia(
        _: any AKPlayable,
        didChangeTracksTo _: [AVPlayerItemTrack]
    ) {}
    func akMedia(
        _: any AKPlayable,
        didChangePresentationSizeTo _: CGSize
    ) {}
}
