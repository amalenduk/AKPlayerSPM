//
//  AKApplicationLifeCycleEventsObserver.swift
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
import Combine
import UIKit

// MARK: - AKApplicationLifeCycleEvent

/// Events emitted when the application transitions through different lifecycle
/// phases.
public enum AKApplicationLifeCycleEvent: Sendable {
    // MARK: - Cases

    /// The application is about to lose active status (e.g., phone call or
    /// control center presentation).
    case willResignActive

    /// The application has become active and is ready to accept user
    /// interactions.
    case didBecomeActive

    /// The application has entered the background state.
    case didEnterBackground

    /// The application is preparing to transition back to the foreground.
    case willEnterForeground
}

// MARK: - AKApplicationLifeCycleState

/// Represents the current tracked state of the application's lifecycle.
public enum AKApplicationLifeCycleState: Sendable {
    // MARK: - Cases

    /// The application is in an inactive state.
    case resignActive

    /// The application is currently active in the foreground.
    case active

    /// The application is running in the background.
    case background

    /// The application is in the process of coming to the foreground.
    case foreground

    // MARK: - Computed Properties

    /// A convenience property returning `true` if the app is currently
    /// `.active` or `.foreground`.
    public var isActiveOrForeground: Bool {
        self == .active || self == .foreground
    }

    /// A convenience property returning `true` if the app is currently
    /// `.resignActive` or `.background`.
    public var isResignActiveOrBackground: Bool {
        self == .resignActive || self == .background
    }
}

// MARK: - AKApplicationLifeCycleEventsObserverDelegate

/// Delegate interface for receiving application lifecycle event updates.
@MainActor
public protocol AKApplicationLifeCycleEventsObserverDelegate: AnyObject {
    // MARK: - Methods

    /// Notifies the delegate that an application lifecycle transition event
    /// occurred.
    /// - Parameters:
    ///   - observer: The observer instance monitoring system lifecycle
    /// notifications.
    ///   - event: The specific lifecycle event that took place.
    func applicationLifeCycleEventsObserver(
        _ observer: AKApplicationLifeCycleEventsObserverProtocol,
        on event: AKApplicationLifeCycleEvent
    )
}

// MARK: - AKApplicationLifeCycleEventsObserverProtocol

/// A contract for monitoring application state transitions and notifying a
/// delegate.
@MainActor
public protocol AKApplicationLifeCycleEventsObserverProtocol: AnyObject {
    // MARK: - Properties

    /// The current state of the application lifecycle.
    var state: AKApplicationLifeCycleState { get }

    /// The delegate object receiving lifecycle event notifications.
    var delegate: AKApplicationLifeCycleEventsObserverDelegate? { get set }

    // MARK: - Methods

    /// Begins observing system lifecycle notifications via Combine.
    func startObserving()

    /// Stops observing system lifecycle notifications and cleans up active
    /// subscriptions.
    func stopObserving()
}

// MARK: - AKApplicationLifeCycleEventsObserver

/// An observer class responsible for listening to `UIApplication` lifecycle
/// notifications
/// using Combine pipelines and forwarding state changes to its delegate on the
/// main thread.
@MainActor
public class AKApplicationLifeCycleEventsObserver: AKApplicationLifeCycleEventsObserverProtocol {
    // MARK: - Properties

    /// The delegate object receiving lifecycle event updates.
    public weak var delegate: AKApplicationLifeCycleEventsObserverDelegate?

    /// Flag indicating whether system notifications are currently being
    /// observed.
    private var isObserving = false

    /// The current lifecycle state of the application.
    public private(set) var state: AKApplicationLifeCycleState = .foreground

    /// Container holding reactive Combine event subscriptions.
    private var subscriptions = Set<AnyCancellable>()

    // MARK: - Init & Deinit

    /// Initializes a new instance of the application lifecycle events observer.
    public init() {}

    deinit {}

    // MARK: - Observation Lifecycle

    /// Starts observing system lifecycle notifications.
    ///
    /// Subscribes to `willResignActiveNotification`,
    /// `didBecomeActiveNotification`,
    /// `didEnterBackgroundNotification`, and `willEnterForegroundNotification`
    /// on the main queue.
    public func startObserving() {
        guard !isObserving else { return }

        NotificationCenter.default
            .publisher(for: UIApplication.willResignActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                handleApplicationWillResignActive()
            }
            .store(in: &subscriptions)

        NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                handleApplicationDidBecomeActive()
            }
            .store(in: &subscriptions)

        NotificationCenter.default
            .publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                handleApplicationDidEnterBackground()
            }
            .store(in: &subscriptions)

        NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                handleApplicationWillEnterForeground()
            }
            .store(in: &subscriptions)

        isObserving = true
    }

    /// Stops observing system lifecycle notifications and cancels all active
    /// subscriptions.
    public func stopObserving() {
        guard isObserving else { return }
        subscriptions.removeAll()
        isObserving = false
    }

    // MARK: - Handlers

    /// Updates state to `.resignActive` and triggers delegate callback for
    /// `.willResignActive`.
    public func handleApplicationWillResignActive() {
        state = .resignActive
        delegate?.applicationLifeCycleEventsObserver(
            self,
            on: .willResignActive
        )
    }

    /// Updates state to `.active` and triggers delegate callback for
    /// `.didBecomeActive`.
    public func handleApplicationDidBecomeActive() {
        state = .active
        delegate?.applicationLifeCycleEventsObserver(self, on: .didBecomeActive)
    }

    /// Updates state to `.background` and triggers delegate callback for
    /// `.didEnterBackground`.
    public func handleApplicationDidEnterBackground() {
        state = .background
        delegate?.applicationLifeCycleEventsObserver(
            self,
            on: .didEnterBackground
        )
    }

    /// Updates state to `.foreground` and triggers delegate callback for
    /// `.willEnterForeground`.
    public func handleApplicationWillEnterForeground() {
        state = .foreground
        delegate?.applicationLifeCycleEventsObserver(
            self,
            on: .willEnterForeground
        )
    }
}
