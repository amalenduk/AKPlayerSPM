//
//  AKApplicationLifeCycleEventsObserver.swift
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
import UIKit

public protocol AKApplicationLifeCycleEventsObserverDelegate: AnyObject {
    func applicationLifeCycleEventsObserver(_ observer: AKApplicationLifeCycleEventsObserverProtocol,
                                            on event: AKApplicationLifeCycleEvent)
}

public enum AKApplicationLifeCycleEvent {
    case willResignActive
    case didBecomeActive
    case didEnterBackground
    case willEnterForeground
}

public enum AKApplicationLifeCycleState {
    case resignActive
    case active
    case background
    case foreground
    
    var isActiveOrForeground: Bool {
        return self == .active
        || self == .foreground
    }
    
    var isResignActiveOrBackground: Bool {
        return self == .resignActive
        || self == .background
    }
}

public protocol AKApplicationLifeCycleEventsObserverProtocol {
    var state: AKApplicationLifeCycleState { get }
    var delegate: AKApplicationLifeCycleEventsObserverDelegate? { get set }
    
    func startObserving()
    func stopObserving()
}

open class AKApplicationLifeCycleEventsObserver: AKApplicationLifeCycleEventsObserverProtocol {
    
    // MARK: - Properties
    
    public weak var delegate: AKApplicationLifeCycleEventsObserverDelegate?
    
    private var isObserving = false
    
    public private(set) var state: AKApplicationLifeCycleState = .foreground
    
    // MARK: - Init
    
    public init() { }
    
    deinit {
        stopObserving()
    }
    
    open func startObserving() {
        guard !isObserving else { return }
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleApplicationWillResignActive(_:)),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleApplicationDidBecomeActive(_:)),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleApplicationDidEnterBackground(_ :)),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleApplicationWillEnterForeground(_ :)),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
        
        
        isObserving = true
    }
    
    open func stopObserving() {
        guard isObserving else { return }
        
        NotificationCenter.default.removeObserver(self,
                                                  name: UIApplication.willResignActiveNotification,
                                                  object: nil)
        NotificationCenter.default.removeObserver(self,
                                                  name: UIApplication.didBecomeActiveNotification,
                                                  object: nil)
        NotificationCenter.default.removeObserver(self,
                                                  name: UIApplication.didEnterBackgroundNotification,
                                                  object: nil)
        NotificationCenter.default.removeObserver(self,
                                                  name: UIApplication.willEnterForegroundNotification,
                                                  object: nil)
        
        isObserving = false
    }
    
    @objc open func handleApplicationWillResignActive(_ notification: Notification) {
        state = .resignActive
        guard let delegate = delegate else { return }
        delegate.applicationLifeCycleEventsObserver(self,
                                                    on: .willResignActive)
    }
    
    @objc open func handleApplicationDidBecomeActive(_ notification: Notification) {
        state = .active
        guard let delegate = delegate else { return }
        delegate.applicationLifeCycleEventsObserver(self,
                                                    on: .didBecomeActive)
    }
    
    @objc open func handleApplicationDidEnterBackground(_ notification: Notification) {
        state = .background
        guard let delegate = delegate else { return }
        delegate.applicationLifeCycleEventsObserver(self,
                                                    on: .didEnterBackground)
    }
    
    @objc open func handleApplicationWillEnterForeground(_ notification: Notification) {
        state = .foreground
        guard let delegate = delegate else { return }
        delegate.applicationLifeCycleEventsObserver(self,
                                                    on: .willEnterForeground)
    }
}
