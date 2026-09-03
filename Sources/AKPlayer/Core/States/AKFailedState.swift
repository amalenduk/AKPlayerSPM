//
//  AKFailedState.swift
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

public class AKFailedState: AKBaseState {
    
    // MARK: - Properties
    
    public var error: AKPlayerError
    
    // MARK: - Init
    
    public init(playerController: AKPlayerControllerProtocol,
                error: AKPlayerError) {
        self.error = error
        super.init(playerController: playerController, state: .failed)
    }
    
    deinit { }
    
    public override func processStateChange() {
        playerController.delegate?.playerController(playerController,
                                                    didFailWith: error)
    }
    
    public override func availability(for action: AKPlayerAction)
    -> (allowed: Bool, reason: AKPlayerUnavailableCommandReason?) {
        switch action {
        case .load:
            return playerController.player.error == nil ? (true, .none) : (false, .playerCanNoLongerPlay)
        default:
            return (false, playerController.player.error == nil ? .playerCanNoLongerPlay : .loadMediaFirst)
        }
    }
}
