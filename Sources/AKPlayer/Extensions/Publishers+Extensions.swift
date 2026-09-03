//
//  Publishers+Extensions.swift
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

import Foundation
import Combine

public extension Publishers {
    
    static func CombineLatest5<A, B, C, D, E>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) -> AnyPublisher<(A.Output, B.Output, C.Output, D.Output, E.Output), A.Failure> where A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, B.Failure == A.Failure, C.Failure == A.Failure, D.Failure == A.Failure, E.Failure == A.Failure {
        Publishers.CombineLatest(Publishers.CombineLatest4(a, b, c, d), e)
            .map { ($0.0, $0.1, $0.2, $0.3, $1) }
            .eraseToAnyPublisher()
    }
    
    static func CombineLatest6<A, B, C, D, E, F>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) -> AnyPublisher<(A.Output, B.Output, C.Output, D.Output, E.Output, F.Output), A.Failure> where A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, B.Failure == A.Failure, C.Failure == A.Failure, D.Failure == A.Failure, E.Failure == A.Failure, F.Failure == A.Failure {
        Publishers.CombineLatest3(Publishers.CombineLatest4(a, b, c, d), e, f)
            .map { ($0.0, $0.1, $0.2, $0.3, $1, $2) }
            .eraseToAnyPublisher()
    }
    
    static func CombineLatest7<A, B, C, D, E, F, G>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) -> AnyPublisher<(A.Output, B.Output, C.Output, D.Output, E.Output, F.Output, G.Output), A.Failure> where A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, G: Publisher, B.Failure == A.Failure, C.Failure == A.Failure, D.Failure == A.Failure, E.Failure == A.Failure, F.Failure == A.Failure, G.Failure == A.Failure {
        Publishers.CombineLatest4(Publishers.CombineLatest4(a, b, c, d), e, f, g)
            .map { ($0.0, $0.1, $0.2, $0.3, $1, $2, $3) }
            .eraseToAnyPublisher()
    }
}

public extension Publisher {
    
    func weakCapture<T, V>(_ other: T?, at keyPath: KeyPath<T, V>) -> AnyPublisher<(Output, V), Failure> where T: AnyObject {
        compactMap { [weak other] output -> (Output, V)? in
            guard let other else { return nil }
            return (output, other[keyPath: keyPath])
        }
        .eraseToAnyPublisher()
    }
    
    func weakCapture<T>(_ other: T?) -> AnyPublisher<(Output, T), Failure> where T: AnyObject {
        weakCapture(other, at: \T.self)
    }
}
