//
//  BID.swift
//  Beam
//
//  Created by Sebastien Metrot on 22/09/2020.
//

import Foundation
import AppKit

struct BID: Codable, Hashable {
    var id: UInt64
    static var baseTime = Double(1420070400000)
    static let timeBits = 41
    static let nodeBits = 10
    static let seqBits = 12
    static var sequence = 0
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

    func mask(_ value: Int, _ bits: Int) -> Int {
        return (value & ((1 << bits) - 1))
    }

    init() {
        id = 0
        Self.sequence += 1
        let t = mask(Int(CACurrentMediaTime() * 1000 - Self.baseTime), Self.timeBits)
        id = UInt64(t << (Self.nodeBits + Self.seqBits) | (mask(Self.nodeId, Self.nodeBits) << Self.seqBits) | mask(Self.sequence, Self.seqBits))
    }
}
