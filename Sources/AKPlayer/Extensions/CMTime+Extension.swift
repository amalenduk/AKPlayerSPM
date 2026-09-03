//
//  CMTime+Extension.swift
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

public extension CMTime {
    
    var stringValue: String {
        guard isValid && isNumeric else {
            return "--:--"
        }
        
        let duration = lrint(seconds)
        
        let positiveDuration = abs(duration)
        if positiveDuration > 3600 {
            return String(format: "%@%01ld:%02ld:%02ld",
                          duration < 0 ? "-" : "",
                          positiveDuration / 3600,
                          (positiveDuration / 60) % 60,
                          positiveDuration % 60)
        } else {
            return String(format: "%@%02ld:%02ld",
                          duration < 0 ? "-" : "",
                          (positiveDuration / 60) % 60,
                          positiveDuration % 60)
        }
    }
    
    func subSecondStringValue() -> String {
        if isValid && isNumeric {
            let duration = lrint(seconds)
            let positiveDuration = abs(duration)
            let hours = positiveDuration / 3600
            let minutes = (positiveDuration / 60) % 60
            let seconds = positiveDuration % 60
            let milliseconds = positiveDuration - ((hours * 3600 + minutes * 60 + seconds) * 1000)
            if hours > 1 {
                return String(format: "%@%01ld:%02ld:%02ld.%03ld", duration < 0 ? "-" : "", hours, minutes, seconds, milliseconds)
            } else {
                return String(format: "%@%02ld:%02ld.%03ld", duration < 0 ? "-" : "", minutes, seconds, milliseconds)
            }
        } else {
            return "--:--.---"
        }
    }
    
    func verboseStringValue() -> String {
        guard isValid && isNumeric else {
            return ""
        }
        
        let duration = lrint(seconds)
        let positiveDuration = abs(duration)
        let hours = positiveDuration / 3600
        let mins = (positiveDuration / 60) % 60
        let seconds = positiveDuration % 60
        let remaining = duration < 0
        
        var components = DateComponents()
        components.hour = Int(hours)
        components.minute = Int(mins)
        components.second = Int(seconds)
        
        var verboseString = DateComponentsFormatter.localizedString(from: components, unitsStyle: .full)
        verboseString = remaining ? String(format: "%@ remaining", verboseString!) : verboseString
        return verboseString!.replacingOccurrences(of: ",", with: "")
    }
}

public extension CMTimeRange {
    var isValidAndNotEmpty: Bool {
        isValid && !isEmpty
    }
}
