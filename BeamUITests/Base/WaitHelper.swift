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
    let minimumWaitTimeout = BaseTest().minimumWaitTimeout
    
    @discardableResult
    func waitFor(_ predicateFormat: String, _ element: XCUIElement) -> Bool {
        let predicate = NSPredicate(format: predicateFormat)
        let result =  XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: element, handler: nil)], timeout: implicitWaitTimeout)
        return result == .completed
    }
    
    @discardableResult
    func waitFor(_ predicateFormat: String, _ element: XCUIElement, _ timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: predicateFormat)
        let result =  XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: element, handler: nil)], timeout: timeout)
        return result == .completed
    }
    
    @discardableResult
    func waitForElementQuery(_ predicateFormat: String, _ elements: XCUIElementQuery) -> Bool {
        let predicate = NSPredicate(format: predicateFormat)
        let result =  XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: elements, handler: nil)], timeout: implicitWaitTimeout)
        return result == .completed
    }
    
    @discardableResult
    func waitForStringValueEqual(_ expectedValue: String, _ element: XCUIElement) -> Bool {
        return waitFor(PredicateFormat.valueEquals.rawValue + "'\(expectedValue)'", element)
    }
    
    @discardableResult
    func waitForIdentifierEqual(_ expectedIdentifier: String, _ element: XCUIElement) -> Bool {
        return waitFor(PredicateFormat.identifierEquals.rawValue + "'\(expectedIdentifier)'", element)
    }
    
    @discardableResult
    func waitForDoesntExist(_ element: XCUIElement) -> Bool {
        return waitFor(PredicateFormat.notExists.rawValue, element)
    }
    
    @discardableResult
    func waitForIsHittable(_ element: XCUIElement) -> Bool {
        return waitFor(PredicateFormat.isHittable.rawValue, element)
    }
    
    
    enum PredicateFormat: String {
        case isHittable = "isHittable == true"
        case isNotHittable = "isHittable == false"
        case exists = "exists == true"
        case notExists = "exists == false"
        case identifierEquals = "identifier == "
        case valueEquals = "value == "
    }
}
