//
//  AKNetworkStatusMonitor.swift
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

import Combine
import Foundation
import Network

// MARK: - AKNetworkStatusMonitorProtocol

/// A contract for monitoring network status changes via NWPathMonitor.
@MainActor
public protocol AKNetworkStatusMonitorProtocol: AnyObject {
    // MARK: - Properties

    /// The current network path object.
    var currentPath: NWPath? { get }

    /// The current status of the network path.
    var currentNetworkStatus: NWPath.Status { get }

    /// A convenience boolean indicating if the network status is currently satisfied.
    var isConnected: Bool { get }

    /// A publisher emitting network status changes.
    var networkStatusPublisher: AnyPublisher<NWPath.Status, Never> { get }

    // MARK: - Methods

    /// Begins observing network status updates.
    func startObserving()

    /// Stops observing network status updates and cleans up monitoring resources.
    func stopObserving()
}

// MARK: - AKNetworkStatusMonitor

/// A monitor class responsible for tracking network connectivity changes using `NWPathMonitor`
/// and exposing status updates through Combine publishers on the main thread.
@MainActor
public class AKNetworkStatusMonitor: AKNetworkStatusMonitorProtocol {
    // MARK: - Properties

    /// Opaque reference to system path monitor.
    /// Marked `nonisolated(unsafe)` to permit cancellation during `deinit`.
    private nonisolated(unsafe) var networkPathMonitor: NWPathMonitor?

    private var isObserving = false
    private let monitorQueue = DispatchQueue(label: "com.akplayer.networkmonitor", qos: .utility)

    /// Track the latest confirmed path state safely.
    private var latestPath: NWPath?

    public var currentPath: NWPath? {
        return networkPathMonitor?.currentPath ?? latestPath
    }

    public var currentNetworkStatus: NWPath.Status {
        return currentPath?.status ?? .requiresConnection
    }

    public var isConnected: Bool {
        return currentNetworkStatus == .satisfied
    }

    private let networkStatusSubject = CurrentValueSubject<NWPath.Status, Never>(.requiresConnection)

    public var networkStatusPublisher: AnyPublisher<NWPath.Status, Never> {
        return
            networkStatusSubject
                .removeDuplicates()
                .eraseToAnyPublisher()
    }

    // MARK: - Init & Deinit

    /// Initializes a new instance of the network status monitor.
    public init() {}

    deinit {
        networkPathMonitor?.cancel()
        networkPathMonitor = nil
    }

    // MARK: - Control Methods

    /// Starts observing network path changes.
    public func startObserving() {
        guard !isObserving else { return }

        let monitor = NWPathMonitor()

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.latestPath = path
                self.networkStatusSubject.send(path.status)
            }
        }

        networkPathMonitor = monitor
        monitor.start(queue: monitorQueue)
        isObserving = true
    }

    /// Stops observing network path changes and cancels the path monitor.
    public func stopObserving() {
        guard isObserving else { return }

        networkPathMonitor?.cancel()
        networkPathMonitor = nil
        isObserving = false
    }
}
