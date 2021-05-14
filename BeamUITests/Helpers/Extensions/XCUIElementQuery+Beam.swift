//
//  XCUIElementQuery+Beam.swift
//  BeamUITests
//
//  Created by Stef Kors on 12/05/2021.
//

import Foundation
import XCTest

extension XCUIElementQuery {
    var lastMatch: XCUIElement { return self.element(boundBy: self.count - 1) }
}
