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
        if self as? BeamNote != nil {
            return childrenText
        }

        return [(id, text)] + childrenText
    }

    var allTextElements: [BeamElement] {
        let childrenText = children.reduce([]) { value, element -> [BeamElement] in
            value + element.allTextElements
        }
        if self as? BeamNote != nil {
            return childrenText
        }

        return [self] + childrenText
    }

    func visitAllElements(_ visitor: @escaping (BeamElement) -> Void) {
        visitor(self)
        for child in children {
            child.visitAllElements(visitor)
        }
    }

    var allFileElements: [(UUID, BeamElement)] {
        var array = [(UUID, BeamElement)]()
        visitAllElements { element in
            guard case let .image(fileId, origin: _, displayInfos: _) = element.kind else { return }
            array.append((fileId, element))
        }
        return array
    }

    var allVisibleTexts: [(UUID, BeamText)] {
        let childrenText = open ? children.reduce([]) { value, element -> [(UUID, BeamText)] in
            value + element.allTexts
        }  : []
        if self as? BeamNote != nil {
            return childrenText
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
