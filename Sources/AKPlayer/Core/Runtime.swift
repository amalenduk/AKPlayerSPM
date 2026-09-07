//
//   Runtime.swift
//   AKPlayer
//
//   Copyright (c) 2020 Amalendu Kar. All rights reserved.
//   Licensed under the MIT license. See LICENSE file in the project root.
//

import Foundation

func getAssociatedObject<T>(_ object: Any, _ key: UnsafeRawPointer) -> T? {
    objc_getAssociatedObject(object, key) as? T
}

func setRetainedAssociatedObject(
    _ object: Any,
    _ key: UnsafeRawPointer,
    _ value: some Any
) {
    objc_setAssociatedObject(
        object,
        key,
        value,
        .OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )
}
