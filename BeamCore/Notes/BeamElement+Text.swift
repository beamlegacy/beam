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

    var joinTexts: BeamText {
        var childrenText = BeamText()
        children.forEach({ child in
            dump(child.kind)
            child.allTexts.forEach({ (_, text) in
                childrenText.append(text)
            })
        })
        return childrenText
    }

    /// Join subsequent items of the .bullet kind into a single bullet BeamElement
    /// - Returns: self
    @discardableResult func joinKinds() -> BeamElement {
        for child in flatElements {
            if let previousChild = child.previousSibbling() {
                if child.kind == .bullet && previousChild.kind == .bullet {
                    previousChild.text.append(child.text)
                    removeChild(child)
                }
            }
        }
        return self
    }
}
