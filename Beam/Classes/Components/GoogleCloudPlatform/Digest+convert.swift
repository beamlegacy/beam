//
//  Digest+convert.swift
//  Beam
//
//  Created by Julien Plu on 09/03/2022.
//

import Foundation
import CryptoKit

extension Digest {
    var bytes: [UInt8] { Array(makeIterator()) }
    var data: Data { Data(bytes) }
}
