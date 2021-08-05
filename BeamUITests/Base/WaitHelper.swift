//
//  WaitHelper.swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation
import XCTest

//The class is designed to wait for some specific predicates,
//where predicates formats are stored in appropriate enums of the class
class WaitHelper: XCTestCase {
    
    let implicitWaitTimeout = BaseTest().implicitWaitTimeout
    
    func waitFor(_ predicateFormat: String, _ element: XCUIElement) {
        let predicate = NSPredicate(format: predicateFormat)
        _ = XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: element, handler: nil)], timeout: implicitWaitTimeout)
    }
    
    enum PredicateFormat: String {
        case isHittable = "isHittable == true"
        case isNotHittable = "isHittable == false"
        case exists = "exists == true"
        case notExists = "exists == false"
    }
}
