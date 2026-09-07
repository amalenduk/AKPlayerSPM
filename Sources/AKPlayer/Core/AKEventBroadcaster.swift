//
//   AKEventBroadcaster.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

/// Internal multicast broadcaster managing multiple `AsyncStream` subscribers.
final class AKEventBroadcaster<Event: Sendable>: @unchecked Sendable {
    // MARK: - Properties

    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<Event>.Continuation] = [:]

    // MARK: - Init & Deinit

    init() {}

    deinit {
        finish()
    }

    // MARK: - API

    /// Emits an event to all active streams.
    func send(_ event: Event) {
        lock.lock()
        let active = Array(continuations.values)
        lock.unlock()

        for continuation in active {
            continuation.yield(event)
        }
    }

    /// Creates a new subscription for a caller.
    func makeStream(
        bufferingPolicy: AsyncStream<Event>.Continuation
            .BufferingPolicy = .bufferingNewest(100)
    ) -> AsyncStream<Event> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: bufferingPolicy) { continuation in
            lock.lock()
            continuations[id] = continuation
            lock.unlock()

            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                lock.lock()
                continuations.removeValue(forKey: id)
                lock.unlock()
            }
        }
    }

    /// Terminates all open streams. Safe to call from any context or deinit.
    func finish() {
        lock.lock()
        let active = Array(continuations.values)
        continuations.removeAll()
        lock.unlock()

        for continuation in active {
            continuation.finish()
        }
    }
}
