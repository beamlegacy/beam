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
        app.staticTexts["\(NoteViewLocators.OtherElements.beginningPartOfContextItem.accessibilityIdentifier)\(month.lowercased())"].clickOnExistence()
        return self
    }
    
    @discardableResult
    func selectYear(year: String) -> DatePickerTestView {
        app.dialogs.staticTexts[DatePickerViewLocators.StaticTexts.yearDropdown.accessibilityIdentifier].clickOnExistence()
        app.staticTexts["\(NoteViewLocators.OtherElements.beginningPartOfContextItem.accessibilityIdentifier)\(year)"].clickOnExistence()
        return self
    }
    
    @discardableResult
    func selectDate(date: String) -> DatePickerTestView {
        app.dialogs.children(matching: .staticText).matching(identifier: date).element(boundBy: 0).clickOnExistence()
        return self
    }
    
}
