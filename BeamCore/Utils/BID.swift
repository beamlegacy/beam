//
//  BID.swift
//  Beam
//
//  Created by Sebastien Metrot on 22/09/2020.
//

import Foundation
import AppKit

public struct BID64: Codable, Hashable, Equatable {
    public var id: UInt64

    private static var baseTime = Double(1420070400000)
    private static let timeBits = 41
    private static let nodeBits = 10
    private static let seqBits = 12
    private static var sequence = 0
    public static var nodeId: Int {
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

    public init() {
        id = 0
        Self.sequence += 1
        id = Self.generateIDWithCurrentTime()
    }

    public init(id: UInt64) {
        self.id = id
    }

    /// splitting into sub functions for swift type-checking performance
    static private func mask(_ value: Int, _ bits: Int) -> Int {
        return (value & ((1 << bits) - 1))
    }
    static private func currentTimeMask() -> Int {
        mask(Int(CACurrentMediaTime() * 1000 - baseTime), timeBits)
    }
    static private func generateIDWithCurrentTime() -> UInt64 {
        let t = mask(Int(CACurrentMediaTime() * 1000 - Self.baseTime), Self.timeBits)
        return UInt64(t << (nodeBits + seqBits) | (mask(nodeId, nodeBits) << seqBits) | mask(sequence, seqBits))
    }
}

public struct BID32: Codable, Hashable, Equatable {
    public var id: UInt32

    private static var baseTime = Double(1420070400000)
    private static let timeBits = 20
    private static let nodeBits = 5
    private static let seqBits = 7
    private static var sequence = 0

    public init() {
        id = 0
        Self.sequence += 1
        id = Self.generateIDWithCurrentTime()
    }

    public init(id: UInt32) {
        self.id = id
    }

    /// splitting into sub functions for swift type-checking performance
    static private func mask(_ value: Int, _ bits: Int) -> Int {
        return (value & ((1 << bits) - 1))
    }
    static private func currentTimeMask() -> Int {
        mask(Int(CACurrentMediaTime() * 1000 - baseTime), timeBits)
    }
    static private func generateIDWithCurrentTime() -> UInt32 {
        let t = currentTimeMask()
        return UInt32(t << (nodeBits + seqBits) | (mask(BID64.nodeId, nodeBits) << seqBits) | mask(sequence, seqBits))
    }
}

public struct MonotonicIncreasingID32: Codable {
    public var value: UInt32 = 0
    public mutating func newValue() -> UInt32 {
        defer {
            value += 1
        }

        return value
    }

    public static var shared = Self()
    public static var newValue: UInt32 {
        return Self.shared.newValue()
    }
}

public struct MonotonicIncreasingID64: Codable {
    public var value: UInt64 = 0
    public mutating func newValue() -> UInt64 {
        defer {
            value += 1
        }

        return value
    }

    public static var shared = Self()
    public static var newValue: UInt64 {
        return Self.shared.newValue()
    }
}
