//
//  WeakReference.swift
//  Beam
//
//  Created by Sebastien Metrot on 03/02/2021.
//

import Foundation

struct WeakReference<T> {
    private weak var privateRef: AnyObject?
    var ref: T? {
        get { return privateRef as? T }
        set { privateRef = newValue as AnyObject }
    }

    init(_ ref: T) {
        self.ref = ref
    }
}
