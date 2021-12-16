//
//  DebugHelpers.swift
//  BeamCore
//
//  Created by Sebastien Metrot on 15/12/2021.
//

import Foundation

public func dumpBacktrace(file: StaticString = #file, line: UInt = #line) {
    //swiftlint:disable print
    print("Dumping callstack from \(file):\(line)")
    for symbol in Thread.callStackSymbols {
        print("\t\(symbol)")
    }
    //swiftlint:enable print
}
