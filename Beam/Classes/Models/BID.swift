//
//  BID.swift
//  Beam
//
//  Created by Sebastien Metrot on 22/09/2020.
//

import Foundation
import AppKit

struct BID64: Codable, Hashable, Equatable {
    var id: UInt64

    private static var baseTime = Double(1420070400000)
    private static let timeBits = 41
    private static let nodeBits = 10
    private static let seqBits = 12
    private static var sequence = 0
    static var nodeId: Int {
        var uuidRef: CFUUID?
        var uuidBytes: [CUnsignedChar] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        var ts = timespec(tv_sec: 0, tv_nsec: 0)

        gethostuuid(&uuidBytes, &ts)

        uuidRef = CFUUIDCreateWithBytes(
            kCFAllocatorDefault,
            uuidBytes[0],
            uuidBytes[1],
            uuidBytes[2],
            uuidBytes[3],
            uuidBytes[4],
            uuidBytes[5],
            uuidBytes[6],
            uuidBytes[7],
            uuidBytes[8],
            uuidBytes[9],
            uuidBytes[10],
            uuidBytes[11],
            uuidBytes[12],
            uuidBytes[13],
            uuidBytes[14],
            uuidBytes[15]
        )

        return uuidRef!.hashValue
    }

    private func mask(_ value: Int, _ bits: Int) -> Int {
        return (value & ((1 << bits) - 1))
    }

    init() {
        id = 0
        Self.sequence += 1
        let t = mask(Int(CACurrentMediaTime() * 1000 - Self.baseTime), Self.timeBits)
        id = UInt64(t << (Self.nodeBits + Self.seqBits) | (mask(Self.nodeId, Self.nodeBits) << Self.seqBits) | mask(Self.sequence, Self.seqBits))
    }

    init(id: UInt64) {
        self.id = id
    }
}

struct BID32: Codable, Hashable, Equatable {
    var id: UInt32

    private static var baseTime = Double(1420070400000)
    private static let timeBits = 20
    private static let nodeBits = 5
    private static let seqBits = 7
    private static var sequence = 0
    private func mask(_ value: Int, _ bits: Int) -> Int {
        return (value & ((1 << bits) - 1))
    }

    init() {
        id = 0
        Self.sequence += 1
        let t = mask(Int(CACurrentMediaTime() * 1000 - Self.baseTime), Self.timeBits)
        id = UInt32(t << (Self.nodeBits + Self.seqBits) | (mask(BID64.nodeId, Self.nodeBits) << Self.seqBits) | mask(Self.sequence, Self.seqBits))
    }

    init(id: UInt32) {
        self.id = id
    }
}

struct MonotonicIncreasingID32 {
    static var value: UInt32 = 0
    static var newValue: UInt32 {
        defer {
            Self.value += 1
        }

        return Self.value
    }
}

struct MonotonicIncreasingID64 {
    static var value: UInt64 = 0
    static var newValue: UInt64 {
        defer {
            Self.value += 1
        }

        return Self.value
    }
}
