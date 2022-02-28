//
//  DispatchQueue+MainSync.swift
//  BeamCore
//
//  Created by Sebastien Metrot on 20/02/2022.
//

import Foundation

public extension DispatchQueue {
    class func mainSync(_ block:  @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.sync {
                block()
            }
        }
    }
}
