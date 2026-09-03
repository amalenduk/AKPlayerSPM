//
//  AKTime.swift
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

import CoreMedia

public struct AKTime: Equatable, Comparable, CustomStringConvertible {
    
    public let value: CMTime?
    
    // MARK: - Initializers
    
    public init(time: CMTime?) {
        self.value = time
    }
    
    public init(seconds: Double, preferredTimescale: Int32) {
        self.init(time: CMTimeMakeWithSeconds(seconds, preferredTimescale: preferredTimescale))
    }
    
    public init(seconds: Double) {
        self.init(time: CMTimeMakeWithSeconds(seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
    }
    
    // MARK: - Computed Properties
    
    public var seconds: Double? {
        guard let value = value, value.isValid && value.isNumeric else { return nil }
        return CMTimeGetSeconds(value)
    }
    
    public var description: String {
        return self.stringValue
    }
    
    public var stringValue: String {
        guard let value = value, value.isValid && value.isNumeric else { return "--:--" }
        let rawSeconds = value.seconds
        let totalSeconds = Int(abs(rawSeconds))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds / 60) % 60
        let seconds = totalSeconds % 60
        let prefix = rawSeconds < 0 ? "-" : ""
        
        if hours > 0 {
            return String(format: "%@%01d:%02d:%02d", prefix, hours, minutes, seconds)
        } else {
            return String(format: "%@%02d:%02d", prefix, minutes, seconds)
        }
    }
    
    public func subSecondStringValue() -> String {
        guard let value = self.value, value.isValid && value.isNumeric else {
            return "--:--.---"
        }
        
        let rawSeconds = value.seconds
        let positiveSeconds = abs(rawSeconds)
        
        let totalSeconds = Int(positiveSeconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds / 60) % 60
        let seconds = totalSeconds % 60
        
        let fractionalSeconds = positiveSeconds.truncatingRemainder(dividingBy: 1)
        let milliseconds = Int((fractionalSeconds * 1000).rounded())
        let prefix = rawSeconds < 0 ? "-" : ""
        
        if hours > 0 {
            return String(format: "%@%01d:%02d:%02d.%03d", prefix, hours, minutes, seconds, milliseconds)
        } else {
            return String(format: "%@%02d:%02d.%03d", prefix, minutes, seconds, milliseconds)
        }
    }
    
    public func verboseStringValue() -> String {
        guard let value = self.value, value.isValid && value.isNumeric else {
            return ""
        }
        
        let rawSeconds = value.seconds
        let totalSeconds = Int(abs(rawSeconds))
        let hours = totalSeconds / 3600
        let mins = (totalSeconds / 60) % 60
        let seconds = totalSeconds % 60
        let remaining = rawSeconds < 0
        
        var components = DateComponents()
        components.hour = hours
        components.minute = mins
        components.second = seconds
        
        guard let formatted = DateComponentsFormatter.localizedString(from: components, unitsStyle: .full) else {
            return ""
        }
        
        let verboseString = remaining ? "\(formatted) remaining" : formatted
        return verboseString.replacingOccurrences(of: ",", with: "")
    }
    
    // MARK: - Protocol Conformances (Equatable & Comparable)
    
    public static func < (lhs: AKTime, rhs: AKTime) -> Bool {
        guard let a = lhs.value?.seconds, let b = rhs.value?.seconds else { return false }
        return a < b
    }
    
    public static func == (lhs: AKTime, rhs: AKTime) -> Bool {
        return lhs.value?.seconds == rhs.value?.seconds
    }
}
