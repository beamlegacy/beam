//
//  UITestFrameworkTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 21.06.2022.
//

import Foundation
import XCTest

class UITestFrameworkTests: BaseTest {
    
    func testTableComparisonFunctionality() {
        let result = RowAllNotesTestTable("xyz", 2, 1, "abc").isEqualTo(RowAllNotesTestTable("abc", 1, 2, "xyz"))
        XCTAssertFalse(result.0, result.1)
    }
    
}
