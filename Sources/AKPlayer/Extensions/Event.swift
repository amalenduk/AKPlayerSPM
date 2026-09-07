//
//   Event.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Combine

public typealias Event<T> = PassthroughSubject<T, Never>
