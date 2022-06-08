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
    
    //TBD using BaseTable class accepting accepting generic tables
    func isEqualTo(_ externalTable: AllNotesTestTable) -> (Bool, String) {
        var failedValues = [String]()
        if (self.numberOfVisibleItems != externalTable.numberOfVisibleItems) {
            return (false, "Tables rows number is different")
        }
        for index in 0..<numberOfVisibleItems {
            let rowComparisonResult =  self.rows[index].isEqualTo(externalTable.rows[index])
            if !rowComparisonResult.0 {
                failedValues.append("Row number:\(index+1) comparison failed, where:\(rowComparisonResult.0)")
            }
        }
        return (failedValues.count == 0, failedValues.joined(separator: " || "))
    }
    
    //TBD using BaseTable class accepting accepting generic tables
    func containsRows() -> Bool {
        //TBD with next Sync tests
        return false
    }
}
