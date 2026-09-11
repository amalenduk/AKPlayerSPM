//
//  Task+Extensions.swift
//  AKPlayer
//
//  Created by Amalendu Kar on 11/09/26.
//

import Combine

extension Task {
    func store(in set: inout Set<AnyCancellable>) {
        set.insert(AnyCancellable { self.cancel() })
    }
}
