//
//  RowCreditCardsTestTable.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 03.06.2022.
//

import Foundation

class RowCreditCardsTestTable: BaseRow {
    
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
    
    override init() {}
}
