//
//  ExclusiveRunner.swift
//  Beam
//
//  Created by Frank Lefebvre on 12/04/2022.
//

import Foundation

struct ExclusiveRunner {
    private var sema = DispatchSemaphore(value: 1)

    enum Error: Swift.Error {
        case alreadyRunning
    }

    func run<T>(_ operation: () throws -> T) throws -> T {
        guard sema.wait(timeout: .now()) == .success else {
            throw Error.alreadyRunning
        }
        defer {
            sema.signal()
        }
        return try operation()
    }
}
