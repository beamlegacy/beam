//
//  CreditCardsTestTable.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 11.05.2022.
//

import Foundation
import XCTest

class CreditCardsTestTable: BaseView, Rowable {
    
    var rows = [RowCreditCardsTestTable]()
    var numberOfVisibleItems: Int!
    
    override init() {
        super.init()
        getVisibleRows()
    }
    
    private func getTextFieldValueByRow(rowNumber: Int, field:  CreditCardTableLocators.TextFields) -> String {
        return getElementStringValue(element:app.tables.containing(.tableColumn, identifier: CreditCardTableLocators.TextFields.cardDescription.accessibilityIdentifier).children(matching: .tableRow).element(boundBy: rowNumber).textFields[field.accessibilityIdentifier])
    }
    
    func getVisibleRow(_ rowNumber: Int) -> RowCreditCardsTestTable {
        //To be replaced once https://gitlab.com/beamgroup/beam/-/merge_requests/2840 is merged
        let description = getElementStringValue(element:app.tables.containing(.tableColumn, identifier:CreditCardTableLocators.TextFields.cardDescription.accessibilityIdentifier).children(matching: .tableRow).element(boundBy: rowNumber).cells.containing(.image, identifier:CreditCardTableLocators.Images.cardIcon.accessibilityIdentifier).children(matching: .textField).element)
        let cardHolder = getTextFieldValueByRow(rowNumber: rowNumber, field: .cardHolderTextField)
        let cardNumber = getTextFieldValueByRow(rowNumber: rowNumber, field: .cardNumberTextField)
        let expirationDate = getTextFieldValueByRow(rowNumber: rowNumber, field: .cardDateTextField)
        return RowCreditCardsTestTable(description, cardHolder, cardNumber, expirationDate)
    }
    
    func getVisibleRows() {
        getNumberOfVisibleItems()
        for index in 0..<numberOfVisibleItems {
            rows.append(getVisibleRow(index))
        }
    }
    
    @discardableResult
    func getNumberOfVisibleItems() -> Int {
        numberOfVisibleItems = app.images.matching(identifier: CreditCardTableLocators.Images.cardIcon.accessibilityIdentifier).allElementsBoundByIndex.count
        return numberOfVisibleItems
    }
    
    @discardableResult
    func selectCreditCardItem(index: Int) -> CreditCardsTestTable {
        getCardIconElement(index: index).tapInTheMiddle()
        return self
    }
    
    func openEditCardView(index: Int) -> CreditCardsTestTable {
        getCardIconElement(index: index).doubleTapInTheMiddle()
        return self
    }
    
    private func getCardIconElement(index: Int) -> XCUIElement {
        return app.images.matching(identifier: CreditCardTableLocators.Images.cardIcon.accessibilityIdentifier).allElementsBoundByIndex[index]
    }
}
