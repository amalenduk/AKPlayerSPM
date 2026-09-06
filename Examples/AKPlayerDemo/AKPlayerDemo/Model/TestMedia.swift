//
//  TestMedia.swift
//  AKPlayerDemo
//
//  Created by Amalendu Kar on 02/09/26.
//

import Foundation
import AKPlayer

public enum TestMediaKind: String, Codable {
    case clip, live
}

public struct TestMedia: Identifiable, Codable {
    public var id = UUID()
    public let name: String
    public let url: URL?
    public let kind: TestMediaKind
    public let isPlayable: Bool
    public let note: String?
    public let audioLanguages: [String]? // e.g. ["en","es"]

    public init(name: String, url: URL?, kind: TestMediaKind, isPlayable: Bool = true, note: String? = nil, audioLanguages: [String]? = nil) {
        self.name = name
        self.url = url
        self.kind = kind
        self.isPlayable = isPlayable
        self.note = note
        self.audioLanguages = audioLanguages
    }
}

extension TestMediaKind {
    var akMediaType: AKMediaType {
        switch self {
        case .clip:
            return .clip
        case .live:
            return .stream(isLive: true)
        }
    }
}

// Sample dataset used in Example / manual testing
@MainActor public let sampleTestMedia: [TestMedia] = [
    TestMedia(name: "Clip — H264, stereo", url: URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"), kind: .clip, isPlayable: true, note: "video, stereo"),
    TestMedia(name: "Audio — MP3 podcast", url: URL(string: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"), kind: .clip, isPlayable: true, note: "audio-only"),
    TestMedia(name: "Protected — DRM simulated", url: URL(string: "https://example.com/media/drm_protected.m3u8"), kind: .clip, isPlayable: false, note: "protected / not playable without keys"),
    TestMedia(name: "Multi-track — en+es audio", url: URL(string: "https://example.com/media/multitrack.m3u8"), kind: .clip, isPlayable: true, note: "multitrack audio"),
    TestMedia(name: "Live — HLS low-latency", url: URL(string: "https://hls-harbor-livepush.akamaized.net/live_cdn/nsqIStpj8PaG-Ev/emcQJ0pGpremocy/index.m3u8"), kind: .live, isPlayable: true, note: "live stream"),
    TestMedia(name: "Apple — DV + Atmos sample", url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/adv_dv_atmos/main.m3u8"), kind: .clip, isPlayable: true, note: """
    Video Specs:
    - Format: H.264 variants (24 fps)
    - Aspect Ratio: 16:9
    - HDR: Dolby Vision Profile 5
    - Tier 1: 1920x1080 @ 8 Mbps
    - Tier 2: 1280x720 @ 4 Mbps
    - Tier 3: 960x540 @ 2 Mbps

    Audio Specs:
    - Dolby Atmos, 48 kHz (primary)
    - Fallback: AAC-LC, Stereo, 128 kbps
    - Languages: English
    """, audioLanguages: ["en"]),
    TestMedia(name: "Interstitial Sample — Apple MVP interstitial", url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/interstitial-sample/mvp_interstitial_sample.m3u8"), kind: .clip, isPlayable: true, note: """
    Primary Video Specs:
    - AVC 1024x576 @ 2.1 Mbps
    - HEVC 1920x1080 @ 2.7 Mbps
    - HEVC Dolby Vision Profile 5 3840x2160 @ 24 Mbps

    Primary Audio Specs:
    - Dolby Atmos, 7.1, 48 kHz, 768 kbps
    - Dolby Digital, 5.1, 48 kHz, 384 kbps
    - HE-AAC, stereo, 44.1 kHz, 69 kbps
    - Languages: English

    Subtitles:
    - English
    - Español (España)
    - ID3/emsg timed metadata expected

    Interstitials (ad samples included in manifest):
    - ad1: HEVC 1280x720 @ 697 Kbps; up to 3840x2160 @ 2.1 Mbps; audio AAC-LC 48kHz 128kbps
    - midroll-1: HEVC 1280x720 @ 737 Kbps; up to 3840x2160 @ 2.2 Mbps; audio AAC-LC 48kHz 128kbps
    - midroll-2: HEVC 1280x720 @ 767 Kbps; up to 3840x2160 @ 2.3 Mbps; audio AAC-LC 48kHz 128kbps
    - ad3: AVC/HEVC mixes up to 1920x1080 @ 6 Mbps; audio AAC-LC 48kHz 128kbps
    """, audioLanguages: ["en"]),
    TestMedia(name: "BipBop HEVC Example", url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/master.m3u8"), kind: .clip, isPlayable: true, note: """
    Video Specs:
    - Format: HEVC variants with H.264 fallback
    - Frame Rate: 30 fps
    - Aspect Ratio: 16:9
    - Tier 1: 1920x1080 @ 6 Mbps (HEVC)
    - Tier 2: 1280x720 @ 3 Mbps (HEVC)
    - Tier 3: 960x540 @ 1.5 Mbps (H.264 fallback)

    Audio Specs:
    - AAC-LC, Stereo, 48 kHz, 128 kbps
    - Languages: English
    """, audioLanguages: ["en"]),
    TestMedia(name: "Broken — 404", url: URL(string: "https://example.invalid/broken.mp4"), kind: .clip, isPlayable: false, note: "server 404 simulated")
    ]
