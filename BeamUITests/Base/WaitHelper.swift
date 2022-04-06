//
//  swift
//  BeamUITests
//
//  Created by Andrii on 26.07.2021.
//

import Foundation
import XCTest

//The class is designed to wait for some specific predicates,
//where predicates formats are stored in appropriate enums of the class
//class WaitHelper: XCTestCase {

enum PredicateFormat: String {
    case isEnabled = "isEnabled == true"
    case isDisabled = "isEnabled == false"
    case isHittable = "isHittable == true"
    case isNotHittable = "isHittable == false"
    case exists = "exists == true"
    case notExists = "exists == false"
    case identifierEquals = "identifier == "
    case valueEquals = "value == "
    case hasKeyboardFocus = "hasKeyboardFocus == true"
    case doesntHaveKeyboardFocus = "hasKeyboardFocus == false"
}

protocol WaitHelper {
    @discardableResult
    func waitFor(_ predicateFormat: String, _ element: XCUIElement) -> Bool

    @discardableResult
    func waitFor(_ predicateFormat: String, _ element: XCUIElement, _ timeout: TimeInterval) -> Bool

    @discardableResult
    func waitForElementQuery(_ predicateFormat: String, _ elements: XCUIElementQuery) -> Bool

    @discardableResult
    func waitForStringValueEqual(_ expectedValue: String, _ element: XCUIElement) -> Bool

    @discardableResult
    func waitForStringValueEqual(_ expectedValue: String, _ element: XCUIElement, _ timeout: TimeInterval) -> Bool

    @discardableResult
    func waitForCountValueEqual(timeout: TimeInterval, expectedNumber: Int, elementQuery: XCUIElementQuery) -> Bool

    @discardableResult
    func waitForIdentifierEqual(_ expectedIdentifier: String, _ element: XCUIElement) -> Bool

    @discardableResult
    func waitForDoesntExist(_ element: XCUIElement) -> Bool

    @discardableResult
    func waitForIsHittable(_ element: XCUIElement) -> Bool

    @discardableResult
    func waitForIsEnabled(_ element: XCUIElement) -> Bool
    
    @discardableResult
    func waitForIsDisabled(_ element: XCUIElement) -> Bool

    @discardableResult
    func waitForKeyboardFocus(_ element: XCUIElement) -> Bool

    @discardableResult
    func waitForKeyboardUnfocus(_ element: XCUIElement) -> Bool

    // MARK: Static versions
    @discardableResult
    static func waitFor(_ predicateFormat: String, _ element: XCUIElement) -> Bool

    @discardableResult
    static func waitFor(_ predicateFormat: String, _ element: XCUIElement, _ timeout: TimeInterval) -> Bool

    @discardableResult
    static func waitForElementQuery(_ predicateFormat: String, _ elements: XCUIElementQuery) -> Bool

    @discardableResult
    static func waitForStringValueEqual(_ expectedValue: String, _ element: XCUIElement) -> Bool

    @discardableResult
    static func waitForStringValueEqual(_ expectedValue: String, _ element: XCUIElement, _ timeout: TimeInterval) -> Bool

    @discardableResult
    static func waitForCountValueEqual(timeout: TimeInterval, expectedNumber: Int, elementQuery: XCUIElementQuery) -> Bool

    @discardableResult
    static func waitForIdentifierEqual(_ expectedIdentifier: String, _ element: XCUIElement) -> Bool

    @discardableResult
    static func waitForDoesntExist(_ element: XCUIElement) -> Bool

    @discardableResult
    static func waitForIsHittable(_ element: XCUIElement) -> Bool

    @discardableResult
    static func waitForIsEnabled(_ element: XCUIElement) -> Bool

    @discardableResult
    static func waitForKeyboardFocus(_ element: XCUIElement) -> Bool

    @discardableResult
    static func waitForKeyboardUnfocus(_ element: XCUIElement) -> Bool

    func expectation(for predicate: NSPredicate,
                     evaluatedWith object: Any?,
                     handler: XCTNSPredicateExpectation.Handler?) -> XCTestExpectation
    static func expectation(for predicate: NSPredicate,
                     evaluatedWith object: Any?,
                            handler: XCTNSPredicateExpectation.Handler?) -> XCTestExpectation
}

extension WaitHelper {
    func expectation(for predicate: NSPredicate,
                     evaluatedWith object: Any?,
                     handler: XCTNSPredicateExpectation.Handler? = nil) -> XCTestExpectation {
        XCTNSPredicateExpectation(predicate: predicate, object: object)
    }

