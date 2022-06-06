//
//  RowAllNotesTestTable.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 03.06.2022.
//

import Foundation

class RowAllNotesTestTable: BaseRow {
    
    var title: String!
    //var isPublished: Bool! To be fixed with accessibility
    var words: Int!
    var links: Int!
    var updated: String!
    
    init(_ title: String,/*_ isPublished: Bool,*/_ words: Int,_ links: Int, _ updated: String) {
        self.title = title
        //self.isPublished = isPublished
        self.words = words
        self.links = links
        self.updated = updated
    }
    
    override init() {}
}
