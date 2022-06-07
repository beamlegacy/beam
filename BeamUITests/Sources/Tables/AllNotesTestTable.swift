//
//  AllNotesTestTable.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 25.05.2022.
//

import Foundation
import XCTest

class AllNotesTestTable: BaseView, Rowable {

    var rows = [RowAllNotesTestTable]()
    var numberOfVisibleItems: Int!
    
    override init() {
        super.init()
        getVisibleRows()
    }
    
    private func getTextFieldValueByRow(_ rowNumber: Int,_ sortColumn: AllNotesTableLocators.SortButtons) -> String {
        return getElementStringValue(element: app.windows[OmniboxLocators.Labels.allNotes.accessibilityIdentifier].tables.children(matching: .tableRow).element(boundBy: rowNumber).staticTexts[sortColumn.accessibilityIdentifier])
    }
    
    func getVisibleRow(_ rowNumber: Int) -> RowAllNotesTestTable {
        let title = getTextFieldValueByRow(rowNumber, .title)
        let words = Int(getTextFieldValueByRow(rowNumber, .words))!
        let links = Int(getTextFieldValueByRow(rowNumber, .links))!
        let updated = getTextFieldValueByRow(rowNumber, .updated)
        return RowAllNotesTestTable(title, words, links, updated)
    }
    
    func getVisibleRows() {
        getNumberOfVisibleItems()
        for index in 0..<numberOfVisibleItems {
            rows.append(getVisibleRow(index))
        }
    }
    
    @discardableResult
    func getNumberOfVisibleItems() -> Int {
        numberOfVisibleItems = AllNotesTestView().getNumberOfNotes()
        return numberOfVisibleItems
    }
    
    func sortTableBy(column: AllNotesTableLocators.SortButtons) -> AllNotesTestTable {
        button(column.accessibilityIdentifier).tapInTheMiddle()
        return self
    }
    
}