    static func expectation(for predicate: NSPredicate,
                     evaluatedWith object: Any?,
                            handler: XCTNSPredicateExpectation.Handler? = nil) -> XCTestExpectation {
        XCTNSPredicateExpectation(predicate: predicate, object: object)
    }
}

extension WaitHelper {
    @discardableResult
    func waitFor(_ predicateFormat: String, _ element: XCUIElement) -> Bool {
        let predicate = NSPredicate(format: predicateFormat)
        let result =  XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: element, handler: nil)], timeout: BaseTest.implicitWaitTimeout)
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
        let result =  XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: elements, handler: nil)], timeout: BaseTest.implicitWaitTimeout)
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
    func waitForIsDisabled(_ element: XCUIElement) -> Bool {
        return waitFor(PredicateFormat.isDisabled.rawValue, element)
    }
    
    @discardableResult
    func waitForKeyboardFocus(_ element: XCUIElement) -> Bool {
        return waitFor(PredicateFormat.hasKeyboardFocus.rawValue, element)
    }
    
    @discardableResult
    func waitForKeyboardUnfocus(_ element: XCUIElement) -> Bool {
        return waitFor(PredicateFormat.doesntHaveKeyboardFocus.rawValue, element)
    }
    
    // MARK: Static versions
    @discardableResult
    static func waitFor(_ predicateFormat: String, _ element: XCUIElement) -> Bool {
        let predicate = NSPredicate(format: predicateFormat)
        let result =  XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: element, handler: nil)], timeout: BaseTest.implicitWaitTimeout)
        return result == .completed
    }

    @discardableResult
    static func waitFor(_ predicateFormat: String, _ element: XCUIElement, _ timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: predicateFormat)
        let result =  XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: element, handler: nil)], timeout: timeout)
        return result == .completed
    }

    @discardableResult
    static func waitForElementQuery(_ predicateFormat: String, _ elements: XCUIElementQuery) -> Bool {
        let predicate = NSPredicate(format: predicateFormat)
        let result =  XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: elements, handler: nil)], timeout: BaseTest.implicitWaitTimeout)
        return result == .completed
    }

    @discardableResult
    static func waitForStringValueEqual(_ expectedValue: String, _ element: XCUIElement) -> Bool {
        return waitFor(PredicateFormat.valueEquals.rawValue + "'\(expectedValue)'", element)
    }

    @discardableResult
    static func waitForStringValueEqual(_ expectedValue: String, _ element: XCUIElement, _ timeout: TimeInterval) -> Bool {
        return waitFor(PredicateFormat.valueEquals.rawValue + "'\(expectedValue)'", element, timeout)
    }

    @discardableResult
    static func waitForCountValueEqual(timeout: TimeInterval, expectedNumber: Int, elementQuery: XCUIElementQuery) -> Bool {
        var count: TimeInterval = 0
        while elementQuery.count != expectedNumber && count < timeout {
            sleep(1)
            count += 1
        }
        return count < timeout
    }

    @discardableResult
    static func waitForIdentifierEqual(_ expectedIdentifier: String, _ element: XCUIElement) -> Bool {
        return waitFor(PredicateFormat.identifierEquals.rawValue + "'\(expectedIdentifier)'", element)
    }

    @discardableResult
    static func waitForDoesntExist(_ element: XCUIElement) -> Bool {
        return waitFor(PredicateFormat.notExists.rawValue, element)
    }

    @discardableResult
    static func waitForIsHittable(_ element: XCUIElement) -> Bool {
        return waitFor(PredicateFormat.isHittable.rawValue, element)
    }

    @discardableResult
    static func waitForIsEnabled(_ element: XCUIElement) -> Bool {
        return waitFor(PredicateFormat.isEnabled.rawValue, element)
    }

    @discardableResult
    static func waitForKeyboardFocus(_ element: XCUIElement) -> Bool {
        return waitFor(PredicateFormat.hasKeyboardFocus.rawValue, element)
    }

    @discardableResult
    static func waitForKeyboardUnfocus(_ element: XCUIElement) -> Bool {
        return waitFor(PredicateFormat.doesntHaveKeyboardFocus.rawValue, element)
    }

}

extension BaseTest: WaitHelper {
}

extension BaseView: WaitHelper {
}
