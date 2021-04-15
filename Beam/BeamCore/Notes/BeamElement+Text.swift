//
//  BeamElement+Text.swift
//  BeamCore
//
//  Created by Sebastien Metrot on 12/04/2021.
//

import Foundation

public extension BeamElement {
    var allTexts: [(UUID, BeamText)] {
        let childrenText = children.reduce([]) { value, element -> [(UUID, BeamText)] in
            value + element.allTexts
        }
        if let note = self as? BeamNote {
            return [(id, BeamText(text: note.title))] + childrenText
       }

        return [(id, text)] + childrenText
    }
}
