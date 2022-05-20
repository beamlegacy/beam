//
//  CreditCardsTestTable.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 11.05.2022.
//

import Foundation
import XCTest

class CreditCardsTestTable: BaseView, Rowable {
    
    var rows = [Row]()
    var numberOfVisibleItems: Int!
    
    public class Row {
        var description: String!
        var cardHolder: String!
        var cardNumber: String!
        var expirationDate: String!
        
        init(_ description: String,_ cardHolder: String,_ cardNumber: String,_ expirationDate: String) {
            self.description = description
            self.cardHolder = cardHolder
            self.cardNumber = cardNumber
            self.expirationDate = expirationDate
        }
        
        init() {}
    }
    
    override init() {
        super.init()
        getVisibleRows()
    }
    
    func compareRows(_ externalRow: Row, _ currentRowIndex: Int ) -> (Bool, String) {
        let currentRow = getVisibleRow(currentRowIndex) //rows[currentRowIndex]
        var errorMessage = ""
        let result = (externalRow.description == currentRow.description &&
                      externalRow.cardHolder == currentRow.cardHolder &&
                      externalRow.cardNumber == currentRow.cardNumber &&
                      externalRow.expirationDate == externalRow.expirationDate)
        if !result {
            errorMessage = "External row data: \(externalRow.description!),\(externalRow.cardHolder!),\(externalRow.cardNumber!),\(externalRow.expirationDate!) is NOT equal to current row data: \(currentRow.description!),\(currentRow.cardHolder!),\(currentRow.cardNumber!),\(currentRow.expirationDate!)"
        }
        return (result, errorMessage)
    }
    
    private func getTextFieldValueByRow(rowNumber: Int, field:  CreditCardTableLocators.TextFields) -> String {
        return getElementStringValue(element:app.windows.textFields.matching(identifier: field.accessibilityIdentifier).element(boundBy: rowNumber))
    }
    
    func getVisibleRow(_ rowNumber: Int) -> CreditCardsTestTable.Row {
        //To be replaced once https://gitlab.com/beamgroup/beam/-/merge_requests/2840 is merged
        let description = getElementStringValue(element:app.windows["Passwords"].sheets.tables.children(matching: .tableRow).element(boundBy: rowNumber).cells.containing(.image, identifier:"preferences credit card").children(matching: .textField).element)
        let cardHolder = getTextFieldValueByRow(rowNumber: rowNumber, field: .cardHolderTextField)
        let cardNumber = getTextFieldValueByRow(rowNumber: rowNumber, field: .cardNumberTextField)
        let expirationDate = getTextFieldValueByRow(rowNumber: rowNumber, field: .cardDateTextField)
        return Row(description, cardHolder, cardNumber, expirationDate)
    }
    
    func getVisibleRows() {
        getNumberOfVisibleItems()
        for index in 0..<numberOfVisibleItems {
            rows.append(getVisibleRow(index))
        }
    }
    
    @discardableResult
    func getNumberOfVisibleItems() -> Int {
        numberOfVisibleItems = app.windows.textFields.matching(identifier: CreditCardTableLocators.TextFields.cardNumberTextField.accessibilityIdentifier).allElementsBoundByIndex.count
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
        return app.windows.images.matching(identifier: CreditCardTableLocators.TextFields.descriptionTextField.accessibilityIdentifier).allElementsBoundByIndex[index]
    }
}
