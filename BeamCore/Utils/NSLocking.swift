//
//  NSLocking.swift
//  BeamCore
//
//  Created by Thomas on 29/07/2022.
//

import Foundation

extension NSLocking {
    @discardableResult
    public func callAsFunction<T>(block: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try block()
    }
}
