//
//  DatePickerTestView.swift
//  BeamUITests
//
//  Created by Andrii on 07/12/2021.
//

import Foundation
import XCTest

class DatePickerTestView: BaseView {
    
    @discardableResult
    func selectMonth(month: String) -> DatePickerTestView {
        app.dialogs.staticTexts[DatePickerViewLocators.StaticTexts.monthDropdown.accessibilityIdentifier].clickOnExistence()
        app.staticTexts["\(NoteViewLocators.Others.beginningPartOfContextItem.accessibilityIdentifier)\(month.lowercased())"].click()
        return self
    }
    
    @discardableResult
    func selectYear(year: String) -> DatePickerTestView {
        app.dialogs.staticTexts[DatePickerViewLocators.StaticTexts.yearDropdown.accessibilityIdentifier].clickOnExistence()
        app.staticTexts["\(NoteViewLocators.Others.beginningPartOfContextItem.accessibilityIdentifier)\(year)"].click()
        return self
    }
    
    @discardableResult
    func selectDate(date: String) -> DatePickerTestView {
        app.dialogs.children(matching: .staticText).matching(identifier: date).element(boundBy: 0).click()
        return self
    }
    
}
