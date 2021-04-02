//
//  WeakReference.swift
//  Beam
//
//  Created by Sebastien Metrot on 03/02/2021.
//

import Foundation

public struct WeakReference<T> {
    private weak var privateRef: AnyObject?
    public var ref: T? {
        get { return privateRef as? T }
        set { privateRef = newValue as AnyObject }
    }

    public init(_ ref: T) {
        self.ref = ref
    }
}
