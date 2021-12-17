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
    func waitForStringValueEqual(_ expectedValue: String, _ element: XCUIElement, _ timeout: TimeInterval) -> Bool {
        return waitFor(PredicateFormat.valueEquals.rawValue + "'\(expectedValue)'", element, timeout)
    }
    
    @discardableResult
    func waitForCountValueEqual(timeout: TimeInterval, expectedNumber: Int, elementQuery: XCUIElementQuery) -> Bool {
        var count: TimeInterval = 0
        while elementQuery.count != expectedNumber && count < timeout {
            sleep(1)
            count += 1
        }
        return count < timeout
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
    
    @discardableResult
    func waitForIsEnabled(_ element: XCUIElement) -> Bool {
        return waitFor(PredicateFormat.isEnabled.rawValue, element)
    }
    
    @discardableResult
    func waitForKeyboardFocus(_ element: XCUIElement) -> Bool {
        return waitFor(PredicateFormat.hasKeyboardFocus.rawValue, element)
    }
    
    @discardableResult
    func waitForKeyboardUnfocus(_ element: XCUIElement) -> Bool {
        return waitFor(PredicateFormat.doesntHaveKeyboardFocus.rawValue, element)
    }
    
    enum PredicateFormat: String {
        case isEnabled = "isEnabled == true"
        case isHittable = "isHittable == true"
        case isNotHittable = "isHittable == false"
        case exists = "exists == true"
        case notExists = "exists == false"
        case identifierEquals = "identifier == "
        case valueEquals = "value == "
        case hasKeyboardFocus = "hasKeyboardFocus == true"
        case doesntHaveKeyboardFocus = "hasKeyboardFocus == false"
    }
}
