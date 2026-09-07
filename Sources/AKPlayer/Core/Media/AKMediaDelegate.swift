//
//  AKMediaDelegate.swift
//  AKPlayer
//
//  Copyright (c) 2020 Amalendu Kar
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE
//  SOFTWARE.
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

extension AKMediaDelegate {
  public func akMedia(
    _: any AKPlayable,
    didChangeState _: AKPlayableState
  ) {}
  public func akMedia(
    _: any AKPlayable,
    didChangeItemDurationTo _: CMTime
  ) {}
  public func akMedia(
    _: any AKPlayable,
    didChangeTimebaseTo _: CMTimebase?
  ) {}
  public func akMedia(
    _: any AKPlayable,
    didChangeCapability _: AKMediaCapability,
    to _: Bool
  ) {}
  public func akMedia(
    _: any AKPlayable,
    didChangeLoadedTimeRangesTo _: [CMTimeRange]
  ) {}
  public func akMedia(
    _: any AKPlayable,
    didChangeSeekableTimeRangesTo _: [CMTimeRange]
  ) {}
  public func akMedia(
    _: any AKPlayable,
    didChangeTracksTo _: [AVPlayerItemTrack]
  ) {}
  public func akMedia(
    _: any AKPlayable,
    didChangePresentationSizeTo _: CGSize
  ) {}
}
