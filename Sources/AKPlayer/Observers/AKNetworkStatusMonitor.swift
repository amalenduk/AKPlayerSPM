//
//  AKNetworkReachabilityObserver.swift
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
import Network
import Combine

public protocol AKNetworkStatusMonitorProtocol {
    var currentPath: NWPath? { get }
    var currentNetworkStatus: NWPath.Status { get }
    var isConnected: Bool { get }
    var networkStatusPublisher: AnyPublisher<NWPath.Status, Never> { get }
    
    func startObserving()
    func stopObserving()
}

open class AKNetworkStatusMonitor: AKNetworkStatusMonitorProtocol {
    
    // MARK: - Properties
    
    private var networkPathMonitor: NWPathMonitor?
    private var isObserving = false
    private let monitorQueue = DispatchQueue(label: "com.akplayer.networkmonitor", qos: .utility)
    
    // Track the latest confirmed path state safely
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
        return networkStatusSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    // MARK: - Init
    
    public init() {}
    
    deinit {
        stopObserving()
    }
    
    // MARK: - Control Methods
    
    open func startObserving() {
        guard !isObserving else { return }
        
        let monitor = NWPathMonitor()
        
        monitor.pathUpdateHandler = { [weak self] path in
            self?.latestPath = path
            self?.networkStatusSubject.send(path.status)
        }
        
        self.networkPathMonitor = monitor
        monitor.start(queue: monitorQueue)
        isObserving = true
    }
    
    open func stopObserving() {
        guard isObserving else { return }
        
        networkPathMonitor?.cancel()
        networkPathMonitor = nil
        isObserving = false
    }
}
