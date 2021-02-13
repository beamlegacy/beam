//
//  RWLock.swift
//  Beam
//
//  Created by Sebastien Metrot on 03/02/2021.
//

import Foundation

protocol RWLockable {
    func readLock()
    func readUnlock()
    func writeLock()
    func writeUnlock()
}

class RWLock: RWLockable {
    private var lock = pthread_rwlock_t()

    init() {
        pthread_rwlock_init(&lock, nil)
    }

    func readLock() {
        pthread_rwlock_rdlock(&lock)
    }

    func readUnlock() {
        pthread_rwlock_unlock(&lock)
    }

    func writeLock() {
        pthread_rwlock_wrlock(&lock)
    }

    func writeUnlock() {
        pthread_rwlock_unlock(&lock)
    }

    deinit {
        pthread_rwlock_destroy(&lock)
    }
}

extension RWLockable {
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
}
