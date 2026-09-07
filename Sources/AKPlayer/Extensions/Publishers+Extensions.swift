//
//   Publishers+Extensions.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Combine
import Foundation

// MARK: - Publishers Extensions

public extension Publishers {
    // MARK: - CombineLatest Variants

    /// Combines elements from five publishers and delivers a tuple containing
    /// the latest value of each upstream publisher.
    static func CombineLatest5<
        A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher
    >(
        _ a: A,
        _ b: B,
        _ c: C,
        _ d: D,
        _ e: E
    )
        -> AnyPublisher<
            (A.Output, B.Output, C.Output, D.Output, E.Output),
            A.Failure
        >
        where
        B.Failure == A.Failure, C.Failure == A.Failure, D.Failure == A.Failure,
        E.Failure == A.Failure
    {
        Publishers.CombineLatest(Publishers.CombineLatest4(a, b, c, d), e)
            .map { ($0.0, $0.1, $0.2, $0.3, $1) }
            .eraseToAnyPublisher()
    }

    /// Combines elements from six publishers and delivers a tuple containing
    /// the latest value of each upstream publisher.
    static func CombineLatest6<
        A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher,
        F: Publisher
    >(
        _ a: A,
        _ b: B,
        _ c: C,
        _ d: D,
        _ e: E,
        _ f: F
    ) -> AnyPublisher<
        (
            A.Output,
            B.Output,
            C.Output,
            D.Output,
            E.Output,
            F.Output
        ), A.Failure
    >
        where
        B.Failure == A.Failure, C.Failure == A.Failure, D.Failure == A.Failure,
        E.Failure == A.Failure,
        F.Failure == A.Failure
    {
        Publishers.CombineLatest3(Publishers.CombineLatest4(a, b, c, d), e, f)
            .map { ($0.0, $0.1, $0.2, $0.3, $1, $2) }
            .eraseToAnyPublisher()
    }

    /// Combines elements from seven publishers and delivers a tuple containing
    /// the latest value of each upstream publisher.
    static func CombineLatest7<
        A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher,
        F: Publisher, G: Publisher
    >(
        _ a: A,
        _ b: B,
        _ c: C,
        _ d: D,
        _ e: E,
        _ f: F,
        _ g: G
    ) -> AnyPublisher<
        (A.Output, B.Output, C.Output, D.Output, E.Output, F.Output, G.Output),
        A.Failure
    >
        where
        B.Failure == A.Failure, C.Failure == A.Failure, D.Failure == A.Failure,
        E.Failure == A.Failure,
        F.Failure == A.Failure, G.Failure == A.Failure
    {
        Publishers.CombineLatest4(
            Publishers.CombineLatest4(a, b, c, d),
            e,
            f,
            g
        )
        .map { ($0.0, $0.1, $0.2, $0.3, $1, $2, $3) }
        .eraseToAnyPublisher()
    }
}

// MARK: - Publisher Extensions

public extension Publisher {
    // MARK: - Weak Capture Operators

    /// Weakly captures an object and extracts the value at a specified keypath
    /// for each emitted element, dropping values if the target object is
    /// deallocated.
    /// - Parameters:
    ///   - other: The object instance to weakly reference.
    ///   - keyPath: A keypath accessing a property on the target object.
    /// - Returns: A publisher emitting tuples containing original output and
    /// the evaluated keypath value.
    func weakCapture<T: AnyObject, V>(
        _ other: T?,
        at keyPath: KeyPath<T, V>
    ) -> AnyPublisher<
        (Output, V), Failure
    > {
        compactMap { [weak other] output -> (Output, V)? in
            guard let other else { return nil }
            return (output, other[keyPath: keyPath])
        }
        .eraseToAnyPublisher()
    }

    /// Weakly captures an object alongside each emitted element, dropping
    /// values if the target object is deallocated.
    /// - Parameter other: The object instance to weakly reference.
    /// - Returns: A publisher emitting tuples containing original output and
    /// the weakly retained object instance.
    func weakCapture<T: AnyObject>(_ other: T?)
        -> AnyPublisher<(Output, T), Failure>
    {
        weakCapture(other, at: \T.self)
    }
}
