//
//  AVPlayerItem+Extensions.swift
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

public extension AVPlayerItem {
    
    func canStep(by count: Int) -> Bool {
        var isForward: Bool { return count.signum() == 1 }
        return isForward ? canStepForward : canStepBackward
    }
    
    func canPlay(at rate: AKPlaybackRate) -> Bool {
        switch rate.rate {
        case 0.0...:
            switch rate.rate {
            case 2.0...:
                return canPlayFastForward
            case 1.0..<2.0:
                return true
            case 0.0..<1.0:
                return canPlaySlowForward
            default:
                return false
            }
        case ..<0.0:
            switch rate.rate {
            case -1.0:
                return canPlayReverse
            case -1.0..<0.0:
                return canPlaySlowReverse
            case ..<(-1.0):
                return canPlayFastReverse
            default:
                return false
            }
        default:
            return false
        }
    }
}
