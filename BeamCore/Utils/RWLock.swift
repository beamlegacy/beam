//
//  RWLock.swift
//  Beam
//
//  Created by Sebastien Metrot on 03/02/2021.
//

import Foundation

public protocol RWLockable {
    func readLock()
    func readUnlock()
    func writeLock()
    func writeUnlock()
}

public class RWLock: RWLockable {
    private var lock = pthread_rwlock_t()

    public init() {
        pthread_rwlock_init(&lock, nil)
    }

    public func readLock() {
        pthread_rwlock_rdlock(&lock)
    }

    public func readUnlock() {
        pthread_rwlock_unlock(&lock)
    }

    public func writeLock() {
        pthread_rwlock_wrlock(&lock)
    }

    public func writeUnlock() {
        pthread_rwlock_unlock(&lock)
    }

    deinit {
        pthread_rwlock_destroy(&lock)
    }
}

public extension RWLockable {
    func read<R>(_ block: @escaping () -> R) -> R {
        readLock()
        let res = block()
        readUnlock()
        return res
    }

    func write<R>(_ block: @escaping () -> R) -> R {
        writeLock()
        let res = block()
        writeUnlock()
        return res
    }

    func read<R>(_ block: @escaping () throws -> R) throws -> R {
        readLock()
        let res = try block()
        readUnlock()
        return res
    }

    func write<R>(_ block: @escaping () throws -> R) throws -> R {
        writeLock()
        let res = try block()
        writeUnlock()
        return res
    }
}
