//
//  NSView+Xib.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 03/01/2021.
//

import Cocoa

extension NSView {

    var nibName: String {
        return String(describing: type(of: self))
    }

}
