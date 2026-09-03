//
//  AKSeek.swift
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

public enum AKSeekPosition: Hashable {
    case time(CMTime)
    case date(Date)
    
    public var isTime: Bool {
        if case .time = self {
            return true
        } else {
            return false
        }
    }
    
    public var isDate: Bool {
        if case .date = self {
            return true
        } else {
            return false
        }
    }
    
    public var time: CMTime {
        guard case .time(let time) = self else { return .zero }
        return time
    }
}

public struct AKSeek: Equatable, Hashable {
    public let id = UUID()
    public let position: AKSeekPosition
    public let toleranceBefore: CMTime
    public let toleranceAfter: CMTime
    public let completionHandler: ((Bool) -> Void)?
    
    public init(position: AKSeekPosition,
                toleranceBefore: CMTime = .positiveInfinity,
                toleranceAfter: CMTime = .positiveInfinity,
                completionHandler: ((Bool) -> Void)? = nil) {
        self.position = position
        self.toleranceBefore = toleranceBefore
        self.toleranceAfter = toleranceAfter
        self.completionHandler = completionHandler
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
